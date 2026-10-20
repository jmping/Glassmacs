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
  (let* ((item (lookup-key glassmacs-r-ui-context-menu [queue]))
         (enable-form (plist-get (cddr item) :enable)))
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
       (should (eq (glassmacs-session-state other-session) 'ready))))))

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

(ert-deftest glassmacs-r-directory-inspection-does-not-query-r ()
  (let ((buffer-file-name "/tmp/project/source.R")
        (default-directory "/tmp/project/"))
    (cl-letf (((symbol-function 'glassmacs-sessions-resolve)
               (lambda (&rest _) (user-error "No selected session"))))
      (glassmacs-r-inspect-directories)
      (with-current-buffer "*Glassmacs R Directories*"
        (should (search-forward "/tmp/project/source.R" nil t))
        (should (search-forward "No live R getwd() query was made" nil t)))
      (kill-buffer "*Glassmacs R Directories*"))))

(provide 'test-glassmacs-r-ui)
;;; test-glassmacs-r-ui.el ends here
