;;; test-glassmacs-r-lifecycle.el --- R queue controls, console close, quit -*- lexical-binding: t; -*-

;; Uses the fake-process helpers from test-glassmacs-sessions.el, which
;; scripts/test loads first.

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-sessions)
(require 'glassmacs-r-queue)
(require 'glassmacs-dialogs)

(defvar gs-test--sent)

(defmacro glr-test--answering (answers &rest body)
  "Run BODY with `glassmacs-dialog-choose' returning ANSWERS in turn.
Bind `asked' to the list of dialog messages, oldest first."
  (declare (indent 1))
  `(let ((remaining ,answers) (asked nil))
     (cl-letf (((symbol-function 'glassmacs-dialog-choose)
                (lambda (message _choices &optional _informative)
                  (setq asked (append asked (list message)))
                  (pop remaining))))
       ,@body)))

(defun glr-test--r-console (name)
  "Return (PROCESS . BUFFER) for a fake live R console NAME."
  (let ((console (gs-test--console name)))
    (with-current-buffer (cdr console)
      (setq major-mode 'inferior-ess-r-mode))
    console))

;;; Dialogs

(ert-deftest glassmacs-dialog-fallback-maps-keys-to-ids ()
  (cl-letf (((symbol-function 'glassmacs-dialog--native-available-p) #'ignore)
            ((symbol-function 'read-multiple-choice)
             (lambda (_prompt choices &rest _)
               (should (equal (mapcar #'car choices) '(?k ?c ?t)))
               (assq ?t choices))))
    (should (eq (glassmacs-dialog-choose
                 "Close?" '((keep "Keep" :key ?k :default t)
                            (cancel "Cancel" :key ?c :cancel t)
                            (terminate "Terminate" :key ?t)))
                'terminate))))

(ert-deftest glassmacs-dialog-quit-or-error-is-cancel ()
  (let ((choices '((go "Go" :key ?g) (stop "Stop" :key ?s :cancel t))))
    (cl-letf (((symbol-function 'glassmacs-dialog--native-available-p) #'ignore))
      (cl-letf (((symbol-function 'read-multiple-choice)
                 (lambda (&rest _) (signal 'quit nil))))
        (should (eq (glassmacs-dialog-choose "Go?" choices) 'stop)))
      (cl-letf (((symbol-function 'read-multiple-choice)
                 (lambda (&rest _) (error "No minibuffer"))))
        (should (eq (glassmacs-dialog-choose "Go?" choices) 'stop))))))

(ert-deftest glassmacs-dialog-native-helper-receives-spec-and-answers ()
  (let (spec)
    (cl-letf (((symbol-function 'glassmacs-dialog--native-available-p)
               (lambda () t))
              ((symbol-function 'executable-find) (lambda (_) "/usr/bin/open"))
              ((symbol-function 'process-file)
               (lambda (_program _in _out _display &rest args)
                 (should (equal (seq-take args 5)
                                (list "-n" "-W" "-a" (glassmacs-dialog--helper-app)
                                      "--args")))
                 (should (equal (nth 5 args) "--choice"))
                 (setq spec (with-temp-buffer
                              (insert-file-contents (nth 7 args))
                              (goto-char (point-min))
                              (let ((json-object-type 'alist)) (json-read))))
                 (with-temp-file (nth 6 args)
                   (insert "{\"choice\":\"terminate\"}"))
                 0))
              ((symbol-function 'read-multiple-choice)
               (lambda (&rest _) (ert-fail "Native answer must not fall back"))))
      (should (eq (glassmacs-dialog-choose
                   "Close?" '((keep "Keep R Running" :default t)
                              (terminate "Terminate R" :destructive t)
                              (cancel "Cancel" :cancel t))
                   "Details")
                  'terminate))
      (should (equal (cdr (assq 'message spec)) "Close?"))
      (should (equal (cdr (assq 'informative spec)) "Details"))
      (let ((buttons (append (cdr (assq 'buttons spec)) nil)))
        (should (equal (mapcar (lambda (b) (cdr (assq 'id b))) buttons)
                       '("keep" "terminate" "cancel")))
        (should (eq (cdr (assq 'destructive (nth 1 buttons))) t))))))

(ert-deftest glassmacs-dialog-native-failure-falls-back ()
  (cl-letf (((symbol-function 'glassmacs-dialog--native-available-p) (lambda () t))
            ((symbol-function 'executable-find) (lambda (_) "/usr/bin/open"))
            ((symbol-function 'process-file) (lambda (&rest _) 1))
            ((symbol-function 'read-multiple-choice)
             (lambda (_prompt choices &rest _) (car choices))))
    (should (eq (glassmacs-dialog-choose "Go?" '((go "Go" :key ?g)
                                                (stop "Stop" :key ?s :cancel t)))
                'go))))

;;; Pause reasons, continuation prompts and resume

(ert-deftest glassmacs-queue-continuation-pause-explains-and-blocks-dispatch ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (first (glassmacs-queue-submit "f(" s))
          (second (glassmacs-queue-submit "g()" s))
          reported)
     ;; R answered with its continuation prompt.
     (process-put p 'sec-prompt t)
     (glassmacs-sessions--pump s)
     (should (eq (glassmacs-entry-state first) 'uncertain))
     (should (glassmacs-session-paused s))
     (should (string-match-p "incomplete expression after cmd-1"
                             (glassmacs-session-pause-reason s)))
     (cl-letf (((symbol-function 'message)
                (lambda (fmt &rest args) (setq reported (apply #'format fmt args)))))
       (glassmacs-queue-submit "h()" s))
     (should (string-match-p "paused (R is waiting" reported))
     (should (string-match-p "R > Resume Queue, or the Queue button" reported))
     (should (eq (glassmacs-entry-state second) 'pending))
     (should (= 1 (length gs-test--sent))))))

(ert-deftest glassmacs-queue-never-dispatches-into-continuation-prompt ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (process-put p 'sec-prompt t)
     (let ((e (glassmacs-queue-submit "x" s)))
       (should (eq (glassmacs-entry-state e) 'pending))
       (should-not gs-test--sent)
       (process-put p 'sec-prompt nil)
       (glassmacs-sessions--pump s)
       (should (eq (glassmacs-entry-state e) 'running))))))

(ert-deftest glassmacs-queue-resume-at-continuation-offers-to-cancel-input ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (interrupted nil)
          (glassmacs-queue-resume-continuation-function
           (lambda (process) (setq interrupted process))))
     (glassmacs-sessions--pause s "R is waiting for the rest of an incomplete expression")
     (process-put p 'sec-prompt t)
     (let ((e (glassmacs-queue-submit "x" s)))
       ;; Keep Paused leaves everything alone.
       (glr-test--answering '(cancel)
         (should-not (glassmacs-queue-resume s)))
       (should (glassmacs-session-paused s))
       (should-not interrupted)
       ;; Cancelling the input interrupts R and resumes, but nothing is
       ;; sent until R shows its primary prompt again.
       (glr-test--answering '(clear)
         (should (glassmacs-queue-resume s)))
       (should (eq interrupted p))
       (should-not (glassmacs-session-paused s))
       (should-not (glassmacs-session-pause-reason s))
       (should (eq (glassmacs-entry-state e) 'pending))
       (process-put p 'sec-prompt nil)
       (glassmacs-sessions--pump s)
       (should (eq (glassmacs-entry-state e) 'running))))))

(ert-deftest glassmacs-queue-clear-and-resume-requires-confirmation ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (glassmacs-queue-pause s)
     (let ((a (glassmacs-queue-submit "a" s))
           (b (glassmacs-queue-submit "b" s)))
       (gs-test--confirming nil
         (glassmacs-queue-clear-and-resume s))
       (should (glassmacs-session-paused s))
       (should (eq (glassmacs-entry-state a) 'pending))
       (gs-test--confirming t
         (glassmacs-queue-clear-and-resume s))
       (should-not (glassmacs-session-paused s))
       (should (eq (glassmacs-entry-state a) 'removed))
       (should (eq (glassmacs-entry-state b) 'removed))
       (should-not gs-test--sent)
       (let ((c (glassmacs-queue-submit "c" s)))
         (should (eq (glassmacs-entry-state c) 'running)))))))

(ert-deftest glassmacs-queue-move-reorders-only-pending-commands ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (running (glassmacs-queue-submit "running" s))
          (a (glassmacs-queue-submit "a" s))
          (b (glassmacs-queue-submit "b" s))
          (c (glassmacs-queue-submit "c" s)))
     (should (= 1 (glassmacs-queue-move c -2)))
     (should (equal (glassmacs-queue-pending s) (list c a b)))
     (should (eq (car (glassmacs-session-entries s)) running))
     (should (= 3 (glassmacs-queue-move c 10)))
     (should (equal (glassmacs-queue-pending s) (list a b c)))
     (should (cl-find :reordered (glassmacs-sessions-history)
                      :key (lambda (h) (plist-get h :event))))
     (should-error (glassmacs-queue-move running 1) :type 'user-error)
     (gs-test--finish-running p)
     (glassmacs-sessions--pump s)
     (should (eq (glassmacs-entry-state a) 'running)))))

(ert-deftest glassmacs-sessions-status-text-describes-every-state ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (should (string-match-p "is idle; nothing is queued" (glassmacs-sessions-status-text s)))
     (glassmacs-queue-submit "a" s)
     (glassmacs-queue-submit "b" s)
     (should (string-match-p "is running cmd-1; 1 command is queued"
                             (glassmacs-sessions-status-text s)))
     (cl-letf (((symbol-function 'interrupt-process) #'ignore))
       (glassmacs-queue-interrupt s))
     (should (string-match-p "(1 held since an interrupt)"
                             (glassmacs-sessions-status-text s)))
     (glassmacs-queue-pause s)
     (should (string-match-p "is paused (paused by you)"
                             (glassmacs-sessions-status-text s))))))

;; ESS reads its secondary-prompt variable in whatever buffer is current
;; when output arrives, so its `sec-prompt' flag can be missing.
(ert-deftest glassmacs-continuation-prompt-is-detected-from-the-console ()
  (gs-test--with-env
   (let* ((console (gs-test--console "glassmacs-continuation"))
          (process (car console)) (buffer (cdr console)))
     (unwind-protect
         (dolist (case '(("> " nil) ("> + " t) ("+ " t) ("> + + " t)
                         ("result: + " nil) ("+ 1" nil)))
           (with-current-buffer buffer
             (let ((inhibit-read-only t))
               (goto-char (point-max))
               (insert "\n" (car case))
               (set-marker (process-mark process) (point))))
           (should (eq (and (glassmacs-sessions--continuation-p process) t)
                       (cadr case))))
       (kill-buffer buffer)))))

(ert-deftest glassmacs-continuation-prompt-uses-ess-prompt-regexps ()
  "ESS prompt variables are regexps; some ESS releases use \"+ ?\"."
  (gs-test--with-env
   (let* ((console (gs-test--console "glassmacs-continuation-regexp"))
          (process (car console)) (buffer (cdr console)))
     (unwind-protect
         (progn
           (with-current-buffer buffer
             (setq-local inferior-ess-secondary-prompt "+ ?"
                         inferior-ess-primary-prompt "> "))
           (dolist (case '(("> +" t) ("> + " t) ("+" t) ("> " nil) ("x+ " nil)))
             (with-current-buffer buffer
               (let ((inhibit-read-only t))
                 (goto-char (point-max))
                 (insert "\n" (car case))
                 (set-marker (process-mark process) (point))))
             (should (eq (and (glassmacs-sessions--continuation-p process) t)
                         (cadr case)))))
       (kill-buffer buffer)))))

(ert-deftest glassmacs-r-continuation-resume-integration-real-ess ()
  "Real R: an incomplete expression pauses; resuming discards only it."
  (skip-unless (gs-test--ess-and-r-p))
  (require 'ess-site)
  (let ((glassmacs-sessions--list nil) (glassmacs-sessions--history nil)
        (default-directory temporary-file-directory)
        (ess-ask-for-ess-directory nil) (ess-history-file nil)
        (inhibit-message t) buffer)
    (unwind-protect
        (progn
          (save-window-excursion (setq buffer (R)))
          (let* ((session (car (glassmacs-sessions-refresh)))
                 (process (glassmacs-session-process session))
                 (broken (glassmacs-queue-submit "glassmacs_f <- function(x) {" session))
                 (next (glassmacs-queue-submit "cat('resumed', 6 * 7, '\\n')" session))
                 (deadline (+ (float-time) 15)))
            (while (and (< (float-time) deadline)
                        (not (glassmacs-session-paused session)))
              (accept-process-output process 0.05)
              (glassmacs-sessions--tick))
            (should (glassmacs-session-paused session))
            (should (eq (glassmacs-entry-state broken) 'uncertain))
            (should (string-match-p "incomplete expression"
                                    (glassmacs-session-pause-reason session)))
            (should (eq (glassmacs-entry-state next) 'pending))
            (cl-letf (((symbol-function 'glassmacs-dialog-choose)
                       (lambda (&rest _) 'clear)))
              (should (glassmacs-queue-resume session)))
            (let ((check (glassmacs-queue-submit
                          "cat('defined:', exists('glassmacs_f'), '\\n')" session)))
              (setq deadline (+ (float-time) 15))
              (while (and (< (float-time) deadline)
                          (not (eq (glassmacs-entry-state check) 'completed)))
                (accept-process-output process 0.05)
                (glassmacs-sessions--tick))
              (should (eq (glassmacs-entry-state next) 'completed))
              (should (eq (glassmacs-entry-state check) 'completed)))
            (with-current-buffer buffer
              (save-excursion
                (goto-char (point-min))
                (should (search-forward "resumed 42" nil t))
                (should (search-forward "defined: FALSE" nil t))))))
      (glassmacs-sessions--cancel-timer)
      (when (buffer-live-p buffer)
        (let ((process (get-buffer-process buffer)))
          (when (and process (process-live-p process))
            (delete-process process)))
        (let ((kill-buffer-query-functions nil)) (kill-buffer buffer))))))

;;; Queue inspector

(ert-deftest glassmacs-queue-inspector-shows-and-controls-the-queue ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (running (glassmacs-queue-submit "slow()" s))
          (held (glassmacs-queue-submit "depends()" s))
          buffer)
     (cl-letf (((symbol-function 'interrupt-process) #'ignore))
       (glassmacs-queue-interrupt s))
     ;; R returns to its prompt after the interrupt.
     (gs-test--finish-running p)
     (let ((fresh (glassmacs-queue-submit "fresh()\nsecond_line()" s)))
       (unwind-protect
           (save-window-excursion
             (setq buffer (glassmacs-r-show-queue s))
             (with-current-buffer buffer
               (should (derived-mode-p 'glassmacs-queue-inspector-mode))
               (let ((text (buffer-string)))
                 (should (string-match-p "R-1 is running cmd-3" text))
                 (should (string-match-p "cmd-2 +held +depends()" text))
                 (should (string-match-p "▶ +cmd-3 +running +fresh" text))
                 (should (string-search "fresh()  … (+1 line)" text))
                 (should (string-match-p "cmd-1 +uncertain" text))
                 (should (string-match-p "\\[Resume\\]" text)))
               ;; Resume from the inspector releases the held command.
               (glassmacs-queue-inspector-resume)
               (should-not (glassmacs-entry-held held))
               (gs-test--finish-running p)
               (glassmacs-sessions--pump s)
               (should (eq (glassmacs-entry-state fresh) 'completed))
               (should (eq (glassmacs-entry-state held) 'running))
               (should (eq (glassmacs-entry-state running) 'uncertain))))
         (when (buffer-live-p buffer) (kill-buffer buffer)))))))

(ert-deftest glassmacs-queue-inspector-reorders-removes-and-refreshes ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          buffer)
     (glassmacs-queue-submit "running()" s)
     (let ((a (glassmacs-queue-submit "first()" s))
           (b (glassmacs-queue-submit "second()" s)))
       (unwind-protect
           (save-window-excursion
             (setq buffer (glassmacs-r-show-queue s))
             (with-current-buffer buffer
               (goto-char (text-property-any (point-min) (point-max)
                                             'glassmacs-queue-entry
                                             (glassmacs-entry-id b)))
               (glassmacs-queue-inspector-move-up)
               (should (equal (glassmacs-queue-pending s) (list b a)))
               ;; Point follows the moved command.
               (should (eq (glassmacs-queue-inspector--entry-at-point) b))
               (gs-test--confirming t
                 (glassmacs-queue-inspector-remove))
               (should (eq (glassmacs-entry-state b) 'removed))
               ;; A change made elsewhere refreshes the inspector.
               (glassmacs-queue-submit "third()" s)
               (accept-process-output nil 0.05)
               (should (string-match-p "third()" (buffer-string)))
               (goto-char (point-min))
               (should-error (glassmacs-queue-inspector-remove) :type 'user-error)))
         (when (buffer-live-p buffer) (kill-buffer buffer)))))))

(ert-deftest glassmacs-queue-commands-use-the-inspector-session ()
  (gs-test--with-env
   (let* ((s1 (glassmacs-sessions-register (gs-test--proc "R")))
          (s2 (glassmacs-sessions-register (gs-test--proc "R-2")))
          buffer)
     (unwind-protect
         (save-window-excursion
           (setq buffer (glassmacs-r-show-queue s2))
           (with-current-buffer buffer
             (cl-letf (((symbol-function 'glassmacs-sessions--prompt)
                        (lambda (&rest _) (ert-fail "Must not ask for a session"))))
               (call-interactively #'glassmacs-queue-pause)))
           (should (glassmacs-session-paused s2))
           (should-not (glassmacs-session-paused s1)))
       (when (buffer-live-p buffer) (kill-buffer buffer))))))

;;; Menus and toolbar

(ert-deftest glassmacs-r-queue-controls-are-in-every-r-menu ()
  (dolist (menu (list glassmacs-r-ui-source-menu glassmacs-r-ui-console-menu
                      glassmacs-r-ui-context-menu glassmacs-r-ui-signals-menu
                      glassmacs-r-ui-global-menu))
    (should (eq (lookup-key menu [queue]) 'glassmacs-r-show-queue))
    (should (eq (lookup-key menu [resume-queue]) 'glassmacs-queue-resume))
    (should (eq (lookup-key menu [pause-queue]) 'glassmacs-queue-pause))
    (should (eq (lookup-key menu [clear-resume-queue])
                'glassmacs-queue-clear-and-resume)))
  (should (equal (keymap-prompt glassmacs-r-ui-console-menu) "R")))

(ert-deftest glassmacs-r-menu-is-available-outside-r-buffers ()
  "A paused queue can be resumed from a frame showing any buffer."
  (with-temp-buffer
    (fundamental-mode)
    (let ((item (cdr (assq 'glassmacs-r-global
                           (cdr (lookup-key (current-global-map) [menu-bar]))))))
      (should (equal (car item) "R"))
      (should (eq (lookup-key (cdr item) [resume-queue]) 'glassmacs-queue-resume)))))

(ert-deftest glassmacs-r-buffers-show-one-r-menu-and-queue-signals ()
  (let ((console (generate-new-buffer " *glassmacs-signals-console*")))
    (unwind-protect
        (with-current-buffer console
          (comint-mode)
          (setq major-mode 'inferior-ess-r-mode)
          (cl-letf (((symbol-function 'glassmacs-r-ui--source-buffer-p) #'ignore)
                    ((symbol-function 'glassmacs-r-ui--enable-toolbar) #'ignore))
            (glassmacs-r-ui--install-controls))
          ;; Read the private map's own entries; `lookup-key' would return a
          ;; composition with comint's inherited menu-bar map.
          (let ((own (cdr (assq 'menu-bar (cdr glassmacs-r-ui--local-map)))))
            (should (eq (cdr (assq 'glassmacs-r-global (cdr own))) 'undefined))
            (should (eq (cdr (assq 'signals (cdr own))) glassmacs-r-ui-signals-menu)))
          ;; comint's own Signals entries remain in the shared map.
          (should (keymapp (lookup-key comint-mode-map [menu-bar signals]))))
      (kill-buffer console))))

(ert-deftest glassmacs-r-toolbars-offer-the-queue ()
  (should (assq 'glassmacs-queue glassmacs-r-ui--toolbar-actions))
  (should (assq 'glassmacs-queue glassmacs-r-ui--console-toolbar-actions))
  (should (eq (nth 2 (assq 'glassmacs-queue glassmacs-r-ui--console-toolbar-actions))
              'glassmacs-r-show-queue)))

;;; Closing an R console

(ert-deftest glassmacs-console-close-keep-running-closes-only-the-window ()
  (gs-test--with-env
   (let* ((console (glr-test--r-console "glassmacs-close-keep"))
          (process (car console)) (buffer (cdr console)))
     (glassmacs-sessions-register process)
     (glassmacs-close-test--with-split buffer
       (set-window-buffer (next-window window 'never) (get-buffer-create " *glr-other*"))
       (glr-test--answering '(keep)
         (should (glassmacs--close-reviewed 'view window))
         (should (equal asked '("Close the R console for R-1?"))))
       (should-not (window-live-p window))
       (should (process-live-p process))
       (should (buffer-live-p buffer)))
     (kill-buffer buffer))))

(ert-deftest glassmacs-console-close-terminate-idle-r-after-close ()
  (gs-test--with-env
   (let* ((console (glr-test--r-console "glassmacs-close-terminate"))
          (process (car console)) (buffer (cdr console))
          (session (glassmacs-sessions-register process)))
     (glassmacs-close-test--with-split buffer
       (set-window-buffer (next-window window 'never) (get-buffer-create " *glr-other*"))
       (glr-test--answering '(terminate)
         (should (glassmacs--close-reviewed 'view window))
         ;; An idle session needs no second confirmation.
         (should (= 1 (length asked))))
       (should-not (window-live-p window))
       (should-not (process-live-p process))
       (should (eq (glassmacs-session-state session) 'terminated)))
     (kill-buffer buffer))))

(ert-deftest glassmacs-console-close-terminating-busy-r-needs-second-confirmation ()
  (gs-test--with-env
   (let* ((console (glr-test--r-console "glassmacs-close-busy"))
          (process (car console)) (buffer (cdr console))
          (session (glassmacs-sessions-register process))
          (running (glassmacs-queue-submit "slow()" session)))
     (glassmacs-close-test--with-split buffer
       (set-window-buffer (next-window window 'never) (get-buffer-create " *glr-other*"))
       ;; Terminate, then Cancel at "still working": nothing changes.
       (glr-test--answering '(terminate cancel)
         (should-not (glassmacs--close-reviewed 'view window))
         (should (string-match-p "still working" (nth 1 asked))))
       (should (window-live-p window))
       (should (process-live-p process))
       (should (eq (glassmacs-entry-state running) 'running))
       ;; Confirming both ends R and records the command as uncertain.
       (glr-test--answering '(terminate terminate)
         (should (glassmacs--close-reviewed 'view window)))
       (should-not (process-live-p process))
       (should (eq (glassmacs-entry-state running) 'uncertain)))
     (kill-buffer buffer))))

(ert-deftest glassmacs-console-terminate-waits-for-a-successful-close ()
  "A later document Cancel must leave a Terminate-chosen R running."
  (gs-test--with-env
   (let* ((console (glr-test--r-console "glassmacs-close-veto"))
          (process (car console)) (buffer (cdr console)))
     (glassmacs-sessions-register process)
     (glassmacs-close-test--with-split buffer
       (set-window-buffer (next-window window 'never) (get-buffer-create " *glr-other*"))
       (glr-test--answering '(terminate)
         (cl-letf (((symbol-function 'glassmacs--close-documents-in-windows)
                    (lambda (_windows) nil)))
           (should-not (glassmacs--close-reviewed 'view window))))
       (should (window-live-p window))
       (should (process-live-p process)))
     (kill-buffer buffer))))

(ert-deftest glassmacs-console-close-cancel-keeps-window-and-r ()
  (gs-test--with-env
   (let* ((console (glr-test--r-console "glassmacs-close-cancel"))
          (process (car console)) (buffer (cdr console)))
     (glassmacs-sessions-register process)
     (glassmacs-close-test--with-split buffer
       (set-window-buffer (next-window window 'never) (get-buffer-create " *glr-other*"))
       (glr-test--answering '(cancel)
         (should-not (glassmacs--close-reviewed 'view window)))
       (should (window-live-p window))
       (should (process-live-p process)))
     (kill-buffer buffer))))

(ert-deftest glassmacs-closing-a-source-document-never-asks-about-r ()
  (gs-test--with-env
   (let* ((console (glr-test--r-console "glassmacs-close-source"))
          (source (generate-new-buffer "analysis.R")))
     (glassmacs-sessions-register (car console))
     (glassmacs-close-test--with-split source
       (glr-test--answering nil
         (cl-letf (((symbol-function 'glassmacs-dialog-choose)
                    (lambda (&rest _) (ert-fail "No R dialog for a source document"))))
           (should (glassmacs--close-reviewed 'view window)))))
     (should (process-live-p (car console)))
     (kill-buffer (cdr console)))))

;;; Quitting

(ert-deftest glassmacs-quit-without-r-sessions-is-unchanged ()
  (let (reviewed)
    (cl-letf (((symbol-function 'glassmacs-recovery--live-r-sessions) #'ignore)
              ((symbol-function 'glassmacs-dialog-choose)
               (lambda (&rest _) (ert-fail "No R dialog without R sessions")))
              ((symbol-function 'glassmacs-recovery--quit-reviewed)
               (lambda () (setq reviewed t))))
      (let ((glassmacs-preserve-open-buffers-on-quit nil))
        (glassmacs-recovery-quit))
      (should reviewed))))

(ert-deftest glassmacs-quit-with-r-asks-natively-and-honors-each-choice ()
  (gs-test--with-env
   (let* ((process (gs-test--proc "R"))
          (session (glassmacs-sessions-register process))
          calls)
     (set-process-query-on-exit-flag process t)
     (cl-letf (((symbol-function 'glassmacs-recovery--live-r-sessions)
                (lambda () (list session)))
               ((symbol-function 'glassmacs-recovery--quit-preserving)
                (lambda ()
                  (push (list 'preserve (process-query-on-exit-flag process)
                              (functionp (car kill-emacs-hook)))
                        calls)))
               ((symbol-function 'glassmacs-recovery--quit-reviewed)
                (lambda ()
                  (push (list 'review (process-query-on-exit-flag process)
                              (bound-and-true-p desktop-save-mode))
                        calls))))
       (glr-test--answering '(cancel)
         (should-not (glassmacs-recovery-quit))
         (should (string-match-p "R session running" (car asked))))
       (should-not calls)
       (glr-test--answering '(save)
         (glassmacs-recovery-quit))
       ;; Emacs's own process question is skipped for R during the quit.
       (should (equal (car calls) '(preserve nil t)))
       ;; The quit "failed" (the stub returned), so R's flag is restored.
       (should (process-query-on-exit-flag process))
       (let ((desktop-save-mode t))
         (glr-test--answering '(discard)
           (glassmacs-recovery-quit)))
       (should (equal (car calls) '(review nil nil)))
       (should (process-query-on-exit-flag process))))))

(ert-deftest glassmacs-quit-session-state-is-written-only-on-exit ()
  (let* ((glassmacs-home (make-temp-file "glassmacs-quit-home-" t))
         (glassmacs-restore-workspace nil)
         (desktop-dirname nil)
         saved)
    (unwind-protect
        (cl-letf (((symbol-function 'desktop-save)
                   (lambda (dir &rest _) (setq saved dir))))
          (glassmacs-workspace-save-for-next-launch)
          (should (equal saved (file-name-as-directory glassmacs-home)))
          (should (file-exists-p (glassmacs-workspace--restore-once-file)))
          (with-temp-file (expand-file-name glassmacs-workspace-file-name glassmacs-home)
            (insert ";; desktop"))
          (glassmacs-workspace-forget)
          (should-not (file-exists-p (glassmacs-workspace--restore-once-file)))
          (should-not (file-exists-p
                       (expand-file-name glassmacs-workspace-file-name glassmacs-home))))
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-workspace-restore-once-marker-reopens-once ()
  (let* ((glassmacs-home (make-temp-file "glassmacs-once-home-" t))
         (glassmacs-restore-workspace nil)
         (glassmacs-workspace--restored nil)
         (noninteractive nil)
         read)
    (unwind-protect
        (cl-letf (((symbol-function 'desktop-read) (lambda (&rest _) (setq read t)))
                  ((symbol-function 'glassmacs-workspace-apply) #'ignore))
          (with-temp-file (glassmacs-workspace--restore-once-file) (insert "once"))
          (glassmacs-workspace-restore-at-startup)
          (should read)
          (should-not (file-exists-p (glassmacs-workspace--restore-once-file))))
      (delete-directory glassmacs-home t))))

(provide 'test-glassmacs-r-lifecycle)
;;; test-glassmacs-r-lifecycle.el ends here
