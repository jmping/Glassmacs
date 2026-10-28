;;; test-glassmacs-documents.el --- Mixed R document tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs)

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

(provide 'test-glassmacs-documents)
;;; test-glassmacs-documents.el ends here
