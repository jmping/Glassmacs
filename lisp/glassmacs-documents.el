;;; glassmacs-documents.el --- Research document workflows -*- lexical-binding: t; -*-

(require 'glassmacs-core)
(require 'glassmacs-packages)
(require 'glassmacs-document-local)
(require 'glassmacs-document-history)

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

;; poly-R's RMarkdown > Templates submenu asks the running R session for
;; templates, but with no R session its menu filter calls `process-get' on
;; nil and signals an error every time Emacs builds the menu bar (found by
;; `glassmacs-polymode-menus-evaluate-in-prose-and-chunks').  With no
;; session there are no templates to list, so offer none.
(declare-function ess-get-next-available-process "ess-inf" (&optional dialect ignore-busy background))

(defun glassmacs--poly-r-templates-need-r (original &rest arguments)
  "Call ORIGINAL, poly-R's templates menu filter, with ARGUMENTS only
when an R session is available; otherwise list no templates."
  (when (ignore-errors (ess-get-next-available-process "R" t))
    (apply original arguments)))

(with-eval-after-load 'poly-R
  (when (fboundp 'poly-r-rmarkdown-templates-menu)
    (advice-add 'poly-r-rmarkdown-templates-menu :around
                #'glassmacs--poly-r-templates-need-r)))

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


(defcustom glassmacs-document-use-job-adapter nil
  "Use independent local job records and logs for document rendering.
Experimental: the existing single-process rendering path remains the
default until the per-job adapter passes full packaged-app acceptance.
Remote documents are not implicitly executed through this adapter."
  :type 'boolean
  :group 'glassmacs)

(defvar glassmacs-document-render--serial 0
  "Serial number for local document jobs in this Emacs process.")

(defvar-local glassmacs-document-last-job nil
  "Most recent document job initiated from this source buffer.")

(defun glassmacs-document-render--reported-output (job pattern)
  "Find PATTERN's output file in JOB's own log without reading global logs."
  (when-let* ((buffer (glassmacs-document-job-log-buffer job)))
    (with-current-buffer buffer
      (save-excursion
        (goto-char (point-max))
        (when (re-search-backward pattern nil t)
          (expand-file-name (string-trim (match-string-no-properties 1))
                            (glassmacs-document-context-directory
                             (glassmacs-document-job-context job))))))))

(defun glassmacs-document-render--local (kind file program arguments pattern)
  "Run a local KIND build of FILE through a distinct job with output PATTERN."
  (let* ((context (glassmacs-document-context-for-file file))
         (job (glassmacs-document-job-new
               (format "%s-%d" kind (cl-incf glassmacs-document-render--serial))
               context kind))
         (process
          (glassmacs-document-local-start
           job program arguments
           (lambda (finished)
             (when-let* ((output (glassmacs-document-render--reported-output
                                  finished pattern)))
               (setf (glassmacs-document-job-output-file finished) output)
               (when glassmacs-render-open-output
                 (glassmacs-open-rendered-output output))
               (glassmacs-document-history-record finished))))))
    (setq glassmacs-document-last-job job)
    (display-buffer (glassmacs-document-job-log-buffer job))
    process))


(defun glassmacs-document-build-current-job ()
  "Return this document's last job if its source identity still matches.
For polymode chunks, inspect the base document's job without transferring
identity to an unrelated source buffer."
  (let ((base (or (buffer-base-buffer) (current-buffer))))
    (with-current-buffer base
      (when (and (glassmacs-document-job-p glassmacs-document-last-job)
                 (equal buffer-file-name
                        (glassmacs-document-context-source
                         (glassmacs-document-job-context
                          glassmacs-document-last-job))))
        glassmacs-document-last-job))))

(defun glassmacs-document-build-open-remembered-output ()
  "Explicitly open a remembered local output for the current source document."
  (interactive)
  (let* ((base (or (buffer-base-buffer) (current-buffer)))
         (source (buffer-local-value 'buffer-file-name base))
         (output (and source (glassmacs-document-history-find source))))
    (unless output
      (user-error "No remembered local build output for this document"))
    (glassmacs-open-rendered-output output)))

(defun glassmacs-document-build-browse-recent-outputs ()
  "Choose and explicitly open a previously remembered local build output.
The picker shows full source paths to distinguish identically named files.
It does not refresh, render, replay, or open anything until chosen."
  (interactive)
  (let* ((entries (glassmacs-document-history-list))
         (choices (mapcar
                   (lambda (entry)
                     (cons (format "%s  [%s, %s]"
                                   (alist-get 'source entry)
                                   (alist-get 'kind entry)
                                   (alist-get 'time entry))
                           (alist-get 'output entry)))
                   entries)))
    (unless choices
      (user-error "No remembered local build outputs"))
    (let* ((selected (completing-read "Open remembered output for: "
                                     (mapcar #'car choices) nil t))
           (output (cdr (assoc selected choices))))
      (unless output
        (user-error "No remembered output selected"))
      (glassmacs-open-rendered-output output))))

(defun glassmacs-document-build-forget-remembered-output ()
  "Forget this source's remembered output after confirmation.
This changes only the local metadata index; it never deletes an output file."
  (interactive)
  (let* ((base (or (buffer-base-buffer) (current-buffer)))
         (source (buffer-local-value 'buffer-file-name base)))
    (unless (and source (glassmacs-document-history-find source))
      (user-error "No remembered local build output for this document"))
    (when (y-or-n-p (format "Forget remembered output for %s? " source))
      (glassmacs-document-history-forget source)
      (message "Forgot remembered output for %s (file preserved)" source))))

(defun glassmacs-document-build-open-last-output ()
  "Open the current document's most recently reported successful build output."
  (interactive)
  (let ((job (glassmacs-document-build-current-job)))
    (unless (and job
                 (eq (glassmacs-document-job-status job) 'succeeded)
                 (glassmacs-document-job-output-file job))
      (user-error "No successful build output is linked to this document"))
    (glassmacs-open-rendered-output
     (glassmacs-document-job-output-file job))))

(defun glassmacs-document-build-show-status ()
  "Show a read-only snapshot of the current source's last build.
This does not poll, restart, cancel, or reopen any job or output."
  (interactive)
  (let* ((job (glassmacs-document-build-current-job))
         (context (and job (glassmacs-document-job-context job))))
    (unless job
      (user-error "No build is linked to this document"))
    (let ((buffer (get-buffer-create "*Glassmacs Document Build Status*")))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "Source: %s\n" (glassmacs-document-context-source context)))
          (insert (format "Job: %s\nKind: %s\nStatus: %s\n"
                          (glassmacs-document-job-id job)
                          (glassmacs-document-job-kind job)
                          (glassmacs-document-job-status job)))
          (when-let* ((root (glassmacs-document-context-project-root context)))
            (insert (format "Project: %s\n" root)))
          (when-let* ((output (glassmacs-document-job-output-file job)))
            (insert (format "Output: %s\n" output)))
          (when-let* ((error (glassmacs-document-job-error job)))
            (insert (format "Note: %s\n" error)))
          (insert (format "Log: %s\n"
                          (if (buffer-live-p (glassmacs-document-job-log-buffer job))
                              (buffer-name (glassmacs-document-job-log-buffer job))
                            "not retained")))
          (goto-char (point-min))
          (special-mode)))
      (display-buffer buffer)
      buffer)))

(defun glassmacs-document-build-show-last-log ()
  "Display the current document's independent build log."
  (interactive)
  (let* ((job (glassmacs-document-build-current-job))
         (log (and job (glassmacs-document-job-log-buffer job))))
    (unless (buffer-live-p log)
      (user-error "No retained build log is linked to this document"))
    (display-buffer log)))

(defun glassmacs-document-build-cancel ()
  "Cancel only the current document's running experimental local build."
  (interactive)
  (let ((job (glassmacs-document-build-current-job)))
    (unless job
      (user-error "No build is linked to this document"))
    (glassmacs-document-local-cancel job)))

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
  "Render the current R Markdown file with rmarkdown::render() and open it."
  (interactive)
  (let* ((file (glassmacs--current-file))
         (directory (file-name-directory file))
         (arguments
          (list "-e"
                (format "cat(%S, normalizePath(rmarkdown::render(%s)), \"\\n\", sep = \"\")"
                        glassmacs--render-output-marker (glassmacs-r-quote file))))
         (pattern (concat "^" (regexp-quote glassmacs--render-output-marker)
                          "\\(.+\\)$")))
    (if glassmacs-document-use-job-adapter
        (glassmacs-document-render--local 'rmarkdown file "Rscript" arguments pattern)
      (glassmacs-run-process
       "Rscript" arguments directory
       (lambda () (glassmacs--open-render-output pattern directory))))))

(defun glassmacs-render-quarto ()
  "Render the current Quarto document with the Quarto CLI and open it."
  (interactive)
  (let* ((file (glassmacs--current-file))
         (directory (file-name-directory file))
         (arguments (list "render" file))
         (pattern "^Output created: \\(.+\\)$"))
    (if glassmacs-document-use-job-adapter
        (glassmacs-document-render--local 'quarto file "quarto" arguments pattern)
      (glassmacs-run-process
       "quarto" arguments directory
       (lambda () (glassmacs--open-render-output pattern directory))))))

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
