;;; test-glassmacs-document-history.el --- Private output index tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'glassmacs-document-history)

(defun glassmacs-document-history-test--job (source output)
  "Build a successful synthetic local job for SOURCE and OUTPUT."
  (let ((job (glassmacs-document-job-new
              "history-1" (glassmacs-document-context-create source)
              'quarto)))
    (glassmacs-document-job-transition job 'running)
    (glassmacs-document-job-transition job 'succeeded output)
    job))

(ert-deftest glassmacs-document-history-roundtrip-is-private-and-opt-in ()
  (let* ((glassmacs-home (make-temp-file "glassmacs-document-history-" t))
         (glassmacs-document-remember-build-outputs t)
         (source "/tmp/project/paper.qmd")
         (output "/tmp/project/paper.html")
         (job (glassmacs-document-history-test--job source output)))
    (unwind-protect
        (progn
          (glassmacs-document-history-record job)
          (should (equal (glassmacs-document-history-find source) output))
          (should-not (glassmacs-document-history-find "/tmp/other.qmd"))
          (should (= (logand (file-modes (glassmacs-document-history--file))
                             #o777)
                     #o600)))
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-document-history-opt-out-does-not-write ()
  (let* ((glassmacs-home (make-temp-file "glassmacs-document-history-" t))
         (glassmacs-document-remember-build-outputs nil)
         (job (glassmacs-document-history-test--job
               "/tmp/project/paper.Rmd" "/tmp/project/paper.html")))
    (unwind-protect
        (progn
          (glassmacs-document-history-record job)
          (should-not (file-exists-p (glassmacs-document-history--file))))
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-document-history-rejects-remote-path ()
  (let* ((glassmacs-home (make-temp-file "glassmacs-document-history-" t))
         (glassmacs-document-remember-build-outputs t)
         (job (glassmacs-document-job-new
               "remote" (glassmacs-document-context--make
                         :source "/ssh:host:/work/paper.qmd"
                         :directory "/ssh:host:/work/"
                         :location 'remote)
               'quarto)))
    (unwind-protect
        (progn
          (glassmacs-document-job-transition job 'running)
          (glassmacs-document-job-transition job 'succeeded
                                             "/ssh:host:/work/paper.html")
          (should-error (glassmacs-document-history-record job)
                        :type 'user-error)
          (should-not (file-exists-p (glassmacs-document-history--file))))
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-document-history-corrupt-index-is-preserved ()
  (let* ((glassmacs-home (make-temp-file "glassmacs-document-history-" t))
         (glassmacs-document-remember-build-outputs t)
         (file (glassmacs-document-history--file))
         (job (glassmacs-document-history-test--job
               "/tmp/project/paper.qmd" "/tmp/project/paper.html")))
    (unwind-protect
        (progn
          (with-temp-file file (insert "not-json"))
          (should-error (glassmacs-document-history-record job)
                        :type 'user-error)
          (with-temp-buffer
            (insert-file-contents file)
            (should (equal (buffer-string) "not-json"))))
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-document-history-picker-distinguishes-same-basename ()
  "Browsing is explicit, full-path keyed, and leaves other source entries."
  (let* ((glassmacs-home (make-temp-file "glassmacs-document-history-" t))
         (glassmacs-document-remember-build-outputs t)
         (a "/tmp/project-a/report.Rmd")
         (b "/tmp/project-b/report.Rmd")
         (out-a "/tmp/project-a/report.html")
         (out-b "/tmp/project-b/report.html")
         (opened nil)
         (choices nil))
    (unwind-protect
        (progn
          (glassmacs-document-history-record
           (glassmacs-document-history-test--job a out-a))
          (glassmacs-document-history-record
           (glassmacs-document-history-test--job b out-b))
          (should (= (length (glassmacs-document-history-list)) 2))
          (cl-letf (((symbol-function 'completing-read)
                     (lambda (_prompt candidates &rest _)
                       (setq choices candidates)
                       (car (cl-find-if
                             (lambda (choice) (string-match-p "project-a" choice))
                             candidates))))
                    ((symbol-function 'glassmacs-open-rendered-output)
                     (lambda (file) (setq opened file))))
            (glassmacs-document-build-browse-recent-outputs))
          (should (= (length choices) 2))
          (should (cl-every (lambda (item) (string-match-p "/tmp/project-" item))
                            choices))
          (should (equal opened out-a))
          (should (equal (glassmacs-document-history-find b) out-b)))
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-document-history-forget-is-exact-and-keeps-output ()
  "Forgetting one file is metadata-only and never erases another record."
  (let* ((glassmacs-home (make-temp-file "glassmacs-document-history-" t))
         (glassmacs-document-remember-build-outputs t)
         (source-a "/tmp/a/report.qmd")
         (source-b "/tmp/b/report.qmd")
         (output (make-temp-file "glassmacs-built-output-" nil ".html")))
    (unwind-protect
        (progn
          (glassmacs-document-history-record
           (glassmacs-document-history-test--job source-a output))
          (glassmacs-document-history-record
           (glassmacs-document-history-test--job source-b output))
          (should (glassmacs-document-history-forget source-a))
          (should-not (glassmacs-document-history-find source-a))
          (should (equal (glassmacs-document-history-find source-b) output))
          (should (file-exists-p output))
          (should-not (glassmacs-document-history-forget source-a))
          (should-error
           (glassmacs-document-history-forget "/ssh:host:/tmp/report.qmd")
           :type 'user-error))
      (delete-file output)
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-document-history-forget-prompts-and-respects-decline ()
  (let* ((glassmacs-home (make-temp-file "glassmacs-document-history-" t))
         (glassmacs-document-remember-build-outputs t)
         (source "/tmp/project/paper.Rmd")
         (output "/tmp/project/paper.html"))
    (unwind-protect
        (progn
          (glassmacs-document-history-record
           (glassmacs-document-history-test--job source output))
          (with-temp-buffer
            (setq buffer-file-name source)
            (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
              (glassmacs-document-build-forget-remembered-output))
            (should (equal (glassmacs-document-history-find source) output))
            (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
              (glassmacs-document-build-forget-remembered-output))
            (should-not (glassmacs-document-history-find source))))
      (delete-directory glassmacs-home t))))

(provide 'test-glassmacs-document-history)
;;; test-glassmacs-document-history.el ends here
