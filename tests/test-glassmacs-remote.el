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
    (cl-letf (((symbol-function 'glassmacs-sessions-refresh)
               (lambda () (list session))))
      (with-temp-buffer
        (setq buffer-file-name "/ssh:host-a:/project/script.R")
        (let ((error-data
               (should-error
                (glassmacs-queue-submit "print('should not run')" session
                                        (list :buffer (buffer-name)))
                :type 'user-error)))
          (should (string-match-p "Remote source"
                                  (error-message-string error-data))))
        (should-not (glassmacs-session-entries session))
        (should (= glassmacs-sessions--entry-counter 0))))))

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


(ert-deftest glassmacs-remote-r-chunk-submission-checks-base-document ()
  "A chunk submitted from an indirect buffer must not bypass host checks."
  (require 'glassmacs-sessions)
  (let* ((session (glassmacs-session--make
                   :id "R-remote-chunk" :directory "/ssh:host-b:/work"))
         (glassmacs-sessions--list (list session)))
    (cl-letf (((symbol-function 'glassmacs-sessions-refresh)
               (lambda () (list session))))
      (with-temp-buffer
        (setq buffer-file-name "/ssh:host-a:/work/project.Rmd")
        (let ((base (current-buffer))
              (chunk (make-indirect-buffer (current-buffer)
                                           (generate-new-buffer-name
                                            " *glassmacs remote route chunk*"))))
          (unwind-protect
              (with-current-buffer chunk
                (let ((error-data
                       (should-error
                        (glassmacs-queue-submit
                         "rnorm(10)" session (list :buffer (buffer-name base)
                                                   :operation 'chunk))
                        :type 'user-error)))
                  (should (string-match-p "Remote source"
                                          (error-message-string error-data))))
                (should-not (glassmacs-session-entries session)))
            (kill-buffer chunk)))))))


(ert-deftest glassmacs-remote-r-rejected-choice-keeps-document-unlinked ()
  "Rejected cross-location selection must not write a target."
  (require 'glassmacs-sessions)
  (let ((session (glassmacs-session--make :id "R-wrong-host"
                                         :directory "/ssh:host-b:/work")))
    (cl-letf (((symbol-function 'glassmacs-sessions-refresh)
               (lambda () (list session)))
              ((symbol-function 'glassmacs-sessions-live)
               (lambda () (list session)))
              ((symbol-function 'glassmacs-sessions--prompt)
               (lambda (_live) session)))
      (with-temp-buffer
        (setq buffer-file-name "/ssh:host-a:/work/script.R")
        (should-error (glassmacs-r-resolve-source-target) :type 'user-error)
        (should-not glassmacs-r-target-session)
        (should-not glassmacs-r-cross-location-approval)))))

(ert-deftest glassmacs-remote-r-approval-from-chunk-is-valid-in-base ()
  "Approval granted from an indirect chunk is recognized from the base."
  (require 'glassmacs-sessions)
  (let* ((session (glassmacs-session--make :id "R-approved"
                                         :directory "/ssh:host-b:/work"))
         (glassmacs-sessions--list (list session)))
    (cl-letf (((symbol-function 'glassmacs-sessions-live)
               (lambda () (list session)))
              ((symbol-function 'yes-or-no-p)
               (lambda (_question) t)))
      (with-temp-buffer
        (setq buffer-file-name "/ssh:host-a:/work/document.Rmd"
              glassmacs-r-target-session "R-approved")
        (let ((base (current-buffer))
              (chunk (make-indirect-buffer (current-buffer)
                                           (generate-new-buffer-name " *remote R chunk approval*"))))
          (unwind-protect
              (progn
                (with-current-buffer chunk
                  (glassmacs-r-approve-cross-location-target)
                  (should (eq (glassmacs-r--check-cross-location session) session)))
                (with-current-buffer base
                  (should (eq (glassmacs-r--check-cross-location session) session))))
            (kill-buffer chunk)))))))

(ert-deftest glassmacs-remote-r-origin-invalid-fails-before-queue-mutation ()
  "A stale document origin is not treated as authorization."
  (require 'glassmacs-sessions)
  (let* ((session (glassmacs-session--make :id "R-origin" :directory "/"))
         (glassmacs-sessions--list (list session))
         (glassmacs-sessions--entry-counter 0))
    (cl-letf (((symbol-function 'glassmacs-sessions-refresh)
               (lambda () (list session))))
      (should-error (glassmacs-queue-submit "2+2" session
                                          '(:buffer " *missing remote source*"))
                    :type 'user-error)
      (should-not (glassmacs-session-entries session))
      (should (= glassmacs-sessions--entry-counter 0)))))


;;; Remote ESS launch: network-free wiring and safety regressions.

(ert-deftest glassmacs-remote-r-launch-context-is-network-free ()
  "A startup descriptor uses SSH/TRAMP without making a connection."
  (cl-letf (((symbol-function 'tramp-maybe-open-connection)
             (lambda (&rest _) (ert-fail "Launch context attempted SSH"))))
    (let ((context (glassmacs-remote-r-launch-context
                    "research" "/home/user/project with spaces")))
      (should (equal (plist-get context :directory)
                     "/ssh:research:/home/user/project with spaces/"))
      (should (equal (plist-get (plist-get context :identity) :host)
                     "research")))))

(ert-deftest glassmacs-remote-r-launch-context-rejects-invalid-input ()
  "Reject malformed locations before ESS startup."
  (should-error (glassmacs-remote-r-launch-context
                 "bad host" "/home/user") :type 'user-error)
  (should-error (glassmacs-remote-r-launch-context
                 "research" "relative/path") :type 'user-error))

(ert-deftest glassmacs-remote-r-ess-startup-uses-remote-directory ()
  "ESS keeps responsibility for starting R in the selected TRAMP context."
  (let (seen)
    (cl-letf (((symbol-function 'glassmacs-remote-r--ensure-ess) #'ignore)
              ((symbol-function 'call-interactively)
               (lambda (fn &rest _)
                 (setq seen (cons fn default-directory)))))
      (should-error (glassmacs-remote-r--start-ess
                     "/ssh:research:/home/user/project/")
                    :type 'user-error)
      (should (eq (car seen) 'R))
      (should (equal (cdr seen) "/ssh:research:/home/user/project/")))))

(ert-deftest glassmacs-remote-r-verify-rejects-local-console ()
  "A local process must not be misreported as a remote R process."
  (let* ((buffer (generate-new-buffer " *remote R verify local*"))
         (process (make-pipe-process :name "remote-r-test-local"
                                     :buffer buffer :noquery t)))
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (setq default-directory "/"))
          (should-error
           (glassmacs-remote-r--verify-process
            process "/ssh:research:/work/") :type 'user-error))
      (delete-process process)
      (kill-buffer buffer))))

(ert-deftest glassmacs-remote-r-verify-accepts-matching-context ()
  "Verification checks method and host, not the exact working directory."
  (let* ((buffer (generate-new-buffer " *remote R verify matched*"))
         (process (make-pipe-process :name "remote-r-test-matched"
                                     :buffer buffer :noquery t)))
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (setq default-directory "/ssh:research:/other/"))
          (should (eq (glassmacs-remote-r--verify-process
                       process "/ssh:research:/work/") process))
          (should-error (glassmacs-remote-r--verify-process
                         process "/ssh:different:/work/") :type 'user-error))
      (delete-process process)
      (kill-buffer buffer))))

(ert-deftest glassmacs-remote-r-start-failure-preserves-source-target ()
  "An ESS launch error does not alter the originating source's target."
  (require 'glassmacs-sessions)
  (with-temp-buffer
    (setq glassmacs-r-target-session "R-original")
    (cl-letf (((symbol-function 'glassmacs-remote--require-executable)
               (lambda (_name) "/usr/bin/ssh"))
              ((symbol-function 'glassmacs-remote-r--start-ess)
               (lambda (_dir) (signal 'file-error '("connection denied")))))
      (should-error
       (glassmacs-r-start-remote-session "research" "/home/user")
       :type 'user-error)
      (should (equal glassmacs-r-target-session "R-original")))))


(ert-deftest glassmacs-remote-r-ess-startup-detects-new-process-without-selection ()
  "An ESS-created R process is resolved even when selected window is unchanged."
  (let ((seen nil)
        (console (generate-new-buffer " *remote ESS new process*"))
        proc)
    (unwind-protect
        (progn
          (with-current-buffer console
            (setq default-directory "/ssh:research:/work/"))
          (cl-letf (((symbol-function 'glassmacs-remote-r--ensure-ess) #'ignore)
                    ((symbol-function 'call-interactively)
                     (lambda (_fn &rest _)
                       (setq seen default-directory)
                       (setq proc (make-pipe-process
                                   :name "mock remote ESS creation"
                                   :buffer console :noquery t)))))
            (should (eq (glassmacs-remote-r--start-ess
                         "/ssh:research:/work/") console))
            (should (equal seen "/ssh:research:/work/"))))
      (when (and proc (process-live-p proc)) (delete-process proc))
      (when (buffer-live-p console) (kill-buffer console)))))

(ert-deftest glassmacs-remote-r-ess-startup-rejects-local-process-with-remote-origin ()
  "Creating a local process while launched from TRAMP cannot pass verification."
  (let ((local-console (generate-new-buffer " *remote ESS local fallback*"))
        proc)
    (unwind-protect
        (progn
          (with-current-buffer local-console (setq default-directory "/"))
          (cl-letf (((symbol-function 'glassmacs-remote-r--ensure-ess) #'ignore)
                    ((symbol-function 'call-interactively)
                     (lambda (_fn &rest _)
                       (setq proc (make-pipe-process
                                   :name "mock ESS local fallback"
                                   :buffer local-console :noquery t)))))
            (should-error (glassmacs-remote-r--start-ess
                           "/ssh:research:/work/") :type 'user-error)))
      (when (and proc (process-live-p proc)) (delete-process proc))
      (when (buffer-live-p local-console) (kill-buffer local-console)))))

(provide 'test-glassmacs-remote)
;;; test-glassmacs-remote.el ends here
