;;; test-glassmacs-remote.el --- Remote workflow ERT tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-remote)

(ert-deftest glassmacs-remote-path-construction-uses-tramp-and-preserves-path ()
  (should (equal (glassmacs-remote-make-path "research" "/home/me/a file.R")
                 "/ssh:research:/home/me/a file.R")))

(ert-deftest glassmacs-remote-path-construction-preserves-shell-metacharacters ()
  (should
   (equal (glassmacs-remote-make-path "research" "/home/me/$draft; notes.R")
          "/ssh:research:/home/me/$draft; notes.R")))

(ert-deftest glassmacs-remote-path-construction-rejects-invalid-input ()
  (dolist (host '("" "bad host" "user@host" "host:22" "host/path" "host*"))
    (should-error (glassmacs-remote-make-path host "/tmp/file")
                  :type 'user-error))
  (dolist (path '("" "relative/path" "file.R"))
    (should-error (glassmacs-remote-make-path "research" path)
                  :type 'user-error)))

(ert-deftest glassmacs-remote-context-distinguishes-remote-and-local-paths ()
  (let ((remote (glassmacs-remote-make-path "research" "/home/me/project"))
        (local "/tmp/glassmacs-local-file"))
    (should (equal (plist-get (glassmacs-remote-context remote) :method) "ssh"))
    (should (equal (plist-get (glassmacs-remote-context remote) :host) "research"))
    (should (equal (plist-get (glassmacs-remote-context remote) :localname)
                   "/home/me/project"))
    (should-not (glassmacs-remote-context local))))

(ert-deftest glassmacs-remote-missing-tools-are-reported-without-running-them ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_program) nil)))
    (should-error (glassmacs-remote--require-executable "ssh") :type 'user-error)
    (should-error (glassmacs-remote-mosh "research") :type 'user-error)
    (should (equal (glassmacs-remote-tool-status)
                   '(("ssh") ("mosh") ("tmux"))))))

(ert-deftest glassmacs-remote-mosh-reports-a-missing-local-executable ()
  (cl-letf (((symbol-function 'executable-find)
             (lambda (program)
               (and (equal program "ssh") "/usr/bin/ssh"))))
    (should-error (glassmacs-remote-mosh "research") :type 'user-error)))

(ert-deftest glassmacs-remote-open-surfaces-tramp-file-errors ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_program) "/usr/bin/ssh"))
            ((symbol-function 'find-file)
             (lambda (_path) (signal 'file-error '("Connection timed out")))))
    (should-error (glassmacs-remote-open "research" "/home/me/file.R")
                  :type 'user-error)))

(ert-deftest glassmacs-remote-shell-uses-remote-default-directory ()
  (let (shell-directory)
    (cl-letf (((symbol-function 'executable-find) (lambda (_program) "/usr/bin/ssh"))
              ((symbol-function 'shell)
               (lambda (buffer-name)
                 (setq shell-directory default-directory)
                 (get-buffer-create buffer-name))))
      (glassmacs-remote-shell "research" "/home/me/project with spaces")
      (should (equal shell-directory
                     "/ssh:research:/home/me/project with spaces/")))))

(ert-deftest glassmacs-remote-mosh-passes-host-as-an-argument ()
  (let (program arguments)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (name)
                 (pcase name
                   ("ssh" "/usr/bin/ssh")
                   ("mosh" "/usr/bin/mosh"))))
              ((symbol-function 'make-term)
               (lambda (name command startfile &rest switches)
                 (setq program command
                       arguments (cons startfile switches))
                 (get-buffer-create (format "*%s*" name))))
              ((symbol-function 'term-char-mode) #'ignore)
              ((symbol-function 'pop-to-buffer) #'ignore))
      (unwind-protect
          (progn
            (glassmacs-remote-mosh "research")
            (should (equal program "/usr/bin/mosh"))
            (should (equal arguments '(nil "research"))))
      (let ((buffer (get-buffer "*Glassmacs Mosh research*")))
        (when (buffer-live-p buffer)
          (kill-buffer buffer)))))))

(ert-deftest glassmacs-remote-inspect-does-not-connect ()
  (let ((path (glassmacs-remote-make-path "research" "/home/me/project"))
        buffer)
    (unwind-protect
        (progn
          (setq buffer (get-buffer-create " *glassmacs remote inspect test*"))
          (with-current-buffer buffer
            (setq buffer-file-name path)
            (let ((default-directory "/"))
              (glassmacs-remote-inspect)))
          (with-current-buffer "*Glassmacs Remote*"
            (goto-char (point-min))
            (should (search-forward "Host: research" nil t))
            (should (search-forward "no existing connection buffer" nil t))))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (when (get-buffer "*Glassmacs Remote*")
        (kill-buffer "*Glassmacs Remote*")))))

(ert-deftest glassmacs-remote-cleanup-uses-tramp-and-preserves-password-cache ()
  (let ((path (glassmacs-remote-make-path "research" "/home/me/file.R"))
        cleanup-arguments
        (buffer-file-name nil)
        (default-directory "/"))
    (cl-letf (((symbol-function 'tramp-cleanup-connection)
               (lambda (&rest arguments)
                 (setq cleanup-arguments arguments))))
      (with-temp-buffer
        (setq buffer-file-name path)
        (glassmacs-remote-cleanup-connection))
      (should (equal (nth 1 cleanup-arguments) nil))
      (should (eq (nth 2 cleanup-arguments) t))
      (should (equal (tramp-file-name-host (car cleanup-arguments))
                     "research")))))

(ert-deftest glassmacs-remote-startup-does-not-connect ()
  (let* ((output (generate-new-buffer " *glassmacs remote startup*"))
         (status nil))
    (unwind-protect
        (setq status
              (call-process
               "emacs" nil output t "-Q" "--batch"
               "-l" (expand-file-name "init.el" glassmacs-root)
               "--eval"
               "(progn (require 'tramp) (when (tramp-list-connections) (error \"TRAMP connected at startup\")))"))
      (when (buffer-live-p output)
        (kill-buffer output)))
    (should (and (integerp status) (zerop status)))))

(ert-deftest glassmacs-remote-module-preserves-local-file-editing ()
  (let* ((directory (make-temp-file "glassmacs-remote-local-" t))
         (file (expand-file-name "ordinary.txt" directory))
         buffer)
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "local\n"))
          (setq buffer (find-file-noselect file))
          (with-current-buffer buffer
            (goto-char (point-max))
            (insert "still local\n")
            (save-buffer))
          (with-temp-buffer
            (insert-file-contents file)
            (should (equal (buffer-string) "local\nstill local\n"))))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (delete-directory directory t))))

(provide 'test-glassmacs-remote)
;;; test-glassmacs-remote.el ends here
