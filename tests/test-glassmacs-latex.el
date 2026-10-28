;;; test-glassmacs-latex.el --- LaTeX and Sweave PDF tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-latex)

(defun glassmacs-latex-test--require-auctex ()
  "Load AUCTeX or skip the current test."
  (unless (and (locate-library "tex") (locate-library "latex")
               (ignore-errors (require 'tex) (require 'latex) t))
    (ert-skip "AUCTeX is not installed")))

(defmacro glassmacs-latex-test--isolated (&rest body)
  "Run BODY with AUCTeX settings Glassmacs changes restored afterwards."
  `(let ((quote-binding (lookup-key TeX-mode-map "\""))
         (TeX-view-program-list (copy-tree TeX-view-program-list))
         (TeX-view-program-selection (copy-tree TeX-view-program-selection))
         (LaTeX-babel-hyphen LaTeX-babel-hyphen)
         (TeX-PDF-mode TeX-PDF-mode))
     (unwind-protect (progn ,@body)
       (define-key TeX-mode-map "\"" quote-binding))))

(ert-deftest glassmacs-latex-typing-is-literal ()
  "Quotes, dollars, braces and hyphens are inserted exactly as typed."
  (glassmacs-latex-test--require-auctex)
  (glassmacs-latex-test--isolated
   (glassmacs-latex-configure)
   (let ((input "\"q\" 'a' x_1 y^2 $m$ $$d$$ {b} (c) [d] \\[ e \\] -- ... \\emph{z}"))
     (save-window-excursion
       (let ((buffer (generate-new-buffer "glassmacs-literal.tex")))
         (unwind-protect
             (progn
               (switch-to-buffer buffer)
               (LaTeX-mode)
               ;; AUCTeX's syntax checks need font-lock set up in batch.
               (font-lock-set-defaults)
               (execute-kbd-macro input)
               (should (equal (buffer-string) input)))
           (kill-buffer buffer)))))))

(ert-deftest glassmacs-latex-smart-quotes-are-opt-in ()
  (glassmacs-latex-test--require-auctex)
  (glassmacs-latex-test--isolated
   (let ((glassmacs-latex-smart-quotes nil))
     (glassmacs-latex-configure)
     (should (eq (lookup-key TeX-mode-map "\"") #'self-insert-command)))
   (let ((glassmacs-latex-smart-quotes t))
     (glassmacs-latex-configure)
     (should (eq (lookup-key TeX-mode-map "\"") #'TeX-insert-quote)))
   ;; A user's own binding is never replaced.
   (define-key TeX-mode-map "\"" #'ignore)
   (glassmacs-latex-configure)
   (should (eq (lookup-key TeX-mode-map "\"") #'ignore))))

(ert-deftest glassmacs-latex-keeps-user-customizations ()
  (glassmacs-latex-test--require-auctex)
  (glassmacs-latex-test--isolated
   (put 'LaTeX-babel-hyphen 'saved-value '("\"-"))
   (unwind-protect
       (progn
         (setq LaTeX-babel-hyphen "\"-")
         (glassmacs-latex-configure)
         (should (equal LaTeX-babel-hyphen "\"-")))
     (put 'LaTeX-babel-hyphen 'saved-value nil))
   (glassmacs-latex-configure)
   (should (equal LaTeX-babel-hyphen ""))
   (should TeX-PDF-mode)))

(ert-deftest glassmacs-latex-prefers-skim-for-synctex-on-macos ()
  (glassmacs-latex-test--require-auctex)
  (glassmacs-latex-test--isolated
   (let ((system-type 'darwin))
     (cl-letf (((symbol-function 'file-executable-p)
                (lambda (file) (equal file glassmacs-latex-skim-displayline))))
       (glassmacs-latex-configure))
     (should (equal (alist-get 'output-pdf TeX-view-program-selection)
                    '("Glassmacs Skim")))
     (should (string-match-p "displayline -b %n %o %b"
                             (cadr (assoc "Glassmacs Skim" TeX-view-program-list))))
     (cl-letf (((symbol-function 'file-executable-p) (lambda (_file) nil)))
       (glassmacs-latex-configure))
     (should (equal (alist-get 'output-pdf TeX-view-program-selection)
                    '("Glassmacs Preview"))))))

(ert-deftest glassmacs-latex-viewer-choice-follows-preference ()
  (cl-letf (((symbol-function 'file-executable-p) (lambda (_file) t)))
    (let ((glassmacs-latex-pdf-viewer 'preview))
      (should (equal (glassmacs-latex--viewer-name) "Glassmacs Preview")))
    (let ((glassmacs-latex-pdf-viewer 'auto))
      (should (equal (glassmacs-latex--viewer-name) "Glassmacs Skim"))))
  (cl-letf (((symbol-function 'file-executable-p) (lambda (_file) nil)))
    (let ((glassmacs-latex-pdf-viewer 'skim))
      (should (equal (glassmacs-latex--viewer-name) "Glassmacs Skim")))))

(ert-deftest glassmacs-latex-knit-to-pdf-opens-result-on-success ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/glassmacs project/report.Rnw")
    (let (call opened)
      (cl-letf (((symbol-function 'glassmacs-run-process)
                 (lambda (&rest arguments) (setq call arguments)))
                ((symbol-function 'glassmacs-latex-open-pdf)
                 (lambda (pdf) (setq opened pdf))))
        (glassmacs-knit-sweave-pdf)
        (should (equal (nth 0 call) "Rscript"))
        (should (equal (nth 1 call)
                       '("-e" "knitr::knit2pdf(\"/tmp/glassmacs project/report.Rnw\")")))
        (should (equal (nth 2 call) "/tmp/glassmacs project/"))
        (should-not opened)
        (funcall (nth 3 call))
        (should (equal opened "/tmp/glassmacs project/report.pdf"))))
    (setq buffer-file-name nil)))

(ert-deftest glassmacs-run-process-calls-on-success-only-on-success ()
  (let ((glassmacs--current-process nil) succeeded)
    (cl-letf (((symbol-function 'display-buffer) #'ignore)
              ((symbol-function 'message) #'ignore))
      (let ((process (glassmacs-run-process "sh" '("-c" "exit 1") nil
                                            (lambda () (setq succeeded 'failed-run)))))
        (while (process-live-p process) (accept-process-output process 0.05))
        (accept-process-output nil 0.05))
      (should-not succeeded)
      (let ((process (glassmacs-run-process "sh" '("-c" "true") nil
                                            (lambda () (setq succeeded t)))))
        (while (process-live-p process) (accept-process-output process 0.05))
        (accept-process-output nil 0.05))
      (should (eq succeeded t)))))

(provide 'test-glassmacs-latex)
;;; test-glassmacs-latex.el ends here
