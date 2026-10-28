;;; glassmacs-documents.el --- Research document workflows -*- lexical-binding: t; -*-

(require 'glassmacs-core)
(require 'glassmacs-packages)

(defun glassmacs-rmarkdown-mode ()
  "Use poly-R for an R Markdown file when available."
  (interactive)
  (if (fboundp 'poly-markdown+r-mode)
      (poly-markdown+r-mode)
    (if (fboundp 'markdown-mode) (markdown-mode) (text-mode))
    (glassmacs-packages-offer-installation "R Markdown editing (poly-R)")))

(defun glassmacs-quarto-mode ()
  "Use quarto-mode for a Quarto document when available.
Without it, a Quarto document is edited like R Markdown, which shares its
chunk syntax."
  (interactive)
  (cond
   ((fboundp 'quarto-mode) (quarto-mode))
   ((fboundp 'poly-markdown+r-mode)
    (poly-markdown+r-mode)
    (glassmacs-packages-offer-installation "Quarto editing (quarto-mode)"))
   (t
    (if (fboundp 'markdown-mode) (markdown-mode) (text-mode))
    (glassmacs-packages-offer-installation "Quarto editing (quarto-mode)"))))

(defun glassmacs-sweave-mode ()
  "Use poly-R's Sweave (noweb) mode for Sweave documents when available.
ESS removed its own `Rnw-mode' in version 18.10; current Sweave editing,
with LaTeX prose and R chunks each in their own mode, is poly-R's
`poly-noweb+r-mode'.  An `Rnw-mode' from an older ESS is still used if
that is all there is.  Otherwise fall back to LaTeX mode."
  (interactive)
  (cond
   ((fboundp 'poly-noweb+r-mode) (poly-noweb+r-mode))
   ((fboundp 'Rnw-mode) (Rnw-mode))
   (t
    (cond ((fboundp 'LaTeX-mode) (LaTeX-mode))
          (t (latex-mode)))
    (glassmacs-packages-offer-installation "Sweave editing (poly-R)"))))

(defun glassmacs-rd-mode ()
  "Use ESS's Rd mode for R documentation when available."
  (interactive)
  (if (fboundp 'Rd-mode)
      (Rd-mode)
    (text-mode)
    (glassmacs-packages-offer-installation "R documentation editing (ESS)")))

(add-to-list 'auto-mode-alist '("\\.Rmd\\'" . glassmacs-rmarkdown-mode))
(add-to-list 'auto-mode-alist '("\\.qmd\\'" . glassmacs-quarto-mode))
(add-to-list 'auto-mode-alist '("\\.\\(?:Rnw\\|Snw\\)\\'" . glassmacs-sweave-mode))
(add-to-list 'auto-mode-alist '("\\.Rd\\'" . glassmacs-rd-mode))

(defun glassmacs--current-file ()
  "Return the current buffer's file name, ready to be rendered.
Renderers read the file from disk, so unsaved edits would be silently
left out of the output.  When the buffer is modified, offer to save it
first and refuse to render stale contents if the user declines."
  (unless buffer-file-name
    (user-error "Save this document before rendering"))
  (when (buffer-modified-p)
    (if (y-or-n-p (format "Save %s before rendering? " (buffer-name)))
        (save-buffer)
      (user-error "Rendering uses the saved file; save your changes first")))
  buffer-file-name)

(defcustom glassmacs-render-open-output t
  "Whether rendering a document opens the result when it succeeds.
HTML opens in the web browser, PDF in the PDF viewer (see
`glassmacs-latex-pdf-viewer'), and other formats with their default
application."
  :type 'boolean
  :group 'glassmacs)

(defconst glassmacs--render-output-marker "GLASSMACS_RENDER_OUTPUT="
  "Prefix of the line on which Glassmacs's R render command prints its output.")

(declare-function glassmacs-latex-open-pdf "glassmacs-latex" (pdf))

(defun glassmacs-open-rendered-output (file)
  "Open the rendered output FILE with the appropriate viewer."
  (unless (file-readable-p file)
    (user-error "The rendered file does not exist: %s" file))
  (pcase (downcase (or (file-name-extension file) ""))
    ((or "html" "htm") (browse-url-of-file file))
    ("pdf" (glassmacs-latex-open-pdf file))
    (_ (if (eq system-type 'darwin)
           (call-process "open" nil 0 nil file)
         (find-file-other-window file)))))

(defun glassmacs--render-output (pattern directory)
  "Return the last output file reported by a render, or nil.
Search the process output for PATTERN, whose group 1 is the file name,
relative to DIRECTORY unless absolute."
  (when-let* ((buffer (get-buffer glassmacs-process-buffer-name)))
    (with-current-buffer buffer
      (save-excursion
        (goto-char (point-max))
        (when (re-search-backward pattern nil t)
          (expand-file-name (string-trim (match-string-no-properties 1))
                            directory))))))

(defun glassmacs--open-render-output (pattern directory)
  "Open the output a render reported, if `glassmacs-render-open-output'."
  (when glassmacs-render-open-output
    (let ((output (glassmacs--render-output pattern directory)))
      (if output
          (glassmacs-open-rendered-output output)
        (message "Rendered; the output file was not reported")))))

(defun glassmacs-render-rmarkdown ()
  "Render the current R Markdown file with rmarkdown::render() and open it.
Runs without blocking Emacs.  rmarkdown::render() returns the output file,
which Glassmacs prints and then opens (see `glassmacs-render-open-output')."
  (interactive)
  (let* ((file (glassmacs--current-file))
         (directory (file-name-directory file)))
    (glassmacs-run-process
     "Rscript"
     (list "-e" (format "cat(%S, normalizePath(rmarkdown::render(%s)), \"\\n\", sep = \"\")"
                        glassmacs--render-output-marker (glassmacs-r-quote file)))
     directory
     (lambda ()
       (glassmacs--open-render-output
        (concat "^" (regexp-quote glassmacs--render-output-marker) "\\(.+\\)$")
        directory)))))

(defun glassmacs-render-quarto ()
  "Render the current Quarto document with the Quarto CLI and open it.
Runs without blocking Emacs; the file Quarto reports as \"Output created\"
is opened (see `glassmacs-render-open-output')."
  (interactive)
  (let* ((file (glassmacs--current-file))
         (directory (file-name-directory file)))
    (glassmacs-run-process
     "quarto" (list "render" file) directory
     (lambda ()
       (glassmacs--open-render-output "^Output created: \\(.+\\)$" directory)))))

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
