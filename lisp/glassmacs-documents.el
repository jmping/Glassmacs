;;; glassmacs-documents.el --- Research document workflows -*- lexical-binding: t; -*-

(require 'glassmacs-core)

(defun glassmacs-rmarkdown-mode ()
  "Use poly-R for an R Markdown file when available."
  (interactive)
  (cond
   ((fboundp 'poly-markdown+r-mode) (poly-markdown+r-mode))
   ((fboundp 'markdown-mode) (markdown-mode))
   (t (text-mode))))

(defun glassmacs-quarto-mode ()
  "Use quarto-mode for a Quarto document when available."
  (interactive)
  (cond
   ((fboundp 'quarto-mode) (quarto-mode))
   ((fboundp 'markdown-mode) (markdown-mode))
   (t (text-mode))))

(defun glassmacs-sweave-mode ()
  "Use ESS's Rnw mode for Sweave documents when available."
  (interactive)
  (if (fboundp 'Rnw-mode) (Rnw-mode) (tex-mode)))

(defun glassmacs-rd-mode ()
  "Use ESS's Rd mode for R documentation when available."
  (interactive)
  (if (fboundp 'Rd-mode) (Rd-mode) (text-mode)))

(add-to-list 'auto-mode-alist '("\\.Rmd\\'" . glassmacs-rmarkdown-mode))
(add-to-list 'auto-mode-alist '("\\.qmd\\'" . glassmacs-quarto-mode))
(add-to-list 'auto-mode-alist '("\\.\\(?:Rnw\\|Snw\\)\\'" . glassmacs-sweave-mode))
(add-to-list 'auto-mode-alist '("\\.Rd\\'" . glassmacs-rd-mode))

(defun glassmacs--current-file ()
  "Return the current buffer's file name or report that it is not saved."
  (or buffer-file-name
      (user-error "Save this document before rendering")))

(defun glassmacs-render-rmarkdown ()
  "Render the current R Markdown file with rmarkdown::render()."
  (interactive)
  (let ((file (glassmacs--current-file)))
    (glassmacs-run-process
     "Rscript"
     (list "-e" (format "rmarkdown::render(%s)" (glassmacs-r-quote file)))
     (file-name-directory file))))

(defun glassmacs-render-quarto ()
  "Render the current Quarto document using the Quarto CLI."
  (interactive)
  (let ((file (glassmacs--current-file)))
    (glassmacs-run-process
     "quarto" (list "render" file) (file-name-directory file))))

(defun glassmacs-knit-sweave ()
  "Knit the current Sweave or knitr document using knitr::knit()."
  (interactive)
  (let ((file (glassmacs--current-file)))
    (glassmacs-run-process
     "Rscript"
     (list "-e" (format "knitr::knit(%s)" (glassmacs-r-quote file)))
     (file-name-directory file))))

(provide 'glassmacs-documents)
;;; glassmacs-documents.el ends here
