;;; test-glassmacs-documents.el --- Mixed R document tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs)
;; Defined by polymode; declared so `let' binds it dynamically without it.
(defvar polymode-move-these-vars-from-base-buffer)

(defmacro glassmacs-documents-test--with-modes (available &rest body)
  "Run BODY where only the mode functions in AVAILABLE are defined.
Each available mode records its name in `chosen'; `offered' records
installation offers."
  (declare (indent 1))
  `(let ((chosen nil) (offered nil))
     (cl-letf ,(append
                (mapcar (lambda (mode)
                          `((symbol-function ',mode)
                            ,(if (memq mode available)
                                 `(lambda () (setq chosen ',mode))
                               nil)))
                        '(poly-noweb+r-mode Rnw-mode poly-markdown+r-mode quarto-mode
                                            LaTeX-mode latex-mode markdown-mode))
                '(((symbol-function 'glassmacs-packages-offer-installation)
                   (lambda (feature) (setq offered feature)))))
       ,@body)))

(ert-deftest glassmacs-documents-sweave-uses-poly-r ()
  "ESS 18.10 removed Rnw-mode; Sweave files use poly-R's noweb mode."
  (glassmacs-documents-test--with-modes (poly-noweb+r-mode Rnw-mode latex-mode)
    (with-temp-buffer (glassmacs-sweave-mode))
    (should (eq chosen 'poly-noweb+r-mode))
    (should-not offered))
  (glassmacs-documents-test--with-modes (Rnw-mode latex-mode)
    (with-temp-buffer (glassmacs-sweave-mode))
    (should (eq chosen 'Rnw-mode)))
  (glassmacs-documents-test--with-modes (latex-mode)
    (with-temp-buffer (glassmacs-sweave-mode))
    (should (eq chosen 'latex-mode))
    (should (equal offered "Sweave editing (poly-R)"))))

(ert-deftest glassmacs-documents-quarto-falls-back-to-r-markdown-editing ()
  (glassmacs-documents-test--with-modes (quarto-mode poly-markdown+r-mode markdown-mode)
    (with-temp-buffer (glassmacs-quarto-mode))
    (should (eq chosen 'quarto-mode)))
  (glassmacs-documents-test--with-modes (poly-markdown+r-mode markdown-mode)
    (with-temp-buffer (glassmacs-quarto-mode))
    (should (eq chosen 'poly-markdown+r-mode))
    (should (equal offered "Quarto editing (quarto-mode)"))))

;;; One R target per document

(ert-deftest glassmacs-documents-r-target-is-shared-by-all-chunk-buffers ()
  "A target chosen inside a chunk applies to the prose and every chunk."
  (let* ((base (generate-new-buffer "glassmacs-target.Rmd"))
         (chunk (make-indirect-buffer base " glassmacs-target-r-chunk"))
         (other (make-indirect-buffer base " glassmacs-target-yaml"))
         (unrelated (generate-new-buffer "glassmacs-unrelated.R")))
    (unwind-protect
        (cl-letf (((symbol-function 'glassmacs-sessions-find)
                   (lambda (_id) (glassmacs-session--make :id "R-2" :state 'ready)))
                  ((symbol-function 'glassmacs-sessions--process-live-p)
                   (lambda (_process) t)))
          (with-current-buffer chunk (glassmacs-r-select-session "R-2"))
          (dolist (buffer (list base chunk other))
            (should (equal (buffer-local-value 'glassmacs-r-target-session buffer)
                           "R-2"))
            (should (buffer-local-value 'glassmacs-r-target-indicator-mode buffer)))
          (should-not (buffer-local-value 'glassmacs-r-target-session unrelated))
          (with-current-buffer base (glassmacs-r-clear-session-target))
          (dolist (buffer (list base chunk other))
            (should-not (buffer-local-value 'glassmacs-r-target-session buffer))))
      (kill-buffer chunk)
      (kill-buffer other)
      (kill-buffer base)
      (kill-buffer unrelated))))

(ert-deftest glassmacs-documents-polymode-copies-the-target-to-new-chunks ()
  (let ((polymode-move-these-vars-from-base-buffer '(buffer-file-name)))
    (glassmacs-r--register-polymode-variables)
    (glassmacs-r--register-polymode-variables)
    (should (equal polymode-move-these-vars-from-base-buffer
                   '(glassmacs-r-target-session buffer-file-name)))))

(provide 'test-glassmacs-documents)
;;; test-glassmacs-documents.el ends here
