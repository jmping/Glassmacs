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
  (let* ((directory (make-temp-file "glassmacs-remote-startup-" t))
         (launcher (expand-file-name "scripts/glassmacs" glassmacs-root))
         (output (generate-new-buffer " *glassmacs remote startup*"))
         (status nil))
    (unwind-protect
        (let ((process-environment (copy-sequence process-environment)))
          (setenv "GLASSMACS_HOME" directory)
          (setq status
                (call-process
                 launcher nil output t "--batch" "--eval"
                 "(progn (require 'tramp) (when (tramp-list-connections) (error \"TRAMP connected at startup\")))")))
      (when (buffer-live-p output)
        (kill-buffer output))
      (delete-directory directory t))
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


;;; Remote R routing: metadata and safety checks are network-free.

(ert-deftest glassmacs-remote-identity-parses-location-without-paths ()
  "Session identity contains host information but no remote file path."
  (let ((id (glassmacs-remote-execution-identity
             "/ssh:research:/home/researcher/private/source.R")))
    (should (eq (plist-get id :kind) 'remote))
    (should (equal (plist-get id :method) "ssh"))
    (should (equal (plist-get id :host) "research"))
    (should (equal (glassmacs-remote-execution-label id) "ssh:research"))
    (should-not (string-match-p "private\\|researcher" (prin1-to-string id))))
  (should (equal (glassmacs-remote-execution-identity "/tmp/work.R")
                 '(:kind local))))

(ert-deftest glassmacs-remote-identity-cross-host-policy ()
  "Remote source cannot silently route to a different context."
  (let ((one (glassmacs-remote-execution-identity "/ssh:host-a:/src.R"))
        (same (glassmacs-remote-execution-identity "/ssh:host-a:/elsewhere.R"))
        (other (glassmacs-remote-execution-identity "/ssh:host-b:/src.R"))
        (local (glassmacs-remote-execution-identity "/tmp/src.R")))
    (should-not (glassmacs-remote-cross-location-p one same))
    (should (glassmacs-remote-cross-location-p one other))
    (should (glassmacs-remote-cross-location-p one local))
    (should-not (glassmacs-remote-cross-location-p local other))
    (should-not (glassmacs-remote-cross-location-p local local))))

(ert-deftest glassmacs-remote-r-identity-is-snapshot-not-buffer-mutation ()
  "Session registration identity stays fixed if its directory changes."
  (require 'glassmacs-sessions)
  (let ((session (glassmacs-session--make
                  :id "R-test" :directory "/ssh:host-b:/old"
                  :execution-identity
                  (glassmacs-remote-execution-identity "/ssh:host-a:/old"))))
    (setf (glassmacs-session-directory session) "/tmp/new")
    (should (equal (plist-get (glassmacs-r-session-execution-identity session)
                              :host)
                   "host-a"))))

(ert-deftest glassmacs-remote-r-rejects-mismatched-route-before-queueing ()
  "A remote source targeting another host leaves its queue untouched."
  (require 'glassmacs-sessions)
  (let* ((session (glassmacs-session--make
                   :id "R-mismatch" :directory "/ssh:host-b:/project"))
         (glassmacs-sessions--list (list session))
         (glassmacs-sessions--entry-counter 0))
    (with-temp-buffer
      (setq buffer-file-name "/ssh:host-a:/project/script.R")
      (should-error
       (glassmacs-queue-submit "print('should not run')" session
                               (list :buffer (buffer-name)))
       :type 'user-error)
      (should-not (glassmacs-session-entries session))
      (should (= glassmacs-sessions--entry-counter 0)))))

(ert-deftest glassmacs-remote-r-approval-is-document-and-target-specific ()
  "A confirmed approval does not authorize changed source or R targets."
  (require 'glassmacs-sessions)
  (let* ((one (glassmacs-session--make :id "R-host-b"
                                      :directory "/ssh:host-b:/project"))
         (other (glassmacs-session--make :id "R-host-c"
                                        :directory "/ssh:host-c:/project"))
         (glassmacs-sessions--list (list one other)))
    (cl-letf (((symbol-function 'glassmacs-sessions-live)
               (lambda () (list one other)))
              ((symbol-function 'yes-or-no-p) (lambda (_prompt) t)))
      (with-temp-buffer
        (setq buffer-file-name "/ssh:host-a:/project/script.R"
              glassmacs-r-target-session "R-host-b")
        (should-error (glassmacs-r--check-cross-location one)
                      :type 'user-error)
        (glassmacs-r-approve-cross-location-target)
        (should (eq (glassmacs-r--check-cross-location one) one))
        (should-error (glassmacs-r--check-cross-location other)
                      :type 'user-error)
        (setq buffer-file-name "/ssh:host-d:/project/script.R")
        (should-error (glassmacs-r--check-cross-location one)
                      :type 'user-error)
        (glassmacs-r--set-document-target "R-host-b")
        (should-not glassmacs-r-cross-location-approval)))))

(ert-deftest glassmacs-remote-r-declining-approval-does-not-authorize ()
  "Declined confirmation leaves the cross-host block intact."
  (require 'glassmacs-sessions)
  (let* ((session (glassmacs-session--make
                   :id "R-host-b" :directory "/ssh:host-b:/project"))
         (glassmacs-sessions--list (list session)))
    (cl-letf (((symbol-function 'glassmacs-sessions-live)
               (lambda () (list session)))
              ((symbol-function 'yes-or-no-p) (lambda (_prompt) nil)))
      (with-temp-buffer
        (setq buffer-file-name "/ssh:host-a:/project/script.R"
              glassmacs-r-target-session "R-host-b")
        (should-error (glassmacs-r-approve-cross-location-target)
                      :type 'user-error)
        (should-not glassmacs-r-cross-location-approval)))))


(ert-deftest glassmacs-remote-r-modeline-identifies-remote-target ()
  "Linked remote R sessions advertise their location without paths."
  (require 'glassmacs-sessions)
  (let* ((session (glassmacs-session--make
                   :id "R-remote" :directory "/ssh:host-a:/private/location"))
         (glassmacs-sessions--list (list session)))
    (cl-letf (((symbol-function 'glassmacs-sessions--process-live-p)
               (lambda (_process) t)))
      (with-temp-buffer
        (setq glassmacs-r-target-session "R-remote")
        (should (equal (glassmacs-r--target-lighter)
                       " R[R-remote@ssh:host-a]"))
        (should-not (string-match-p "private" (glassmacs-r--target-lighter)))))))

(provide 'test-glassmacs-remote)
;;; test-glassmacs-remote.el ends here
