;;; test-glassmacs-document-acceptance.el --- End-to-end document jobs -*- lexical-binding: t; -*-

;; These tests exercise the real opt-in renderer, not a mocked callback.
;; Machines without R Markdown/Pandoc skip the real-render case explicitly.
;; Cocoa output presentation remains a separate packaged-Mac acceptance gate.

(require 'ert)
(require 'cl-lib)
(require 'glassmacs)

(defun glassmacs-document-acceptance--rmarkdown-available-p ()
  "Return non-nil when actual local R Markdown HTML rendering is possible."
  (and (executable-find "Rscript")
       (executable-find "pandoc")
       (zerop (call-process
               "Rscript" nil nil nil "--vanilla" "-e"
               "quit(status=if (requireNamespace('rmarkdown', quietly=TRUE)) 0 else 1)"))))

(defun glassmacs-document-acceptance--await (processes &optional seconds)
  "Wait for PROCESSES to finish, failing after SECONDS (default 180)."
  (let ((deadline (+ (float-time) (or seconds 180))))
    (while (and (cl-some #'process-live-p processes)
                (< (float-time) deadline))
      (accept-process-output nil 0.2))
    (should-not (cl-some #'process-live-p processes))
    ;; Give process sentinels a chance to classify their terminal status.
    (accept-process-output nil 0.1)))

(ert-deftest glassmacs-document-acceptance-concurrent-real-rmarkdown ()
  "Two real opt-in renders retain distinct source, output, log and history.
This is not a native macOS HTML-window or focus test."
  (unless (glassmacs-document-acceptance--rmarkdown-available-p)
    (ert-skip "Rscript, rmarkdown and Pandoc are required for real rendering"))
  (let* ((root (make-temp-file "glassmacs-rmarkdown-acceptance-" t))
         (glassmacs-home (expand-file-name "profile/" root))
         (glassmacs-document-use-job-adapter t)
         (glassmacs-document-remember-build-outputs t)
         (glassmacs-document-detect-project-root nil)
         (glassmacs-render-open-output nil)
         (a-directory (expand-file-name "first/" root))
         (b-directory (expand-file-name "second/" root))
         (a-source (expand-file-name "report.Rmd" a-directory))
         (b-source (expand-file-name "report.Rmd" b-directory))
         a-buffer b-buffer a-process b-process a-job b-job
         opened)
    (unwind-protect
        (progn
          (make-directory a-directory t)
          (make-directory b-directory t)
          (make-directory glassmacs-home t)
          (write-region
           "---\ntitle: First\noutput: html_document\n---\n\n\x60\x60\x60{r}\n101 + 1\n\x60\x60\x60\n"
           nil a-source)
          (write-region
           "---\ntitle: Second\noutput: html_document\n---\n\n\x60\x60\x60{r}\n202 + 2\n\x60\x60\x60\n"
           nil b-source)
          (setq a-buffer (find-file-noselect a-source)
                b-buffer (find-file-noselect b-source))
          ;; A disabled automatic opener must not disguise an output mix-up.
          (cl-letf (((symbol-function 'glassmacs-open-rendered-output)
                     (lambda (output) (push output opened))))
            (setq a-process
                  (with-current-buffer a-buffer
                    (glassmacs-render-rmarkdown)))
            (setq b-process
                  (with-current-buffer b-buffer
                    (glassmacs-render-rmarkdown)))
            (setq a-job (buffer-local-value 'glassmacs-document-last-job a-buffer)
                  b-job (buffer-local-value 'glassmacs-document-last-job b-buffer))
            (should (processp a-process))
            (should (processp b-process))
            (should-not (eq a-process b-process))
            (should-not (eq (glassmacs-document-job-log-buffer a-job)
                            (glassmacs-document-job-log-buffer b-job)))
            (glassmacs-document-acceptance--await (list a-process b-process))
            (should (eq (glassmacs-document-job-status a-job) 'succeeded))
            (should (eq (glassmacs-document-job-status b-job) 'succeeded))
            (should-not (glassmacs-document-job-error a-job))
            (should-not (glassmacs-document-job-error b-job))
            (let ((a-output (glassmacs-document-job-output-file a-job))
                  (b-output (glassmacs-document-job-output-file b-job)))
              (should (equal a-output
                             (expand-file-name "report.html" a-directory)))
              (should (equal b-output
                             (expand-file-name "report.html" b-directory)))
              (should (file-readable-p a-output))
              (should (file-readable-p b-output))
              (should (equal (glassmacs-document-history-find a-source)
                             a-output))
              (should (equal (glassmacs-document-history-find b-source)
                             b-output))
              (should-not opened)
              ;; Source reopening consults remembered output only on command.
              (kill-buffer a-buffer)
              (setq a-buffer nil)
              (with-temp-buffer
                (setq buffer-file-name a-source)
                (glassmacs-document-build-open-remembered-output))
              (should (equal opened (list a-output)))
              (should-not (equal (car opened) b-output)))))
      (dolist (process (list a-process b-process))
        (when (and process (process-live-p process))
          (delete-process process)))
      (dolist (job (list a-job b-job))
        (when (and job
                   (buffer-live-p (glassmacs-document-job-log-buffer job)))
          (kill-buffer (glassmacs-document-job-log-buffer job))))
      (dolist (buffer (list a-buffer b-buffer))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer)))
      (delete-directory root t))))

(ert-deftest glassmacs-document-acceptance-cancel-isolates-peer-build ()
  "Cancelling one local build leaves the other one and its result intact."
  (let* ((root (make-temp-file "glassmacs-build-isolation-" t))
         (source-a (expand-file-name "first.Rmd" root))
         (source-b (expand-file-name "second.Rmd" root))
         (job-a (glassmacs-document-job-new
                 "cancelled-build"
                 (glassmacs-document-context-create source-a) 'rmarkdown))
         (job-b (glassmacs-document-job-new
                 "surviving-build"
                 (glassmacs-document-context-create source-b) 'quarto))
         (glassmacs--current-process 'untouched-legacy-process)
         process-a process-b)
    (unwind-protect
        (progn
          (setq process-a
                (glassmacs-document-local-start
                 job-a "sh" '("-c" "exec sleep 30")))
          (setq process-b
                (glassmacs-document-local-start
                 job-b "sh" '("-c" "printf peer-completed")))
          (should (eq (glassmacs-document-job-status job-a) 'running))
          (glassmacs-document-local-cancel job-a)
          (glassmacs-document-acceptance--await (list process-b) 15)
          (should (eq (glassmacs-document-job-status job-a) 'cancelled))
          (should (eq (glassmacs-document-job-status job-b) 'succeeded))
          (should (eq glassmacs--current-process
                      'untouched-legacy-process))
          (should-not (glassmacs-document-job-error job-b))
          (with-current-buffer (glassmacs-document-job-log-buffer job-b)
            (should (string-match-p "peer-completed" (buffer-string))))
          (should-error (glassmacs-document-local-start
                         job-a "sh" '("-c" "printf forbidden"))
                        :type 'user-error))
      (dolist (process (list process-a process-b))
        (when (and process (process-live-p process))
          (delete-process process)))
      (dolist (job (list job-a job-b))
        (when (buffer-live-p (glassmacs-document-job-log-buffer job))
          (kill-buffer (glassmacs-document-job-log-buffer job))))
      (delete-directory root t))))

(provide 'test-glassmacs-document-acceptance)
;;; test-glassmacs-document-acceptance.el ends here
