;;; glassmacs-r-jobs.el --- Durable Rscript job primitives -*- lexical-binding: t; -*-

(require 'cl-lib)

(require 'subr-x)

(require 'glassmacs-remote)

(defgroup glassmacs-r-jobs nil "Durable remote Rscript jobs." :group 'glassmacs-remote)

(cl-defstruct (glassmacs-r-job (:constructor glassmacs-r-job--make) (:copier nil)) id host directory root source state)

(defvar glassmacs-r-jobs--list nil "Jobs submitted during this Emacs invocation.")

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
  (unless (and (file-regular-p source-file) (string-match-p "\\.R\\'" source-file))
    (user-error "Select an existing .R source file"))
  (glassmacs-remote--require-executable "ssh")
  (let* ((id (glassmacs-r-jobs--new-id)) (paths (glassmacs-r-jobs--paths host directory id))
         (root (plist-get paths :root))
         (job (glassmacs-r-job--make :id id :host host :directory directory :root root
                                     :source source-file :state 'submitting)))
    (push job glassmacs-r-jobs--list)
    (when (file-exists-p root) (user-error "Job ID collision"))
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
    (when (called-interactively-p 'interactive) (message "Submitted remote R job %s" id))
    id))

(defun glassmacs-r-jobs--read-marker (path)
  "Read status PATH without visiting a user buffer."
  (when (file-regular-p path)
    (with-temp-buffer
      (insert-file-contents path)
      (string-trim (buffer-string)))))

(defun glassmacs-r-jobs-status (host directory id)
  "Read server status of ID without depending on an ESS session."
  (interactive (list (glassmacs-remote--read-host)
                     (read-string "Remote job directory: " "/")
                     (read-string "Job ID: ")))
  (let* ((file (plist-get (glassmacs-r-jobs--paths host directory id) :status))
         (marker (glassmacs-r-jobs--read-marker file))
         (state (cond
                 ((equal marker "running") 'running)
                 ((and marker (string-match "\\`exit:\\([0-9]+\\)\\'" marker))
                  (if (= (string-to-number (match-string 1 marker)) 0)
                      'completed 'failed))
                 (t 'unknown))))
    (when (called-interactively-p 'interactive)
      (message "Remote R job %s: %s" id state))
    state))

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
  "Display this Emacs invocation's remote job submissions."
  (interactive)
  (with-current-buffer (get-buffer-create "*Glassmacs R Jobs*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "Remote Rscript jobs are independent of ESS sessions.\n")
      (dolist (job glassmacs-r-jobs--list)
        (insert (format "%s  %s  %s\n" (glassmacs-r-job-id job)
                        (glassmacs-r-job-host job) (glassmacs-r-job-state job))))
      (special-mode))
    (display-buffer (current-buffer))))

(provide 'glassmacs-r-jobs)

;;; glassmacs-r-jobs.el ends here
