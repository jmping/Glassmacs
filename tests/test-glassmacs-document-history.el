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

(provide 'test-glassmacs-document-history)
;;; test-glassmacs-document-history.el ends here
