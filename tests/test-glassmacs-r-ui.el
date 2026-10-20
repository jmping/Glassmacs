;;; test-glassmacs-r-ui.el --- R UI ERT tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'comint)
(require 'glassmacs-r-ui)

(ert-deftest glassmacs-r-ui-console-histories-are-buffer-local ()
  (let ((first (generate-new-buffer " *glassmacs-r-history-1*"))
        (second (generate-new-buffer " *glassmacs-r-history-2*")))
    (unwind-protect
        (progn
          (with-current-buffer first
            (comint-mode)
            (glassmacs-r-ui--configure-console)
            (ring-insert comint-input-ring "first-session-command"))
          (with-current-buffer second
            (comint-mode)
            (glassmacs-r-ui--configure-console))
          (should (local-variable-p 'comint-input-ring first))
          (should (local-variable-p 'comint-input-ring second))
          (should-not (eq (buffer-local-value 'comint-input-ring first)
                          (buffer-local-value 'comint-input-ring second)))
          (should (equal (ring-elements
                          (buffer-local-value 'comint-input-ring first))
                         '("first-session-command")))
          (should (ring-empty-p
                   (buffer-local-value 'comint-input-ring second))))
      (kill-buffer first)
      (kill-buffer second))))

(ert-deftest glassmacs-r-ui-real-ess-console-keeps-history-controls ()
  (unless (locate-library "ess-site")
    (ert-skip "ESS is not installed"))
  (require 'ess-site)
  (with-temp-buffer
    (inferior-ess-r-mode)
    (should (local-variable-p 'comint-input-ring))
    (should (eq (key-binding [up]) #'glassmacs-r-ui-previous-input-or-line))
    (should (eq (key-binding [down]) #'glassmacs-r-ui-next-input-or-line))
    (should (eq (key-binding (kbd "RET")) #'comint-send-input))))

(ert-deftest glassmacs-r-ui-ess-region-entrypoint-uses-selected-target ()
  (unless (locate-library "ess-site")
    (ert-skip "ESS is not installed"))
  (require 'ess-site)
  (gs-test--with-env
   (let* ((session (glassmacs-sessions-register (gs-test--proc "R-real-entrypoint")))
          (buffer (generate-new-buffer " *glassmacs-ess-routing*")))
     (unwind-protect
         (with-current-buffer buffer
           (ess-r-mode)
           (setq-local glassmacs-r-target-session (glassmacs-session-id session))
           (insert "x <- 23")
           (let ((entry (ess-eval-region (point-min) (point-max))))
             (should (equal (glassmacs-entry-session-id entry)
                            (glassmacs-session-id session)))
             (should (equal (glassmacs-entry-source entry) "x <- 23"))))
       (kill-buffer buffer)))))

(ert-deftest glassmacs-r-ui-ess-function-entrypoint-queues-current-function ()
  (unless (locate-library "ess-site")
    (ert-skip "ESS is not installed"))
  (require 'ess-site)
  (gs-test--with-env
   (let* ((session (glassmacs-sessions-register (gs-test--proc "R-function-entrypoint")))
          (buffer (generate-new-buffer " *glassmacs-ess-function*")))
     (unwind-protect
         (with-current-buffer buffer
           (ess-r-mode)
           (setq-local glassmacs-r-target-session (glassmacs-session-id session))
           (insert "f <- function(x) {\n  x + 1\n}\n")
           (goto-char (point-min))
           (search-forward "x + 1")
           (let ((entry (ess-eval-function)))
             (should (equal (glassmacs-entry-session-id entry)
                            (glassmacs-session-id session)))
             (should (equal (glassmacs-entry-source entry)
                            "f <- function(x) {\n  x + 1\n}\n"))))
       (kill-buffer buffer)))))

(ert-deftest glassmacs-r-ui-recalled-history-remains-editable ()
  (with-temp-buffer
    (comint-mode)
    (setq-local comint-prompt-regexp "^> ")
    (insert "> ")
    (setq-local comint-accum-marker (copy-marker (point-max))
                comint-get-old-input (lambda () ""))
    (ring-insert comint-input-ring "result <- 1")
    (goto-char (point-max))
    (cl-letf (((symbol-function 'comint-after-pmark-p) (lambda () t)))
      (glassmacs-r-ui-previous-input-or-line))
    (should (equal (buffer-string) "> result <- 1"))
    (goto-char (+ (point-min) 9))
    (insert "edited ")
    (should (equal (buffer-string) "> result edited <- 1"))))

(ert-deftest glassmacs-r-ui-adds-to-emacs-native-context-menu ()
  (with-temp-buffer
    (setq major-mode 'ess-r-mode)
    (let ((menu (make-sparse-keymap)))
      (cl-letf (((symbol-function 'glassmacs-sessions-refresh)
                 (lambda () (ert-fail "Building a context menu must not refresh sessions"))))
        (glassmacs-r-ui--populate-context-menu menu nil))
      (should (eq (lookup-key menu [glassmacs-queue]) #'glassmacs-queue-show))
      (should (eq (lookup-key menu [glassmacs-directories])
                  #'glassmacs-r-inspect-directories)))))

(ert-deftest glassmacs-r-ui-up-at-prompt-start-recalls-history ()
  (with-temp-buffer
    (comint-mode)
    (setq-local comint-prompt-regexp "^> ")
    (insert "> x <- 1")
    (goto-char (point-min))
    (forward-char 2)
    (let (called)
      (cl-letf (((symbol-function 'comint-previous-input)
                 (lambda (&optional count) (setq called count))))
        (glassmacs-r-ui-previous-input-or-line))
      (should (= called 1)))))

(ert-deftest glassmacs-r-ui-up-within-multiline-input-moves-cursor ()
  (with-temp-buffer
    (comint-mode)
    (setq-local comint-prompt-regexp "^> ")
    (insert "> function() {\n  1\n}")
    (goto-char (point-min))
    (forward-line 1)
    (let (called)
      (cl-letf (((symbol-function 'comint-previous-input)
                 (lambda (&optional _) (setq called t))))
        (glassmacs-r-ui-previous-input-or-line))
      (should-not called)
      (should (= (line-number-at-pos) 1)))))

(ert-deftest glassmacs-r-ui-context-menu-enablement-does-not-refresh-sessions ()
  (let* ((binding (assq 'queue (cdr glassmacs-r-ui-context-menu)))
         (enable-form (plist-get (nthcdr 4 binding) :enable)))
    (should enable-form)
    (cl-letf (((symbol-function 'glassmacs-sessions-refresh)
               (lambda () (ert-fail "Menu enablement must not refresh sessions"))))
      (should-not (eval enable-form)))))

(ert-deftest glassmacs-r-target-indicator-reflects-explicit-selection ()
  (let* ((process (gs-test--proc "R-target-modeline"))
         (session (glassmacs-sessions-register process)))
    (unwind-protect
        (with-temp-buffer
          (glassmacs-r-select-session (glassmacs-session-id session))
          (should (equal glassmacs-r-target-session
                         (glassmacs-session-id session)))
          (should (equal (glassmacs-r--target-lighter)
                         (format " R[%s]" (glassmacs-session-id session))))
          (glassmacs-r-clear-session-target)
          (should-not glassmacs-r-target-session)
          (should-not (glassmacs-r--target-lighter)))
      (delete-process process))))

(ert-deftest glassmacs-r-target-does-not-fall-through-after-session-restart ()
  (gs-test--with-env
   (let* ((old (gs-test--proc "R-same-name"))
          (old-session (glassmacs-sessions-register old))
          (other (gs-test--proc "R-other"))
          (other-session (glassmacs-sessions-register other))
          (replacement (gs-test--proc "R-same-name")))
     (with-temp-buffer
       (setq glassmacs-r-target-session (glassmacs-session-id old-session))
       (delete-process old)
       (glassmacs-sessions-register replacement)
       (should-error (glassmacs-queue-submit "must not migrate")
                     :type 'user-error)
       (should-not gs-test--sent)
       (should (equal (glassmacs-r--target-lighter)
                      (format " R[%s!]" (glassmacs-session-id old-session))))
       (should (eq (glassmacs-session-state other-session) 'ready))))))

(ert-deftest glassmacs-r-target-isolation-across-ten-projects ()
  (gs-test--with-env
   (let (project-buffers results)
     (unwind-protect
         (progn
           (dotimes (index 10)
             (let ((project (1+ index)))
               (dotimes (process-index 2)
                 (let* ((process-number (1+ process-index))
                        (process (gs-test--proc
                                  (format "R-project-%d-process-%d"
                                          project process-number)))
                        (session (glassmacs-sessions-register process))
                        (buffer (generate-new-buffer "analysis.R"))
                        (object-value (+ (* project 10) process-number)))
                   (push buffer project-buffers)
                   (with-current-buffer buffer
                     (setq buffer-file-name
                           (format "/research/project-%d/analysis.R" project))
                     (setq-local glassmacs-r-target-session
                                 (glassmacs-session-id session))
                     (let ((entry (glassmacs-queue-submit
                                   (format "object <- %d" object-value))))
                       (push (list object-value session entry) results)))))))
           (setq results (nreverse results))
           (should (= 20 (length (glassmacs-sessions-live))))
           (dolist (result results)
             (let ((object-value (nth 0 result))
                   (session (nth 1 result))
                   (entry (nth 2 result)))
               (should (equal (glassmacs-entry-session-id entry)
                              (glassmacs-session-id session)))
               (should (equal (glassmacs-entry-source entry)
                              (format "object <- %d" object-value)))
               (should
                (cl-some (lambda (sent)
                           (eq (car sent) (glassmacs-session-process session)))
                         gs-test--sent))))
           (should (= 20 (length (delete-dups
                                  (mapcar (lambda (result)
                                            (glassmacs-session-id (nth 1 result)))
                                          results))))))
       (mapc (lambda (buffer)
               (when (buffer-live-p buffer) (kill-buffer buffer)))
             project-buffers)))))

(ert-deftest glassmacs-r-one-off-region-routes-to-chosen-session ()
  (gs-test--with-env
   (let* ((first (glassmacs-sessions-register (gs-test--proc "R-one-off-1")))
          (second (glassmacs-sessions-register (gs-test--proc "R-one-off-2")))
          (glassmacs-r-target-session (glassmacs-session-id first)))
     (with-temp-buffer
       (insert "x <- 7")
       (cl-letf (((symbol-function 'glassmacs-sessions--prompt)
                  (lambda (_) second)))
         (let ((entry (glassmacs-r-submit-region-to-session
                       (point-min) (point-max))))
           (should (equal (glassmacs-entry-session-id entry)
                          (glassmacs-session-id second)))
           (should (equal (glassmacs-entry-source entry) "x <- 7"))
           (should (eq (caar gs-test--sent)
                       (glassmacs-session-process second)))))))))

(ert-deftest glassmacs-r-ess-region-evaluation-obeys-explicit-target ()
  (gs-test--with-env
   (let* ((session (glassmacs-sessions-register (gs-test--proc "R-ess-route")))
          (glassmacs-r-target-session (glassmacs-session-id session)))
     (with-temp-buffer
       (setq major-mode 'ess-r-mode)
       (insert "x <- 9")
       (let ((entry
              (glassmacs-r-ui--around-ess-eval-region
               (lambda (&rest _) (ert-fail "Explicit routing must queue"))
               (point-min) (point-max))))
         (should (equal (glassmacs-entry-session-id entry)
                        (glassmacs-session-id session)))
         (should (equal (glassmacs-entry-source entry) "x <- 9"))
         (should (eq (caar gs-test--sent)
                     (glassmacs-session-process session))))))))

(ert-deftest glassmacs-r-ess-function-evaluation-does-not-cross-function-boundaries ()
  (gs-test--with-env
   (let* ((session (glassmacs-sessions-register (gs-test--proc "R-function-boundary")))
          (glassmacs-r-target-session (glassmacs-session-id session)))
     (with-temp-buffer
       (setq major-mode 'ess-r-mode)
       (insert "first <- function() 1\n\nsecond <- function() 2\n")
       (goto-char (point-min))
       (search-forward "first")
       (search-forward "\n")
       (should-error
        (glassmacs-r-ui--around-ess-eval-function
         (lambda (&rest _) (ert-fail "No function should be queued"))
         nil))
       (should-not gs-test--sent)))))

(ert-deftest glassmacs-r-directory-inspection-does-not-query-r ()
  (let ((buffer-file-name "/tmp/project/source.R")
        (default-directory "/tmp/project/"))
    (cl-letf (((symbol-function 'glassmacs-sessions-resolve)
               (lambda (&rest _) (user-error "No selected session"))))
      (glassmacs-r-inspect-directories)
      (with-current-buffer "*Glassmacs R Directories*"
        (goto-char (point-min))
        (should (search-forward "/tmp/project/" nil t))
        (goto-char (point-min))
        (should (search-forward "No live R getwd() query was made" nil t)))
      (kill-buffer "*Glassmacs R Directories*"))))

(ert-deftest glassmacs-r-directory-inspection-distinguishes-remote-hosts ()
  (let ((buffer-file-name "/ssh:research:/home/user/project/analysis.R")
        (default-directory "/ssh:research:/home/user/project/"))
    (cl-letf (((symbol-function 'glassmacs-sessions-resolve)
               (lambda (&rest _) (user-error "No selected session"))))
      (glassmacs-r-inspect-directories)
      (with-current-buffer "*Glassmacs R Directories*"
        (goto-char (point-min))
        (should (search-forward "Document host: /ssh:research:" nil t))
        (goto-char (point-min))
        (should (search-forward "Project root: (remote; not queried)" nil t)))
      (kill-buffer "*Glassmacs R Directories*"))))

(provide 'test-glassmacs-r-ui)
;;; test-glassmacs-r-ui.el ends here
