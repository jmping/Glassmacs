;;; test-glassmacs-document-jobs.el --- Document job contract tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'glassmacs-document-jobs)

(ert-deftest glassmacs-document-context-local-snapshot ()
  (let ((context (glassmacs-document-context-create
                  "/tmp/research/paper.Rmd" "/tmp/research/" "session-1")))
    (should (equal (glassmacs-document-context-source context)
                   "/tmp/research/paper.Rmd"))
    (should (equal (glassmacs-document-context-directory context)
                   "/tmp/research/"))
    (should (eq (glassmacs-document-context-location context) 'local))
    (should (equal (glassmacs-document-context-target-id context) "session-1"))))

(ert-deftest glassmacs-document-context-remote-does-not-connect ()
  (cl-letf (((symbol-function 'file-remote-p)
             (lambda (path &optional _identification _connected)
               (and (string-prefix-p "/ssh:research:" path)
                    "/ssh:research:"))))
    (let ((context (glassmacs-document-context-create
                    "/ssh:research:/work/paper.qmd"
                    "/ssh:research:/work/")))
      (should (eq (glassmacs-document-context-location context) 'remote))
      (should (equal (glassmacs-document-context-directory context)
                     "/ssh:research:/work/")))))

(ert-deftest glassmacs-document-context-refuses-cross-location-root ()
  (cl-letf (((symbol-function 'file-remote-p)
             (lambda (path &optional _identification _connected)
               (when (string-prefix-p "/ssh:research:" path)
                 "/ssh:research:"))))
    (should-error
     (glassmacs-document-context-create
      "/ssh:research:/work/paper.Rmd" "/tmp/research/")
     :type 'user-error)
    (should-error
     (glassmacs-document-context-create
      "/ssh:research:/work/paper.Rmd" "/ssh:other:/work/")
     :type 'user-error)))

(ert-deftest glassmacs-document-context-requires-absolute-source ()
  (should-error (glassmacs-document-context-create "paper.Rmd")
                :type 'user-error)
  (should-error (glassmacs-document-context-create "/tmp/research/")
                :type 'user-error))

(ert-deftest glassmacs-document-job-preserves-explicit-context ()
  (let* ((context (glassmacs-document-context-create "/tmp/paper.Rmd"))
         (job (glassmacs-document-job-new "build-1" context 'rmarkdown
                                          "*Glassmacs Build 1*")))
    (should (eq (glassmacs-document-job-context job) context))
    (should (eq (glassmacs-document-job-status job) 'pending))
    (glassmacs-document-job-transition job 'running)
    (glassmacs-document-job-transition job 'succeeded "/tmp/paper.html")
    (should (equal (glassmacs-document-job-output-file job)
                   "/tmp/paper.html"))
    (should-error (glassmacs-document-job-transition job 'running)
                  :type 'user-error)))

(ert-deftest glassmacs-document-job-uncertain-cannot-replay ()
  (let ((job (glassmacs-document-job-new
              "build-2" (glassmacs-document-context-create "/tmp/paper.qmd")
              'quarto)))
    (glassmacs-document-job-transition job 'running)
    (glassmacs-document-job-transition job 'uncertain)
    (should-error (glassmacs-document-job-transition job 'pending)
                  :type 'user-error)
    (should-error (glassmacs-document-job-transition job 'running)
                  :type 'user-error)
    (glassmacs-document-job-transition job 'failed nil "confirmed failed")
    (should (equal (glassmacs-document-job-error job) "confirmed failed"))))

(provide 'test-glassmacs-document-jobs)
;;; test-glassmacs-document-jobs.el ends here
