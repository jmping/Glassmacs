;;; glassmacs-r-jobs.el --- Durable Rscript job primitives -*- lexical-binding: t; -*-

(require 'cl-lib)

(require 'subr-x)
(require 'json)

(require 'glassmacs-remote)

(defgroup glassmacs-r-jobs nil "Durable remote Rscript jobs." :group 'glassmacs-remote)

(cl-defstruct (glassmacs-r-job (:constructor glassmacs-r-job--make) (:copier nil)) id host directory root source state)

(defvar glassmacs-r-jobs--list nil "Known durable R jobs, loaded from local metadata.")
(defvar glassmacs-r-jobs--loaded nil "Whether the local job index has been read.")
(defcustom glassmacs-r-jobs-record-file
  (expand-file-name "r-jobs.json" user-emacs-directory)
  "Private local JSON index of job IDs, SSH aliases and directories.
No secrets, R source code, or remote output are stored in this file."
  :type 'file :group 'glassmacs-r-jobs)

(defun glassmacs-r-jobs--row (job)
  "Serialize only the safe metadata for JOB."
  (list (cons 'id (glassmacs-r-job-id job))
        (cons 'host (glassmacs-r-job-host job))
        (cons 'directory (glassmacs-r-job-directory job))
        (cons 'state (symbol-name (glassmacs-r-job-state job)))))

(defun glassmacs-r-jobs--decode-row (row)
  "Decode one locally stored row without connecting to SSH."
  (let* ((id (alist-get 'id row))
         (host (alist-get 'host row))
         (directory (alist-get 'directory row))
         (state (alist-get 'state row)))
    (glassmacs-r-jobs--validate-id id)
    (glassmacs-remote-r-launch-context host directory)
    (glassmacs-r-job--make :id id :host host :directory directory
                          :root (plist-get (glassmacs-r-jobs--paths
                                            host directory id) :root)
                          :state (if (member state
                                             '("submitting" "submitted" "starting"
                                               "running" "cancel-requested"
                                               "cancelled" "completed" "failed"
                                               "unknown" "unreachable"))
                                     (intern state) 'unknown))))

(defun glassmacs-r-jobs--load ()
  "Load a local JSON registry once; never execute code from the file."
  (unless glassmacs-r-jobs--loaded
    (when (file-remote-p glassmacs-r-jobs-record-file)
      (user-error "Durable R job index must be stored locally"))
    (when (file-exists-p glassmacs-r-jobs-record-file)
      (let ((json-object-type 'alist)
            (json-array-type 'list)
            (json-key-type 'symbol))
        (let ((data (json-read-file glassmacs-r-jobs-record-file)))
          (unless (equal (alist-get 'version data) 1)
            (user-error "Unsupported durable R job index version"))
          (setq glassmacs-r-jobs--list
                (mapcar #'glassmacs-r-jobs--decode-row
                        (alist-get 'jobs data))))))
    (setq glassmacs-r-jobs--loaded t))
  glassmacs-r-jobs--list)

(defun glassmacs-r-jobs--save ()
  "Atomically save a mode-0600 JSON index on the local machine."
  (when (file-remote-p glassmacs-r-jobs-record-file)
    (user-error "Durable R job index must be stored locally"))
  (let* ((folder (file-name-directory glassmacs-r-jobs-record-file))
         (content (json-encode
                   (list (cons 'version 1)
                         (cons 'jobs (vconcat
                                      (mapcar #'glassmacs-r-jobs--row
                                              glassmacs-r-jobs--list))))))
         temp-file)
    (make-directory folder t)
    (unwind-protect
        (progn
          (setq temp-file (make-temp-file (expand-file-name ".r-jobs-" folder)))
          (with-temp-file temp-file (insert content "\n"))
          (set-file-modes temp-file #o600)
          (rename-file temp-file glassmacs-r-jobs-record-file t))
      (when (and temp-file (file-exists-p temp-file))
        (delete-file temp-file)))))

(defconst glassmacs-r-jobs--id-regexp "\\`glassmacs-r-[[:xdigit:]]\\{24\\}\\'")

(defun glassmacs-r-jobs--validate-id (id)
  "Return a structurally valid opaque ID."
  (unless (and (stringp id) (string-match-p glassmacs-r-jobs--id-regexp id))
    (user-error "Invalid durable R job ID"))
  id)

(defun glassmacs-r-jobs--new-id ()
  "Return a collision-resistant job label, not a security token."
  (concat "glassmacs-r-" (substring (secure-hash 'sha256 (format "%s:%s:%s:%s" (emacs-pid) (float-time) (random) (make-temp-name "rjob"))) 0 24)))

(defun glassmacs-r-jobs--paths (host directory id)
  "Derive an SSH/TRAMP job directory without any network calls."
  (glassmacs-r-jobs--validate-id id)
  (glassmacs-remote-r-launch-context host directory)
  (let ((root (concat (glassmacs-remote-r-directory host directory) ".glassmacs-jobs/" id "/")))
    (list :root root :source (concat root "job.R") :launcher (concat root "launch.sh")
          :stdout (concat root "stdout.log") :stderr (concat root "stderr.log")
          :pid (concat root "pid") :status (concat root "status")
          :working-directory (concat root "working-directory")
          :cancel (concat root "cancel-request"))))

(defun glassmacs-r-jobs--launcher ()
  "Return the fixed, server-side Rscript driver with cooperative cancellation.
No host names, source paths or shell commands are interpolated into it."
  "#!/bin/sh\nset -eu\numask 077\ncd \"$(dirname \"$0\")\"\njobdir=$(pwd -P)\nIFS= read -r workdir < working-directory\ncase \"$workdir\" in /*) ;; *) printf \"exit:74\\n\" > status; exit 74 ;; esac\nprintf \"starting\\n\" > status\nif ! command -v Rscript >/dev/null 2>&1; then\n  printf \"Rscript not found\\n\" > stderr.log\n  printf \"exit:127\\n\" > status\n  exit 127\nfi\nif ! cd \"$workdir\"; then\n  printf \"Cannot enter working directory\\n\" > \"$jobdir/stderr.log\"\n  printf \"exit:74\\n\" > \"$jobdir/status\"\n  exit 74\nfi\nRscript --vanilla \"$jobdir/job.R\" >\"$jobdir/stdout.log\" 2>\"$jobdir/stderr.log\" &\nchild=$!\nprintf \"%s\\n\" \"$child\" > \"$jobdir/pid\"\nprintf \"running\\n\" > \"$jobdir/status\"\nwhile kill -0 \"$child\" 2>/dev/null; do\n  if [ -f \"$jobdir/cancel-request\" ]; then\n    kill -TERM \"$child\" 2>/dev/null || :\n    wait \"$child\" 2>/dev/null || :\n    printf \"cancelled\\n\" > \"$jobdir/status\"\n    exit 0\n  fi\n  sleep 1\ndone\nif wait \"$child\"; then result=0; else result=$?; fi\nprintf \"exit:%s\\n\" \"$result\" > \"$jobdir/status\"\nexit \"$result\"\n")

(defun glassmacs-r-jobs--run (remote &rest argv)
  "Launch the fixed driver from TRAMP REMOTE, not via interactive ESS."
  (with-temp-buffer
    (setq default-directory remote)
    (let ((result (apply #'process-file (car argv) nil t nil (cdr argv))))
      (unless (and (integerp result) (zerop result))
        (user-error "Remote R job launch failed (exit %s)" result))
      result)))

(defun glassmacs-r-jobs-submit (host directory source-file)
  "Submit a copy of an R script as a detached job on SSH HOST.
This does not use ESS and never replays an interactive session queue.
A network failure can leave an uncertain submission: inspect its directory."
  (interactive (list (glassmacs-remote--read-host)
                     (read-string "Remote working directory: " "/")
                     (read-file-name "R script: " nil nil t)))
  (glassmacs-remote-r-launch-context host directory)
  (glassmacs-r-jobs--load)
  (unless (and (file-regular-p source-file) (string-match-p "\\.R\\'" source-file))
    (user-error "Select an existing .R source file"))
  (glassmacs-remote--require-executable "ssh")
  (let* ((id (glassmacs-r-jobs--new-id)) (paths (glassmacs-r-jobs--paths host directory id))
         (root (plist-get paths :root))
         (job (glassmacs-r-job--make :id id :host host :directory directory :root root
                                     :source source-file :state 'submitting)))
    (when (file-exists-p root) (user-error "Job ID collision"))
    (push job glassmacs-r-jobs--list)
    (glassmacs-r-jobs--save)
    (make-directory root t)
    (set-file-modes (file-name-directory (directory-file-name root)) #o700)
    (set-file-modes root #o700)
    (let ((remote-working-directory
           (plist-get (glassmacs-remote-context
                       (glassmacs-remote-r-directory host directory)) :localname)))
      (when (string-match-p "[\r\n]" remote-working-directory)
        (user-error "Remote job working directory cannot contain newlines"))
      (with-temp-file (plist-get paths :working-directory)
        (insert remote-working-directory "\n")))
    (copy-file source-file (plist-get paths :source) nil)
    (with-temp-file (plist-get paths :launcher) (insert (glassmacs-r-jobs--launcher) "\n"))
    (set-file-modes (plist-get paths :launcher) #o700)
    (glassmacs-r-jobs--run root "sh" "-c" "nohup sh ./launch.sh </dev/null >/dev/null 2>&1 &")
    (setf (glassmacs-r-job-state job) 'submitted)
    (glassmacs-r-jobs--save)
    (when (called-interactively-p 'interactive) (message "Submitted remote R job %s" id))
    id))

(defun glassmacs-r-jobs--read-marker (path)
  "Read status PATH without visiting a user buffer."
  (when (file-regular-p path)
    (with-temp-buffer
      (insert-file-contents path)
      (string-trim (buffer-string)))))

(defun glassmacs-r-jobs-status (host directory id)
  "Read server status without involving ESS or replaying commands.
A running status marker may become stale if the server process disappears."
  (interactive (list (glassmacs-remote--read-host)
                     (read-string "Remote job directory: " "/")
                     (read-string "Job ID: ")))
  (let* ((paths (glassmacs-r-jobs--paths host directory id))
         (marker (glassmacs-r-jobs--read-marker (plist-get paths :status)))
         (state (cond
                 ((equal marker "cancelled") 'cancelled)
                 ((equal marker "starting") 'starting)
                 ((equal marker "running")
                  (if (file-exists-p (plist-get paths :cancel))
                      'cancel-requested 'running))
                 ((and marker (string-match "^exit:\\([0-9]+\\)$" marker))
                  (if (zerop (string-to-number (match-string 1 marker)))
                      'completed 'failed))
                 (t 'unknown))))
    (when (called-interactively-p 'interactive)
      (message "Remote R job %s: %s" id state))
    state))

(defun glassmacs-r-jobs-request-cancel (host directory id)
  "Request cancellation without signalling an unverified or reused PID.
Only the running server-side job driver can signal its own child.
A request cannot guarantee that the remote R process has terminated."
  (interactive (list (glassmacs-remote--read-host)
                     (read-string "Remote working directory: " "/")
                     (read-string "Job ID: ")))
  (let* ((paths (glassmacs-r-jobs--paths host directory id))
         (state (glassmacs-r-jobs-status host directory id)))
    (when (memq state '(completed failed cancelled))
      (user-error "Remote job %s already finished (%s)" id state))
    (unless (file-regular-p (plist-get paths :source))
      (user-error "Remote job source not found; no request sent"))
    (unless (yes-or-no-p
             (format "Request cancellation of remote R job %s on %s? " id host))
      (user-error "Cancellation was not requested"))
    (with-temp-file (plist-get paths :cancel)
      (insert "requested\n"))
    (when (called-interactively-p 'interactive)
      (message "Cancellation requested for %s; verify final status" id))
    'cancel-requested))

(defun glassmacs-r-jobs-refresh ()
  "Explicitly refresh recorded jobs, preserving SSH connection uncertainty."
  (interactive)
  (glassmacs-r-jobs--load)
  (dolist (job glassmacs-r-jobs--list)
    (setf (glassmacs-r-job-state job)
          (condition-case nil
              (glassmacs-r-jobs-status
               (glassmacs-r-job-host job)
               (glassmacs-r-job-directory job)
               (glassmacs-r-job-id job))
            (file-error 'unreachable))))
  (glassmacs-r-jobs--save)
  (when (called-interactively-p 'interactive)
    (glassmacs-r-jobs-list)))

(defun glassmacs-r-jobs-open-log (host directory id &optional stderr)
  "Open the stdout or STDERR log for ID via TRAMP."
  (interactive (list (glassmacs-remote--read-host) (read-string "Remote working directory: " "/")
                     (read-string "Job ID: ") current-prefix-arg))
  (glassmacs-remote-r-launch-context host directory)
  (let* ((paths (glassmacs-r-jobs--paths host directory id))
         (file (plist-get paths (if stderr :stderr :stdout))))
    (unless (file-regular-p file) (user-error "Remote job log unavailable"))
    (find-file-read-only file)))

(defun glassmacs-r-jobs-list ()
  "Display remembered remote R job IDs; no remote host is contacted."
  (interactive)
  (glassmacs-r-jobs--load)
  (with-current-buffer (get-buffer-create "*Glassmacs R Jobs*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "Remote Rscript jobs are independent of ESS sessions.\n"
              "Statuses are snapshots; use M-x glassmacs-r-jobs-refresh to update.\n\n")
      (dolist (job glassmacs-r-jobs--list)
        (insert (format "%s  %s  %s\n" (glassmacs-r-job-id job)
                        (glassmacs-r-job-host job) (glassmacs-r-job-state job))))
      (special-mode))
    (display-buffer (current-buffer))))

(provide 'glassmacs-r-jobs)

;;; glassmacs-r-jobs.el ends here
