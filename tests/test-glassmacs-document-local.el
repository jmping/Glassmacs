;;; test-glassmacs-document-local.el --- Local document build tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'glassmacs-document-local)

(defun glassmacs-document-local-test--job (id)
  "Return a pending local document job named ID."
  (glassmacs-document-job-new
   id
   (glassmacs-document-context-create
    (expand-file-name "paper.Rmd" temporary-file-directory))
   'rmarkdown))

(defun glassmacs-document-local-test--wait (process)
  "Wait briefly for PROCESS to finish and dispatch its sentinel."
  (let ((deadline (+ (float-time) 10)))
    (while (and (process-live-p process) (< (float-time) deadline))
      (accept-process-output process 0.1))
    (accept-process-output process 0.01)
    (should-not (process-live-p process))))

(ert-deftest glassmacs-document-local-success-is-per-job ()
  (let* ((a (glassmacs-document-local-test--job "a"))
         (b (glassmacs-document-local-test--job "b"))
         (callback-count 0)
         (a-process (glassmacs-document-local-start
                     a "sh" '("-c" "printf first")
                     (lambda (_job) (cl-incf callback-count))))
         (b-process (glassmacs-document-local-start
                     b "sh" '("-c" "printf second"))))
    (unwind-protect
        (progn
          (glassmacs-document-local-test--wait a-process)
          (glassmacs-document-local-test--wait b-process)
          (should (eq (glassmacs-document-job-status a) 'succeeded))
          (should (eq (glassmacs-document-job-status b) 'succeeded))
          (should (= callback-count 1))
          (should-not (eq (glassmacs-document-job-log-buffer a)
                          (glassmacs-document-job-log-buffer b)))
          (with-current-buffer (glassmacs-document-job-log-buffer a)
            (should (string-match-p "first" (buffer-string))))
          (with-current-buffer (glassmacs-document-job-log-buffer b)
            (should (string-match-p "second" (buffer-string)))))
      (dolist (job (list a b))
        (when (buffer-live-p (glassmacs-document-job-log-buffer job))
          (kill-buffer (glassmacs-document-job-log-buffer job)))))))

(ert-deftest glassmacs-document-local-failure-keeps-log ()
  (let* ((job (glassmacs-document-local-test--job "failed"))
         (process (glassmacs-document-local-start
                   job "sh" '("-c" "printf problem; exit 7"))))
    (unwind-protect
        (progn
          (glassmacs-document-local-test--wait process)
          (should (eq (glassmacs-document-job-status job) 'failed))
          (should (string-match-p "exit 7" (glassmacs-document-job-error job)))
          (with-current-buffer (glassmacs-document-job-log-buffer job)
            (should (string-match-p "problem" (buffer-string)))))
      (when (buffer-live-p (glassmacs-document-job-log-buffer job))
        (kill-buffer (glassmacs-document-job-log-buffer job))))))

(ert-deftest glassmacs-document-local-rejects-remote-context ()
  (let ((job (glassmacs-document-job-new
              "remote"
              (glassmacs-document-context--make
               :source "/ssh:other:/paper.qmd"
               :directory "/ssh:other:/"
               :location 'remote)
              'quarto)))
    (should-error (glassmacs-document-local-start job "sh" '("-c" "true"))
                  :type 'user-error)
    (should (eq (glassmacs-document-job-status job) 'pending))))

(ert-deftest glassmacs-document-local-cancel-does-not-restart ()
  (let* ((job (glassmacs-document-local-test--job "cancel"))
         (process (glassmacs-document-local-start
                   job "sh" '("-c" "sleep 10"))))
    (unwind-protect
        (progn
          (glassmacs-document-local-cancel job)
          (should (eq (glassmacs-document-job-status job) 'cancelled))
          (should-not (process-live-p process))
          (should-error (glassmacs-document-local-start
                         job "sh" '("-c" "true"))
                        :type 'user-error))
      (when (process-live-p process) (delete-process process))
      (when (buffer-live-p (glassmacs-document-job-log-buffer job))
        (kill-buffer (glassmacs-document-job-log-buffer job))))))

(provide 'test-glassmacs-document-local)
;;; test-glassmacs-document-local.el ends here
