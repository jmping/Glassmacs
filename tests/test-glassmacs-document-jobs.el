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


(ert-deftest glassmacs-document-project-context-is-explicit-and-local ()
  "Project root is captured only when opted in, without changing directory."
  (let ((glassmacs-document-detect-project-root t)
        (calls 0))
    (cl-letf (((symbol-function 'project-current)
               (lambda (&rest _) (cl-incf calls) 'mock-project))
              ((symbol-function 'project-root)
               (lambda (_project) "/tmp/research/")))
      (let ((context (glassmacs-document-context-for-file
                      "/tmp/research/sub/paper.qmd" "R-1")))
        (should (equal (glassmacs-document-context-project-root context)
                       "/tmp/research/"))
        (should (equal (glassmacs-document-context-directory context)
                       "/tmp/research/sub/"))
        (should (equal (glassmacs-document-context-target-id context) "R-1"))
        (should (= calls 1))))
    (let ((glassmacs-document-detect-project-root nil))
      (should-not (glassmacs-document-context-project-root
                   (glassmacs-document-context-for-file
                    "/tmp/research/paper.qmd"))))))

(ert-deftest glassmacs-document-project-context-skips-remote-discovery ()
  (let ((glassmacs-document-detect-project-root t))
    (cl-letf (((symbol-function 'project-current)
               (lambda (&rest _) (error "Should not probe remote project"))))
      (let ((context (glassmacs-document-context-for-file
                      "/ssh:research:/work/paper.qmd")))
        (should (eq (glassmacs-document-context-location context) 'remote))
        (should-not (glassmacs-document-context-project-root context))))))


;;; In-session jobs dashboard and bounded registry

(defun glassmacs-document-jobs-test--job (id source kind)
  "Return a new, synthetic job without starting a process."
  (glassmacs-document-job-new
   id (glassmacs-document-context-create source) kind))

(ert-deftest glassmacs-document-jobs-dashboard-registers-bounded-newest-first ()
  "A snapshot cannot trigger I/O or mutate the underlying job ordering."
  (let ((glassmacs-document-jobs--registry nil))
    (let ((first (glassmacs-document-jobs-test--job
                  "a-1" "/tmp/project-a/report.Rmd" 'rmarkdown))
          (second (glassmacs-document-jobs-test--job
                   "b-1" "/tmp/project-b/report.Rmd" 'quarto)))
      (glassmacs-document-jobs-register first)
      (glassmacs-document-jobs-register second)
      (should (equal (mapcar #'glassmacs-document-job-id
                             (glassmacs-document-jobs-list))
                     '("b-1" "a-1")))
      (let ((snapshot (glassmacs-document-jobs-list)))
        (setcar snapshot nil)
        (should (eq (car glassmacs-document-jobs--registry) second)))
      (should (equal
               (mapcar #'car (glassmacs-document-jobs--entries))
               '("b-1" "a-1")))
      (should (equal
               (aref (cadr (car (glassmacs-document-jobs--entries))) 3)
               "/tmp/project-b/report.Rmd"))
      (should-error (glassmacs-document-jobs-register second)
                    :type 'user-error))
    (let ((glassmacs-document-jobs-limit 3))
      (dotimes (n 5)
        (glassmacs-document-jobs-register
         (glassmacs-document-jobs-test--job
          (format "new-%d" n) (format "/tmp/report-%d.qmd" n) 'quarto)))
      (should (equal (mapcar #'glassmacs-document-job-id
                             (glassmacs-document-jobs-list))
                     '("new-4" "new-3" "new-2"))))))

(ert-deftest glassmacs-document-jobs-dashboard-is-read-only-and-inert ()
  "Opening the dashboard never opens outputs or launches any processes."
  (let* ((glassmacs-document-jobs--registry nil)
         (job (glassmacs-document-jobs-test--job
               "view-1" "/tmp/work/paper.qmd" 'quarto))
         (opened nil)
         (shown nil))
    (glassmacs-document-jobs-register job)
    (glassmacs-document-job-transition job 'running)
    (glassmacs-document-job-transition job 'succeeded "/tmp/work/paper.html")
    (cl-letf (((symbol-function 'glassmacs-open-rendered-output)
               (lambda (path) (push path opened)))
              ((symbol-function 'make-process)
               (lambda (&rest _) (ert-fail "dashboard must never launch")))
              ((symbol-function 'display-buffer)
               (lambda (buffer &rest _) (setq shown buffer))))
      (let ((buffer (glassmacs-document-jobs-show)))
        (unwind-protect
            (progn
              (should (eq shown buffer))
              (with-current-buffer buffer
                (should (derived-mode-p 'glassmacs-document-jobs-mode))
                (should buffer-read-only)
                (should (string-match-p "view-1" (buffer-string)))
                (glassmacs-document-jobs-refresh))
              (should-not opened))
          (kill-buffer buffer))))))

(ert-deftest glassmacs-document-jobs-dashboard-actions-are-explicit ()
  (let* ((glassmacs-document-jobs--registry nil)
         (job (glassmacs-document-jobs-test--job
               "actions-1" "/tmp/project/report.Rmd" 'rmarkdown))
         (peer (glassmacs-document-jobs-test--job
                "peer-1" "/tmp/project/peer.Rmd" 'rmarkdown))
         (opened nil)
         (cancelled nil))
    (glassmacs-document-job-transition job 'running)
    (glassmacs-document-job-transition peer 'running)
    (setf (glassmacs-document-job-process job) 'owned-process)
    (cl-letf (((symbol-function 'glassmacs-document-jobs--selected)
               (lambda () job))
              ((symbol-function 'process-live-p)
               (lambda (process) (eq process 'owned-process)))
              ((symbol-function 'glassmacs-document-local-cancel)
               (lambda (selected)
                 (setq cancelled selected)
                 (glassmacs-document-job-transition selected 'cancelled)))
              ((symbol-function 'y-or-n-p) (lambda (&rest _) t))
              ((symbol-function 'glassmacs-open-rendered-output)
               (lambda (output) (setq opened output))))
      (should-error (glassmacs-document-jobs-open-output) :type 'user-error)
      (glassmacs-document-jobs-cancel)
      (should (eq cancelled job))
      (should (eq (glassmacs-document-job-status peer) 'running))
      (should (eq (glassmacs-document-job-status job) 'cancelled))
      (should-error (glassmacs-document-jobs-cancel) :type 'user-error))
    (let* ((complete (glassmacs-document-jobs-test--job
                      "complete" "/tmp/another/report.Rmd" 'rmarkdown)))
      (glassmacs-document-job-transition complete 'running)
      (glassmacs-document-job-transition complete 'succeeded
                                         "/tmp/another/report.html")
      (cl-letf (((symbol-function 'glassmacs-document-jobs--selected)
                 (lambda () complete))
                ((symbol-function 'glassmacs-open-rendered-output)
                 (lambda (output) (setq opened output))))
        (glassmacs-document-jobs-open-output)
        (should (equal opened "/tmp/another/report.html"))))))

(provide 'test-glassmacs-document-jobs)
;;; test-glassmacs-document-jobs.el ends here
