;;; test-glassmacs-sessions.el --- Session/queue ERT tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-sessions)

(defvar gs-test--sent nil)
(defvar gs-test--fail-send nil)
(defvar gs-test--procs nil)
(defvar ess-process-name-list)

(defmacro gs-test--with-env (&rest body)
  "Run BODY with fresh state and mocked sending."
  `(let ((glassmacs-sessions--list nil)
         (glassmacs-sessions--counter 0)
         (glassmacs-sessions--entry-counter 0)
         (glassmacs-sessions--history nil)
         (glassmacs-sessions--timer nil)
         (gs-test--sent nil)
         (gs-test--fail-send nil)
         (ess-process-name-list nil)
         (gs-test--procs nil))
     (cl-letf (((symbol-function 'glassmacs-sessions--send)
                (lambda (process string)
                  (when gs-test--fail-send (error "send failed"))
                  (push (cons process string) gs-test--sent)
                  (process-put process 'busy t))))
       (unwind-protect (progn ,@body)
         (glassmacs-sessions--cancel-timer)
         (mapc #'delete-process gs-test--procs)))))

(defun gs-test--proc (name)
  (let ((p (make-process :name name :command '("cat") :connection-type 'pipe
                         :noquery t)))
    (push p gs-test--procs)
    p))

(defmacro gs-test--confirming (answer &rest body)
  `(cl-letf (((symbol-function 'glassmacs-queue--ask)
              (lambda (_entries _action) ,answer)))
     ,@body))

(defun gs-test--finish-running (process)
  (process-put process 'busy nil))

(ert-deftest glassmacs-sessions-identity-and-registration ()
  (gs-test--with-env
   (let* ((a (gs-test--proc "R")) (b (gs-test--proc "R:2"))
          (sa (glassmacs-sessions-register a))
          (sb (glassmacs-sessions-register b)))
     (should (equal (glassmacs-session-id sa) "R-1"))
     (should (equal (glassmacs-session-id sb) "R-2"))
     (should (eq sa (glassmacs-sessions-register a)))
     (should (eq (glassmacs-sessions-find b) sb))
     (should (= 2 (length (glassmacs-sessions-live)))))))

(ert-deftest glassmacs-sessions-discovers-ess-processes ()
  (gs-test--with-env
   (let ((a (gs-test--proc "R")))
     (setq ess-process-name-list (list (list (process-name a))))
     (should (= 1 (length (glassmacs-sessions-refresh))))
     (should (eq a (glassmacs-session-process (car (glassmacs-sessions-live))))))))

(ert-deftest glassmacs-sessions-does-not-guess-among-several ()
  (gs-test--with-env
   (glassmacs-sessions-register (gs-test--proc "R"))
   (glassmacs-sessions-register (gs-test--proc "R:2"))
   (should-error (glassmacs-queue-submit "1+1") :type 'user-error)
   (should-not gs-test--sent)
   (with-temp-buffer
     (setq glassmacs-r-target-session "R-2")
     (let ((e (glassmacs-queue-submit "1+1")))
       (should (equal (glassmacs-entry-session-id e) "R-2"))
       (should (equal (process-name (car (car gs-test--sent))) "R:2"))))))

(ert-deftest glassmacs-sessions-missing-session-is-an-error ()
  (gs-test--with-env
   (should-error (glassmacs-queue-submit "1+1") :type 'user-error)
   (should-error (glassmacs-queue-submit "  \n") :type 'user-error)))

(ert-deftest glassmacs-queue-fifo-one-at-a-time-multiline-snapshot ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (text (propertize "f <- function(x) {\n  x + 1\n}" 'face 'bold))
          (e1 (glassmacs-queue-submit text))
          (e2 (glassmacs-queue-submit "f(2)"))
          (e3 (glassmacs-queue-submit "f(3)")))
     (should (equal (glassmacs-entry-source e1) "f <- function(x) {\n  x + 1\n}"))
     (should-not (text-properties-at 0 (glassmacs-entry-source e1)))
     ;; Multiline expression sent whole, once.
     (should (equal (mapcar #'cdr gs-test--sent) (list (glassmacs-entry-source e1))))
     (should (eq (glassmacs-entry-state e1) 'running))
     (should (equal (glassmacs-queue-pending s) (list e2 e3)))
     (glassmacs-sessions--pump s)       ; still busy: nothing new
     (should (= 1 (length gs-test--sent)))
     (gs-test--finish-running p)
     (glassmacs-sessions--pump s)
     (should (eq (glassmacs-entry-state e1) 'completed))
     (should (eq (glassmacs-entry-state e2) 'running))
     (gs-test--finish-running p)
     (glassmacs-sessions--pump s)
     (glassmacs-sessions--pump s)
     (should (equal (mapcar #'cdr (reverse gs-test--sent))
                    (list (glassmacs-entry-source e1) "f(2)" "f(3)"))))))

(ert-deftest glassmacs-queue-snapshot-immune-to-buffer-edits ()
  (gs-test--with-env
   (let ((p (gs-test--proc "R")))
     (process-put p 'busy t)
     (glassmacs-sessions-register p)
     (with-temp-buffer
       (insert "x <- 1")
       (let ((e (glassmacs-r-submit-region (point-min) (point-max))))
         (erase-buffer) (insert "x <- 2")
         (should (equal (glassmacs-entry-source e) "x <- 1")))))))

(ert-deftest glassmacs-queue-pause-resume ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (glassmacs-queue-pause s)
     (let ((e (glassmacs-queue-submit "1")))
       (should (eq (glassmacs-entry-state e) 'pending))
       (should-not gs-test--sent)
       (glassmacs-queue-resume s)
       (should (eq (glassmacs-entry-state e) 'running))))))

(ert-deftest glassmacs-queue-waits-while-r-busy ()
  (gs-test--with-env
   (let ((p (gs-test--proc "R")))
     (process-put p 'busy t)
     (let ((e (glassmacs-queue-submit "1" (glassmacs-sessions-register p))))
       (should (eq (glassmacs-entry-state e) 'pending))))))

(ert-deftest glassmacs-queue-send-failure-keeps-command-and-pauses ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (gs-test--fail-send t)
          (e1 (glassmacs-queue-submit "a"))
          (e2 (glassmacs-queue-submit "b")))
     (should (eq (glassmacs-entry-state e1) 'failed))
     (should (equal (glassmacs-entry-source e1) "a"))
     (should (glassmacs-session-paused s))
     (should (eq (glassmacs-entry-state e2) 'pending))
     (should (equal (glassmacs-entry-reason e1) "send failed")))))

(ert-deftest glassmacs-queue-continuation-prompt-is-uncertain ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (e (glassmacs-queue-submit "f(")))
     (process-put p 'sec-prompt t)
     (glassmacs-sessions--pump s)
     (should (eq (glassmacs-entry-state e) 'uncertain))
     (should (glassmacs-session-paused s)))))

;;; Removal safeguards

(ert-deftest glassmacs-queue-removal-rejected-without-confirmation ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (glassmacs-queue-submit "run")
     (let ((e (glassmacs-queue-submit "later")))
       ;; Non-interactive default (no mock) keeps the command.
       (should-not (glassmacs-queue-remove (glassmacs-entry-id e)))
       (gs-test--confirming nil
         (should-not (glassmacs-queue-remove (glassmacs-entry-id e)))
         (should-not (glassmacs-queue-clear s)))
       (should (eq (glassmacs-entry-state e) 'pending))
       (should-not (cl-find :removed (glassmacs-sessions-history)
                            :key (lambda (h) (plist-get h :event))))))))

(ert-deftest glassmacs-queue-confirmed-removal-is-recorded ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (glassmacs-queue-submit "run")
     (let ((a (glassmacs-queue-submit "set.seed(1)"))
           (b (glassmacs-queue-submit "rnorm(1)")))
       (gs-test--confirming t
         (should (equal (list b) (glassmacs-queue-remove (glassmacs-entry-id b)))))
       (should (eq (glassmacs-entry-state b) 'removed))
       (should (= 2 (glassmacs-entry-original-position b)))
       (should (equal (glassmacs-entry-source b) "rnorm(1)"))
       (should (equal (glassmacs-queue-pending s) (list a)))
       (should (memq b (glassmacs-session-entries s)))
       (let ((ev (cl-find :removed (glassmacs-sessions-history)
                          :key (lambda (h) (plist-get h :event)))))
         (should (equal (plist-get ev :entry) (glassmacs-entry-id b)))
         (should (= 2 (plist-get ev :position)))
         (should (equal (plist-get ev :source) "rnorm(1)"))
         (should (plist-get ev :time)))))))

(ert-deftest glassmacs-queue-bulk-removal-requires-confirmation ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (glassmacs-queue-submit "run")
     (let* ((a (glassmacs-queue-submit "a")) (b (glassmacs-queue-submit "b"))
            (asked 0))
       (cl-letf (((symbol-function 'glassmacs-queue--ask)
                  (lambda (entries _) (cl-incf asked) (and (> asked 1) (= 2 (length entries))))))
         (should-not (glassmacs-queue-clear s))
         (should (equal (glassmacs-queue-pending s) (list a b)))
         (should (= 2 (length (glassmacs-queue-clear s)))))
       (should (= 2 asked))
       (should-not (glassmacs-queue-pending s))
       (should (equal '(1 2) (list (glassmacs-entry-original-position a)
                                   (glassmacs-entry-original-position b))))))))

(ert-deftest glassmacs-queue-removal-ignores-nonpending ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (running (glassmacs-queue-submit "run")))
     (gs-test--confirming t
       (should-error (glassmacs-queue-remove (glassmacs-entry-id running))
                     :type 'user-error)
       (should-not (glassmacs-queue-clear s)))
     (should (eq (glassmacs-entry-state running) 'running)))))

(ert-deftest glassmacs-queue-interrupt-is-distinct-from-removal ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (running (glassmacs-queue-submit "long()"))
          (next (glassmacs-queue-submit "next()")))
     (cl-letf (((symbol-function 'interrupt-process) #'ignore))
       (glassmacs-queue-interrupt s))
     (should (eq (glassmacs-entry-state running) 'uncertain))
     (should (eq (glassmacs-entry-state next) 'pending))
     (should (glassmacs-session-paused s))
     (should-not (cl-find :removed (glassmacs-sessions-history)
                          :key (lambda (h) (plist-get h :event)))))))

;;; Termination

(ert-deftest glassmacs-sessions-termination-preserves-records ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (running (glassmacs-queue-submit "a"))
          (pending (glassmacs-queue-submit "b")))
     (delete-process p)
     (glassmacs-sessions-refresh)
     (should (eq (glassmacs-session-state s) 'terminated))
     (should (eq (glassmacs-entry-state running) 'uncertain))
     (should (eq (glassmacs-entry-state pending) 'orphaned))
     (should (equal (glassmacs-entry-source pending) "b"))
     (should (memq pending (glassmacs-session-entries s)))
     (should-not (glassmacs-sessions-live))
     ;; No replay, no new submissions, no resume.
     (should-error (glassmacs-queue-resume s) :type 'user-error)
     (should-error (glassmacs-queue-submit "c" s) :type 'user-error)
     (glassmacs-sessions--pump s)
     (should (= 1 (length gs-test--sent)))
     (let ((events (mapcar (lambda (h) (plist-get h :event)) (glassmacs-sessions-history))))
       (should (memq :orphaned events))
       (should (memq :uncertain events))
       (should (memq :session-terminated events))))))

(ert-deftest glassmacs-sessions-orphaned-pending-cannot-be-removed-silently ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (glassmacs-queue-submit "a")
     (let ((b (glassmacs-queue-submit "b")))
       (delete-process p)
       (glassmacs-sessions-refresh)
       (gs-test--confirming t
         (should-not (glassmacs-queue-clear s)))
       (should (eq (glassmacs-entry-state b) 'orphaned))))))

(ert-deftest glassmacs-sessions-timer-polls-without-blocking ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p))
          (e (glassmacs-queue-submit "a")))
     (should (timerp glassmacs-sessions--timer))
     (gs-test--finish-running p)
     (glassmacs-sessions--tick)
     (should (eq (glassmacs-entry-state e) 'completed))
     (should-not glassmacs-sessions--timer)
     (should (glassmacs-sessions-ready-p s)))))

(ert-deftest glassmacs-queue-remove-entries-confirms-once ()
  (gs-test--with-env
   (let* ((p (gs-test--proc "R")) (s (glassmacs-sessions-register p)))
     (glassmacs-queue-submit "run")
     (let ((a (glassmacs-queue-submit "a")) (b (glassmacs-queue-submit "b"))
           (c (glassmacs-queue-submit "c")))
       (gs-test--confirming nil
         (should-not (glassmacs-queue-remove-entries
                      (list (glassmacs-entry-id a) (glassmacs-entry-id b)))))
       (should (equal (glassmacs-queue-pending s) (list a b c)))
       (gs-test--confirming t
         (should (= 2 (length (glassmacs-queue-remove-entries
                               (list (glassmacs-entry-id a) (glassmacs-entry-id c)))))))
       (should (equal (glassmacs-queue-pending s) (list b)))))))

;;; Optional real R/ESS integration

(defun gs-test--ess-and-r-p ()
  (and (executable-find "R") (locate-library "ess-site")
       (not (getenv "GLASSMACS_SKIP_INTEGRATION"))))

(ert-deftest glassmacs-sessions-integration-real-ess ()
  (skip-unless (gs-test--ess-and-r-p))
  (require 'ess-site)
  (let ((glassmacs-sessions--list nil) (glassmacs-sessions--history nil)
        (default-directory temporary-file-directory)
        (ess-ask-for-ess-directory nil) (ess-history-file nil)
        (inhibit-message t) buffer)
    (unwind-protect
        (progn
          (save-window-excursion (setq buffer (R)))
          (let* ((s (car (glassmacs-sessions-refresh)))
                 (p (glassmacs-session-process s)))
            (should s)
            (let ((e1 (glassmacs-queue-submit "x <- 41L\nx + 1L" s))
                  (e2 (glassmacs-queue-submit "cat('glassmacs-ok\\n')" s)))
              (let ((deadline (+ (float-time) 30)))
                (while (and (< (float-time) deadline)
                            (not (eq (glassmacs-entry-state e2) 'completed)))
                  (accept-process-output p 0.1)
                  (glassmacs-sessions--tick)))
              (should (eq (glassmacs-entry-state e1) 'completed))
              (should (eq (glassmacs-entry-state e2) 'completed))
              (with-current-buffer buffer
                (should (string-match-p "glassmacs-ok" (buffer-string)))))
            (let ((pending (progn (glassmacs-queue-submit "Sys.sleep(5)" s)
                                  (glassmacs-queue-submit "y <- 1" s))))
              (kill-process p)
              (let ((deadline (+ (float-time) 10)))
                (while (and (< (float-time) deadline)
                            (eq (glassmacs-session-state s) 'ready))
                  (accept-process-output nil 0.1)
                  (glassmacs-sessions-refresh)))
              (should (eq (glassmacs-session-state s) 'terminated))
              (should (eq (glassmacs-entry-state pending) 'orphaned)))))
      (glassmacs-sessions--cancel-timer)
      (when (buffer-live-p buffer)
        (let ((kill-buffer-query-functions nil)) (kill-buffer buffer))))))

(provide 'test-glassmacs-sessions)
;;; test-glassmacs-sessions.el ends here
