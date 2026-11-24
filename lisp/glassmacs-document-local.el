;;; glassmacs-document-local.el --- Local research build process adapter -*- lexical-binding: t; -*-

;; Per-job output and process ownership for local document builds.  This
;; adapter does not inspect TRAMP paths, start remote jobs or replay work.

(require 'glassmacs-document-jobs)

(defun glassmacs-document-local--sentinel (process _event)
  "Update the document job owned by PROCESS when it finishes."
  (when (and (memq (process-status process) '(exit signal))
             (process-get process 'glassmacs-document-job))
    (let ((job (process-get process 'glassmacs-document-job))
          (on-success (process-get process 'glassmacs-document-on-success)))
      (when (eq (glassmacs-document-job-status job) 'running)
        (if (and (eq (process-status process) 'exit)
                 (zerop (process-exit-status process)))
            (progn
              (glassmacs-document-job-transition job 'succeeded)
              (when on-success
                (condition-case err
                    (funcall on-success job)
                  (error
                   ;; The build succeeded even if presentation of its output
                   ;; failed.  Keep that distinction in the job record.
                   (setf (glassmacs-document-job-error job)
                         (error-message-string err))
                   (message "Build output presentation failed: %s"
                            (error-message-string err))))))
          (glassmacs-document-job-transition
           job 'failed nil (format "Process %s (exit %d)"
                                   (process-status process)
                                   (process-exit-status process))))))))

(defun glassmacs-document-local-start (job program arguments &optional on-success)
  "Start a local document JOB using PROGRAM with ARGUMENTS.
Use the context's source directory, make a distinct output buffer, and return
the resulting process.  ON-SUCCESS receives JOB once after a zero exit code.
This adapter does not modify `glassmacs--current-process' or any ESS session.
Only `pending' local jobs are accepted, and there is no shell interpolation."
  (unless (and (glassmacs-document-job-p job)
               (eq (glassmacs-document-job-status job) 'pending)
               (eq (glassmacs-document-context-location
                    (glassmacs-document-job-context job))
                   'local))
    (user-error "A pending local document job is required"))
  (unless (and (stringp program) (listp arguments)
               (cl-every #'stringp arguments))
    (user-error "A program and string argument list are required"))
  (let ((executable (executable-find program)))
    (unless executable
      (user-error "Required executable not found on PATH: %s" program))
    (let* ((directory (glassmacs-document-context-directory
                       (glassmacs-document-job-context job)))
           (buffer (generate-new-buffer
                    (format "*Glassmacs Build %s*" (glassmacs-document-job-id job))))
           process)
      (condition-case err
          (setq process
                (let ((default-directory directory))
                  (make-process :name (format "glassmacs-build-%s"
                                              (glassmacs-document-job-id job))
                                :buffer buffer
                                :command (cons executable arguments)
                                :connection-type 'pipe
                                :noquery t
                                :sentinel #'glassmacs-document-local--sentinel)))
        (error
         (kill-buffer buffer)
         (glassmacs-document-job-transition
          job 'failed nil (error-message-string err))
         (signal (car err) (cdr err))))
      (setf (glassmacs-document-job-log-buffer job) buffer
            (glassmacs-document-job-process job) process)
      (process-put process 'glassmacs-document-job job)
      (process-put process 'glassmacs-document-on-success on-success)
      (glassmacs-document-job-transition job 'running)
      process)))

(defun glassmacs-document-local-cancel (job)
  "Cancel a running local JOB without affecting other document builds.
This is a best-effort signal to the owned process, not a subprocess-tree
termination guarantee."
  (unless (and (glassmacs-document-job-p job)
               (eq (glassmacs-document-job-status job) 'running)
               (process-live-p (glassmacs-document-job-process job)))
    (user-error "No running local document process to cancel"))
  (glassmacs-document-job-transition job 'cancelled)
  (delete-process (glassmacs-document-job-process job))
  job)

(provide 'glassmacs-document-local)
;;; glassmacs-document-local.el ends here
