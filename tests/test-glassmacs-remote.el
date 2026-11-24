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
                                   :buffer console :noquery t))
                       (with-current-buffer console
                         (setq-local ess-local-process-name
                                     (process-name proc))))))
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

(ert-deftest glassmacs-remote-r-transport-loss-orphans-queue-no-replay ()
  "Remote ESS transport loss cannot redispatch pending or uncertain commands."
  (require 'glassmacs-sessions)
  (let* ((running (glassmacs-entry--make :id "running-remote" :session-id "R-host"
                                         :source "slow()" :state 'running))
         (pending (glassmacs-entry--make :id "pending-remote" :session-id "R-host"
                                         :source "other()" :state 'pending))
         (session (glassmacs-session--make
                   :id "R-host" :directory "/ssh:research:/analysis/"
                   :entries (list running pending))))
    (glassmacs-sessions--terminate session)
    (should (glassmacs-session-disconnected session))
    (should (eq (glassmacs-r-session-connection-state session) 'disconnected))
    (should (eq (glassmacs-entry-state running) 'uncertain))
    (should (eq (glassmacs-entry-state pending) 'orphaned))
    (should (glassmacs-session-paused session))
    (should (null (glassmacs-queue--dispatchable session)))
    (should-error (glassmacs-queue-resume session) :type 'user-error)
    ;; Idempotent repeated sentinel/poll observations cannot alter outcomes.
    (glassmacs-sessions--terminate session)
    (should (eq (glassmacs-entry-state running) 'uncertain))
    (should (eq (glassmacs-entry-state pending) 'orphaned))))

(ert-deftest glassmacs-remote-r-local-termination-is-not-disconnection ()
  "Local session termination does not claim an SSH transport was lost."
  (require 'glassmacs-sessions)
  (let ((session (glassmacs-session--make
                  :id "R-local" :directory "/tmp/analysis/")))
    (glassmacs-sessions--terminate session)
    (should-not (glassmacs-session-disconnected session))
    (should (eq (glassmacs-r-session-connection-state session) 'terminated))))

(ert-deftest glassmacs-remote-r-disconnected-session-preserves-host ()
  "A disconnected session keeps its original host identity for diagnostics."
  (require 'glassmacs-sessions)
  (let ((session (glassmacs-session--make
                  :id "R-old" :directory "/ssh:cluster:/home/remote/")))
    (glassmacs-sessions--terminate session)
    (setf (glassmacs-session-directory session) "/tmp")
    (should (equal (plist-get
                    (glassmacs-r-session-execution-identity session) :host)
                   "cluster"))
    (should (equal (glassmacs-r-session-connection-state session)
                   'disconnected))))


(ert-deftest glassmacs-r-jobs-id-paths-do-not-connect ()
  "Malformed IDs must not construct arbitrary remote file paths."
  (require 'glassmacs-r-jobs)
  (should-error (glassmacs-r-jobs--paths "research" "/analysis/" "../etc")
                :type 'user-error)
  (let* ((id "glassmacs-r-aabbccddeeff001122334455")
         (paths (glassmacs-r-jobs--paths "research" "/analysis/" id)))
    (should (equal (plist-get paths :status)
                   (concat "/ssh:research:/analysis/.glassmacs-jobs/" id "/status")))))

(ert-deftest glassmacs-r-jobs-driver-contains-no-source-interpolation ()
  "Fixed launcher delegates to Rscript without embedding project source."
  (require 'glassmacs-r-jobs)
  (let ((driver (glassmacs-r-jobs--launcher)))
    (should (string-match-p "Rscript --vanilla job.R" driver))
    (should (string-match-p "exit:%s" driver))
    (should-not (string-match-p "/Users/\\|/home/research/" driver))))

(ert-deftest glassmacs-r-jobs-status-reader-maps-exit-codes ()
  "Server markers can be read without running SSH or ESS."
  (require 'glassmacs-r-jobs)
  (let ((glassmacs-r-jobs--list nil))
    (cl-letf (((symbol-function 'glassmacs-r-jobs--paths)
               (lambda (&rest _) '(:status "/mock/status")))
              ((symbol-function 'glassmacs-r-jobs--read-marker)
               (lambda (_path) "exit:0")))
      (should (eq (glassmacs-r-jobs-status
                   "research" "/analysis/" "glassmacs-r-aabbccddeeff001122334455")
                  'completed)))
    (cl-letf (((symbol-function 'glassmacs-r-jobs--paths)
               (lambda (&rest _) '(:status "/mock/status")))
              ((symbol-function 'glassmacs-r-jobs--read-marker)
               (lambda (_path) "exit:1")))
      (should (eq (glassmacs-r-jobs-status
                   "research" "/analysis/" "glassmacs-r-aabbccddeeff001122334455")
                  'failed)))))


(ert-deftest glassmacs-r-jobs-registry-roundtrip-private-and-network-free ()
  "Persist ID and remote context, but never copy R source into the index."
  (require 'glassmacs-r-jobs)
  (let* ((folder (make-temp-file "glassmacs-job-registry-" t))
         (glassmacs-r-jobs-record-file (expand-file-name "jobs.json" folder))
         (glassmacs-r-jobs--loaded t)
         (glassmacs-r-jobs--list
          (list (glassmacs-r-job--make
                 :id "glassmacs-r-aabbccddeeff001122334455"
                 :host "research" :directory "/work/with spaces/"
                 :root "/ssh:research:/work/with spaces/.glassmacs-jobs/test/"
                 :source "secret R source contents" :state 'submitted))))
    (unwind-protect
        (progn
          (glassmacs-r-jobs--save)
          (should (= (logand (file-modes glassmacs-r-jobs-record-file) #o777)
                     #o600))
          (with-temp-buffer
            (insert-file-contents glassmacs-r-jobs-record-file)
            (should-not (search-forward "secret R source contents" nil t)))
          (setq glassmacs-r-jobs--loaded nil
                glassmacs-r-jobs--list nil)
          (glassmacs-r-jobs--load)
          (should (= (length glassmacs-r-jobs--list) 1))
          (let ((job (car glassmacs-r-jobs--list)))
            (should (equal (glassmacs-r-job-host job) "research"))
            (should (equal (glassmacs-r-job-directory job)
                           "/work/with spaces/"))
            (should-not (glassmacs-r-job-source job))))
      (delete-directory folder t))))

(ert-deftest glassmacs-r-jobs-cancel-request-is-not-remote-kill ()
  "A confirmed cancel writes a marker without issuing kill to a PID."
  (require 'glassmacs-r-jobs)
  (let* ((folder (make-temp-file "glassmacs-job-cancel-" t))
         (source (expand-file-name "job.R" folder))
         (cancel (expand-file-name "cancel-request" folder))
         (ssh-calls 0))
    (unwind-protect
        (progn
          (with-temp-file source (insert "print(1)\n"))
          (cl-letf (((symbol-function 'glassmacs-r-jobs--paths)
                     (lambda (&rest _) (list :source source :cancel cancel)))
                    ((symbol-function 'glassmacs-r-jobs-status)
                     (lambda (&rest _) 'running))
                    ((symbol-function 'glassmacs-r-jobs--run)
                     (lambda (&rest _) (setq ssh-calls (1+ ssh-calls))))
                    ((symbol-function 'yes-or-no-p) (lambda (_question) t)))
            (should (eq (glassmacs-r-jobs-request-cancel
                         "research" "/project/" "glassmacs-r-aabbccddeeff001122334455")
                        'cancel-requested))
            (should (file-exists-p cancel))
            (should (= ssh-calls 0))))
      (delete-directory folder t))))

(ert-deftest glassmacs-r-jobs-launcher-runs-in-requested-directory ()
  "Run the POSIX driver with a fake local Rscript; no SSH required."
  (require 'glassmacs-r-jobs)
  (let* ((root (make-temp-file "glassmacs-job-driver-" t))
         (jobdir (expand-file-name "job" root))
         (workdir (expand-file-name "working area" root))
         (bin (expand-file-name "bin" root))
         (driver (expand-file-name "launch.sh" jobdir))
         (rscript (expand-file-name "Rscript" bin)))
    (unwind-protect
        (progn
          (mapc (lambda (dir) (make-directory dir t))
                (list jobdir workdir bin))
          (with-temp-file (expand-file-name "working-directory" jobdir)
            (insert workdir "\n"))
          (with-temp-file (expand-file-name "job.R" jobdir)
            (insert "print(42)\n"))
          (with-temp-file driver (insert (glassmacs-r-jobs--launcher)))
          (with-temp-file rscript (insert "#!/bin/sh\npwd\nexit 0\n"))
          (set-file-modes rscript #o700)
          (let ((default-directory (file-name-as-directory jobdir))
                (process-environment
                 (cons (concat "PATH=" bin path-separator (getenv "PATH"))
                       process-environment)))
            (should (= (process-file "sh" nil nil nil "launch.sh") 0)))
          (should (equal (glassmacs-r-jobs--read-marker
                          (expand-file-name "status" jobdir))
                         "exit:0"))
          (should (equal
                   (string-trim
                    (with-temp-buffer
                      (insert-file-contents (expand-file-name "stdout.log" jobdir))
                      (buffer-string)))
                   workdir)))
      (delete-directory root t))))


(ert-deftest glassmacs-r-artifacts-validates-paths-without-ssh ()
  "Reject traversal, TRAMP names, and unsupported artifact extensions."
  (require 'glassmacs-r-artifacts)
  (cl-letf (((symbol-function 'tramp-maybe-open-connection)
             (lambda (&rest _) (ert-fail "Path validation contacted SSH"))))
    (dolist (bad '("../private.png" "img/../private.svg"
                   "/etc/passwd" "/ssh:other:/plot.pdf" "plot.R"
                   "abc//plot.png" "~/plot.png" "plot\\evil.pdf"
                   "other/./plot.pdf" "plot.pdf/"))
      (should-error (glassmacs-r-artifacts--location "research" "/analysis/" bad)
                    :type 'user-error))
    (let ((context (glassmacs-r-artifacts--location
                    "research" "/analysis/" "plots/result 1.pdf")))
      (should (equal (plist-get context :remote-path)
                     "/ssh:research:/analysis/plots/result 1.pdf")))))

(ert-deftest glassmacs-r-artifacts-bounds-and-rejects-symlink-escape ()
  "Size checks reject excessive remote artifacts before preview or transfer."
  (require 'glassmacs-r-artifacts)
  (let* ((root (make-temp-file "glassmacs-artifact-root-" t))
         (outside (make-temp-file "glassmacs-artifact-outside-"))
         (file (expand-file-name "plot.pdf" root))
         (link (expand-file-name "external.pdf" root))
         (glassmacs-r-artifacts-max-bytes 4))
    (unwind-protect
        (progn
          (with-temp-file file (insert "12345"))
          (make-symbolic-link outside link t)
          (should-error
           (glassmacs-r-artifacts--bounded-file
            (list :root (file-name-as-directory root) :remote-path file))
           :type 'user-error)
          (should-error
           (glassmacs-r-artifacts--bounded-file
            (list :root (file-name-as-directory root) :remote-path link))
           :type 'user-error)
          (let ((glassmacs-r-artifacts-max-bytes 10))
            (should (equal (glassmacs-r-artifacts--bounded-file
                            (list :root (file-name-as-directory root)
                                  :remote-path file))
                           file))))
      (delete-directory root t)
      (delete-file outside))))

(ert-deftest glassmacs-r-artifacts-remote-session-provenance-is-recorded ()
  "Artifact identity follows the selected R session, never another host."
  (require 'glassmacs-r-artifacts)
  (require 'glassmacs-sessions)
  (let* ((session (glassmacs-session--make
                   :id "R-remote-plot" :directory "/ssh:research:/work/"
                   :execution-identity
                   (glassmacs-remote-execution-identity "/ssh:research:/work/")))
         (glassmacs-r-artifacts--history nil)
         (seen nil))
    (cl-letf (((symbol-function 'glassmacs-r-artifacts--bounded-file)
               (lambda (context)
                 (setq seen context)
                 "/ssh:research:/work/plots/graph.png"))
              ((symbol-function 'find-file-read-only)
               (lambda (_path) 'previewed)))
      (should (eq (glassmacs-r-artifacts-preview-session
                   session "plots/graph.png") 'previewed))
      (should (equal (plist-get seen :host) "research"))
      (should (equal (plist-get (car glassmacs-r-artifacts--history) :session)
                     "R-remote-plot"))
      (setf (glassmacs-session-directory session) "/ssh:other:/work/")
      (should-error
       (glassmacs-r-artifacts-preview-session session "plots/graph.png")
       :type 'user-error))))

(ert-deftest glassmacs-r-artifacts-download-never-overwrites ()
  "Reject an existing destination without contacting the remote source."
  (require 'glassmacs-r-artifacts)
  (let* ((root (make-temp-file "glassmacs-artifact-dest-" t))
         (dest (expand-file-name "already.pdf" root))
         (reads 0))
    (unwind-protect
        (progn
          (with-temp-file dest (insert "old"))
          (cl-letf (((symbol-function 'glassmacs-r-artifacts--bounded-file)
                     (lambda (&rest _) (setq reads (1+ reads)))))
            (should-error
             (glassmacs-r-artifacts-download "research" "/analysis/"
                                             "plot.pdf" dest)
             :type 'user-error)
            (should (= reads 0))))
      (delete-directory root t))))

(provide 'test-glassmacs-remote)
;;; test-glassmacs-remote.el ends here
