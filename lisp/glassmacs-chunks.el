;;; glassmacs-chunks.el --- R chunks in R Markdown, Quarto and Sweave -*- lexical-binding: t; -*-

;; Documents that mix prose and R code: R Markdown (.Rmd), Quarto (.qmd)
;; and Sweave/knitr (.Rnw, .Snw).  polymode and poly-R provide the editing
;; (each chunk in ESS's R mode, prose in Markdown or LaTeX mode); this
;; module adds what Glassmacs needs on top: finding R chunks, running them
;; through Glassmacs's R session targeting and queue, moving between and
;; inserting chunks, and a document menu, toolbar and shortcuts.
;;
;; Chunks are found by a small parser of their delimiters rather than by
;; polymode's span machinery, so running code behaves the same with or
;; without polymode installed, and is independent of display state.
;;
;; Running code: one chunk is one queue entry, sent as a unit to the
;; document's R session (its explicit target, shared by the prose and every
;; chunk buffer, or the only live session; with several and no target you
;; are asked).  Running several chunks queues them in document order.
;; Running all chunks, or all chunks above point, skips chunks marked
;; eval = FALSE (or Quarto's #| eval: false), as knitting would; running
;; the current chunk always runs it, because you asked for that chunk.

(require 'cl-lib)
(require 'subr-x)
(require 'glassmacs-sessions)

(defgroup glassmacs-chunks nil
  "R chunks in R Markdown, Quarto and Sweave documents."
  :group 'glassmacs-r)

;;; Document syntax

(defconst glassmacs-chunks--markdown-file-regexp
  "\\.\\(?:[Rr]md\\|[Rr]markdown\\|qmd\\)\\'"
  "File names of documents with Markdown-fenced chunks.")

(defconst glassmacs-chunks--noweb-file-regexp
  "\\.[RrSs]nw\\'"
  "File names of Sweave/knitr documents with noweb chunks.")

(defun glassmacs-chunks--base ()
  "Return the buffer holding the whole document (polymode's base buffer)."
  (or (buffer-base-buffer) (current-buffer)))

(defun glassmacs-chunks-syntax ()
  "Return the chunk syntax of the current document: `markdown', `noweb' or nil."
  (let ((base (glassmacs-chunks--base)))
    (with-current-buffer base
      (let ((file (or buffer-file-name (buffer-name))))
        (cond
         ((string-match-p glassmacs-chunks--markdown-file-regexp file) 'markdown)
         ((string-match-p glassmacs-chunks--noweb-file-regexp file) 'noweb)
         ((or (bound-and-true-p poly-markdown+r-mode)
              (bound-and-true-p quarto-mode))
          'markdown)
         ((bound-and-true-p poly-noweb+r-mode) 'noweb))))))

;;; Parsing chunks

(cl-defstruct (glassmacs-chunk (:constructor glassmacs-chunk--make)
                               (:copier nil))
  "An R chunk.  START is the start of its header line, END the end of its
closing line; the code lies between BODY-START and BODY-END."
  start body-start body-end end label options)

(defconst glassmacs-chunks--markdown-header
  "^\\([ \t]*\\)\\(`\\{3,\\}\\)[ \t]*{[ \t]*\\([[:alnum:]_]+\\)\\([^}\n]*\\)}[ \t]*$"
  "A fenced chunk header such as ```{r label, echo = FALSE}.
Groups: indentation, backticks, engine, options.")

(defconst glassmacs-chunks--noweb-header "^[ \t]*<<\\(.*\\)>>=[ \t]*$"
  "A noweb chunk header such as <<label, echo = FALSE>>=.  Group: options.")

(defconst glassmacs-chunks--noweb-close "^[ \t]*@\\(?:[ \t].*\\)?$"
  "The line that ends a noweb chunk.")

(defun glassmacs-chunks--label (options)
  "Return the chunk label in OPTIONS (the text after the engine), or nil."
  (let ((first (string-trim (or (car (split-string options "," t "[ \t]+"))
                                ""))))
    (unless (or (string-empty-p first) (string-match-p "=" first))
      first)))

(defun glassmacs-chunks--r-engine-p (engine options)
  "Return non-nil when a chunk with ENGINE and OPTIONS runs R code."
  (and (member (downcase engine) '("r"))
       (not (string-match-p "\\bengine[ \t]*=[ \t]*['\"]?\\([^rR'\"]\\|[rR][[:alnum:]]\\)"
                            options))))

(defun glassmacs-chunks--parse-markdown ()
  "Return the R chunks of the current Markdown document, in order."
  (let (chunks)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward glassmacs-chunks--markdown-header nil t)
          (let* ((start (line-beginning-position))
                 (fence (match-string-no-properties 2))
                 (engine (match-string-no-properties 3))
                 (options (match-string-no-properties 4))
                 (body-start (min (point-max) (1+ (line-end-position))))
                 (close (concat "^[ \t]*" (regexp-quote fence) "`*[ \t]*$")))
            (goto-char body-start)
            (if (re-search-forward close nil t)
                (let ((body-end (line-beginning-position))
                      (end (line-end-position)))
                  (when (glassmacs-chunks--r-engine-p engine options)
                    (push (glassmacs-chunk--make
                           :start start :body-start body-start :body-end body-end
                           :end end :label (glassmacs-chunks--label options)
                           :options options)
                          chunks)))
              (goto-char (point-max)))))))
    (nreverse chunks)))

(defun glassmacs-chunks--parse-noweb ()
  "Return the R chunks of the current Sweave/knitr document, in order."
  (let (chunks)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward glassmacs-chunks--noweb-header nil t)
          (let* ((start (line-beginning-position))
                 (options (match-string-no-properties 1))
                 (body-start (min (point-max) (1+ (line-end-position)))))
            (goto-char body-start)
            ;; A chunk ends at its @ line, or where the next chunk starts.
            (let* ((close (save-excursion
                            (and (re-search-forward glassmacs-chunks--noweb-close nil t)
                                 (line-beginning-position))))
                   (next (save-excursion
                           (and (re-search-forward glassmacs-chunks--noweb-header nil t)
                                (line-beginning-position))))
                   (body-end (cond ((and close next) (min close next))
                                   (t (or close next (point-max)))))
                   (end (if (and close (eql body-end close))
                            (save-excursion (goto-char close) (line-end-position))
                          body-end)))
              (when (glassmacs-chunks--r-engine-p "r" options)
                (push (glassmacs-chunk--make
                       :start start :body-start body-start :body-end body-end
                       :end end :label (glassmacs-chunks--label options)
                       :options options)
                      chunks))
              (goto-char (max body-start body-end)))))))
    (nreverse chunks)))

(defun glassmacs-chunks-list ()
  "Return the R chunks of the current document, in document order."
  (pcase (glassmacs-chunks-syntax)
    ('markdown (glassmacs-chunks--parse-markdown))
    ('noweb (glassmacs-chunks--parse-noweb))))

(defun glassmacs-chunks-at (&optional position)
  "Return the R chunk containing POSITION (default point), or nil.
A chunk includes its header and closing lines."
  (let ((position (or position (point))))
    (cl-find-if (lambda (chunk)
                  (<= (glassmacs-chunk-start chunk) position
                      (glassmacs-chunk-end chunk)))
                (glassmacs-chunks-list))))

(defvar-local glassmacs-chunks--code-regions-cache nil
  "(MODIFICATION-TICK . REGIONS) of R code in this document.")

(defun glassmacs-chunks-code-position-p (position)
  "Return non-nil when POSITION is inside R code: a chunk or inline code.
Regions are cached per buffer modification, so this is cheap to call for
every word, as spell checking does.  The caller's match data is kept."
  (save-match-data
   (when (glassmacs-chunks-syntax)
    (let* ((tick (buffer-chars-modified-tick))
           (regions (if (eql (car glassmacs-chunks--code-regions-cache) tick)
                        (cdr glassmacs-chunks--code-regions-cache)
                      (cdr (setq glassmacs-chunks--code-regions-cache
                                 (cons tick
                                       (mapcar (lambda (chunk)
                                                 (cons (glassmacs-chunk-start chunk)
                                                       (glassmacs-chunk-end chunk)))
                                               (glassmacs-chunks-list))))))))
      (or (cl-some (lambda (region) (<= (car region) position (cdr region))) regions)
          (glassmacs-chunks-inline-at position))))))

(defun glassmacs-chunks-code (chunk)
  "Return CHUNK's R code without text properties."
  (buffer-substring-no-properties (glassmacs-chunk-body-start chunk)
                                  (glassmacs-chunk-body-end chunk)))

(defun glassmacs-chunks-eval-disabled-p (chunk)
  "Return non-nil when CHUNK is marked not to be evaluated."
  (let ((case-fold-search nil))
    (or (string-match-p "\\beval[ \t]*=[ \t]*\\(?:FALSE\\|F\\)\\b"
                        (or (glassmacs-chunk-options chunk) ""))
        (string-match-p "^#|[ \t]*eval:[ \t]*false\\b" (glassmacs-chunks-code chunk)))))

;;; Inline code

(defconst glassmacs-chunks--inline-patterns
  '((markdown . ("`r[ \t]+\\([^`\n]+\\)`" "`{r}[ \t]+\\([^`\n]+\\)`"))
    (noweb . ("\\\\Sexpr{\\([^}\n]*\\)}")))
  "Inline R code patterns by syntax; group 1 is the expression.")

(defun glassmacs-chunks-inline-at (&optional position)
  "Return (EXPRESSION START . END) for inline R code at POSITION, or nil."
  (let ((position (or position (point)))
        (patterns (alist-get (glassmacs-chunks-syntax)
                             glassmacs-chunks--inline-patterns)))
    (save-excursion
      (goto-char position)
      (let ((line-start (line-beginning-position))
            (line-end (line-end-position))
            found)
        (dolist (pattern patterns)
          (goto-char line-start)
          (while (and (not found) (re-search-forward pattern line-end t))
            (when (<= (match-beginning 0) position (match-end 0))
              (setq found (cons (match-string-no-properties 1)
                                (cons (match-beginning 0) (match-end 0)))))))
        found))))

;;; Running code

(defun glassmacs-chunks--submit (chunks)
  "Queue CHUNKS, in order, for the document's R session.
Return the number queued."
  (let ((session (glassmacs-sessions-resolve))
        (buffer (buffer-name (glassmacs-chunks--base))))
    (dolist (chunk chunks)
      (glassmacs-queue-submit
       (glassmacs-chunks-code chunk) session
       (list :buffer buffer :operation 'chunk
             :label (glassmacs-chunk-label chunk)
             :start (glassmacs-chunk-start chunk)
             :end (glassmacs-chunk-end chunk))))
    (length chunks)))

(defun glassmacs-chunks--runnable (chunks)
  "Return CHUNKS that should run, skipping blank and eval = FALSE chunks."
  (cl-remove-if (lambda (chunk)
                  (or (glassmacs-chunks-eval-disabled-p chunk)
                      (not (string-match-p "[^ \t\n\r]"
                                           (glassmacs-chunks-code chunk)))))
                chunks))

(defun glassmacs-chunks--report (queued total)
  "Report QUEUED of TOTAL chunks were sent."
  (message "Queued %d R chunk%s%s" queued (if (= queued 1) "" "s")
           (if (< queued total)
               (format " (%d skipped: eval = FALSE or empty)" (- total queued))
             "")))

(defun glassmacs-chunks--require-document ()
  "Signal a user error unless the current buffer is a document with chunks."
  (unless (glassmacs-chunks-syntax)
    (user-error "Not an R Markdown, Quarto or Sweave document")))

(defun glassmacs-chunks-run-current ()
  "Run the R chunk at point in the document's R session."
  (interactive)
  (glassmacs-chunks--require-document)
  (let ((chunk (or (glassmacs-chunks-at)
                   (user-error "Point is not in an R chunk"))))
    (when (string-empty-p (string-trim (glassmacs-chunks-code chunk)))
      (user-error "This R chunk is empty"))
    (glassmacs-chunks--submit (list chunk))
    (message "Queued R chunk%s"
             (if (glassmacs-chunk-label chunk)
                 (format " %s" (glassmacs-chunk-label chunk)) ""))))

(defun glassmacs-chunks-run-above ()
  "Run every R chunk above point (and above the chunk at point), in order."
  (interactive)
  (glassmacs-chunks--require-document)
  (let* ((limit (let ((chunk (glassmacs-chunks-at)))
                  (if chunk (glassmacs-chunk-start chunk) (point))))
         (above (cl-remove-if-not (lambda (chunk) (<= (glassmacs-chunk-end chunk) limit))
                                  (glassmacs-chunks-list)))
         (runnable (glassmacs-chunks--runnable above)))
    (unless above (user-error "No R chunks above point"))
    (glassmacs-chunks--report (glassmacs-chunks--submit runnable) (length above))))

(defun glassmacs-chunks-run-all ()
  "Run every R chunk in the document, in order."
  (interactive)
  (glassmacs-chunks--require-document)
  (let* ((chunks (or (glassmacs-chunks-list)
                     (user-error "This document has no R chunks")))
         (runnable (glassmacs-chunks--runnable chunks)))
    (glassmacs-chunks--report (glassmacs-chunks--submit runnable) (length chunks))))

(defun glassmacs-chunks-run-inline ()
  "Run the inline R expression at point and show its value in the console."
  (interactive)
  (glassmacs-chunks--require-document)
  (let ((inline (or (glassmacs-chunks-inline-at)
                    (user-error "Point is not on inline R code"))))
    (glassmacs-queue-submit
     (car inline) nil
     (list :buffer (buffer-name (glassmacs-chunks--base)) :operation 'inline
           :start (cadr inline) :end (cddr inline)))
    (message "Queued inline R expression")))

;;; Moving and inserting

(defun glassmacs-chunks-next (&optional count)
  "Move to the code of the COUNTth next R chunk."
  (interactive "p")
  (glassmacs-chunks--require-document)
  (let* ((count (or count 1))
         (chunks (if (< count 0)
                     (reverse (cl-remove-if-not
                               (lambda (c) (< (glassmacs-chunk-end c) (line-beginning-position)))
                               (glassmacs-chunks-list)))
                   (cl-remove-if-not
                    (lambda (c) (> (glassmacs-chunk-start c) (line-end-position)))
                    (glassmacs-chunks-list))))
         (target (nth (1- (abs count)) chunks)))
    (unless target
      (user-error "No %s R chunk" (if (< count 0) "previous" "next")))
    (goto-char (glassmacs-chunk-body-start target))))

(defun glassmacs-chunks-previous (&optional count)
  "Move to the code of the COUNTth previous R chunk."
  (interactive "p")
  (glassmacs-chunks-next (- (or count 1))))

(defun glassmacs-chunks-insert ()
  "Insert an empty R chunk at point, or wrap the region in one.
Point ends up inside the new chunk.  Chunks are not nested: inside an
existing chunk this signals an error."
  (interactive)
  (glassmacs-chunks--require-document)
  (when (glassmacs-chunks-at)
    (user-error "Point is already in an R chunk"))
  (let* ((noweb (eq (glassmacs-chunks-syntax) 'noweb))
         (open (if noweb "<<>>=" "```{r}"))
         (close (if noweb "@" "```"))
         (region (and (use-region-p)
                      (cons (region-beginning) (region-end)))))
    (if region
        (let ((code (buffer-substring (car region) (cdr region))))
          (delete-region (car region) (cdr region))
          (goto-char (car region))
          (unless (bolp) (insert "\n"))
          (insert open "\n" code)
          (unless (bolp) (insert "\n"))
          (insert close "\n"))
      (unless (bolp) (insert "\n"))
      (insert open "\n")
      (save-excursion (insert "\n" close "\n")))))

;;; Document mode

(declare-function glassmacs-render-rmarkdown "glassmacs-documents" ())
(declare-function glassmacs-render-quarto "glassmacs-documents" ())
(declare-function glassmacs-knit-sweave-pdf "glassmacs-latex" ())
(declare-function glassmacs-shiny-interactive-document-p "glassmacs-shiny" ())
(declare-function glassmacs-run-interactive-document "glassmacs-shiny" ())

(defun glassmacs-chunks-render ()
  "Render (knit) the current document with the tool for its type.
An interactive document (runtime: shiny, or Quarto server: shiny) is run
as a local Shiny app instead, since it cannot be rendered to a file."
  (interactive)
  (glassmacs-chunks--require-document)
  (let ((file (buffer-file-name (glassmacs-chunks--base))))
    (with-current-buffer (glassmacs-chunks--base)
      (cond
       ((glassmacs-shiny-interactive-document-p) (glassmacs-run-interactive-document))
       ((and file (string-match-p "\\.qmd\\'" file)) (glassmacs-render-quarto))
       ((eq (glassmacs-chunks-syntax) 'noweb) (glassmacs-knit-sweave-pdf))
       (t (glassmacs-render-rmarkdown))))))

(defvar glassmacs-document-menu
  (let ((menu (make-sparse-keymap "R Document")))
    (define-key menu [shiny-preview]
      '(menu-item "Open Shiny Preview" glassmacs-shiny-open-preview
                  :enable (bound-and-true-p glassmacs-shiny-url)))
    (define-key menu [shiny-stop]
      '(menu-item "Stop Interactive Document" glassmacs-shiny-stop
                  :visible (glassmacs-shiny-interactive-document-p)
                  :enable (bound-and-true-p glassmacs-shiny-process)))
    (define-key menu [render]
      '(menu-item "Render Document" glassmacs-chunks-render
                  :visible (not (glassmacs-shiny-interactive-document-p))
                  :help "Knit or render this document and open the result"))
    (define-key menu [run-interactive]
      '(menu-item "Run Interactive Document" glassmacs-run-interactive-document
                  :visible (glassmacs-shiny-interactive-document-p)
                  :help "Run this runtime: shiny document and open it in the browser"))
    (define-key menu [separator-render] menu-bar-separator)
    (define-key menu [insert]
      '(menu-item "Insert R Chunk" glassmacs-chunks-insert))
    (define-key menu [previous]
      '(menu-item "Previous R Chunk" glassmacs-chunks-previous))
    (define-key menu [next]
      '(menu-item "Next R Chunk" glassmacs-chunks-next))
    (define-key menu [separator-move] menu-bar-separator)
    (define-key menu [run-inline]
      '(menu-item "Run Inline R Code" glassmacs-chunks-run-inline))
    (define-key menu [run-all]
      '(menu-item "Run All Chunks" glassmacs-chunks-run-all))
    (define-key menu [run-above]
      '(menu-item "Run Chunks Above" glassmacs-chunks-run-above))
    (define-key menu [run-current]
      '(menu-item "Run Chunk" glassmacs-chunks-run-current))
    menu)
  "Menu of R chunk and document commands.")

(defvar glassmacs-document-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Shortcuts familiar from RStudio, on Command (Super) so that ESS's and
    ;; Emacs's own C-c and Meta bindings stay untouched.
    (define-key map (kbd "S-s-<return>") #'glassmacs-chunks-run-current)
    (define-key map [?\M-\s-i] #'glassmacs-chunks-insert)
    (define-key map [?\M-\s-p] #'glassmacs-chunks-run-above)
    (define-key map [?\M-\s-r] #'glassmacs-chunks-run-all)
    (define-key map [M-s-down] #'glassmacs-chunks-next)
    (define-key map [M-s-up] #'glassmacs-chunks-previous)
    (define-key map [?\M-\s-k] #'glassmacs-chunks-render)
    (define-key map [menu-bar glassmacs-document] glassmacs-document-menu)
    map)
  "Keymap for `glassmacs-document-mode'.")

(defvar glassmacs-r-show-toolbar)

;; ICON names must be images GNU Emacs ships (see glassmacs-r-ui.el).
(defconst glassmacs-chunks--toolbar-actions
  '((run-chunk "Run Chunk" glassmacs-chunks-run-current "jump-to")
    (run-all "Run All Chunks" glassmacs-chunks-run-all "next-page")
    (insert-chunk "Insert R Chunk" glassmacs-chunks-insert "new")
    (render "Render Document" glassmacs-chunks-render "show"))
  "Document toolbar entries: (KEY LABEL COMMAND ICON).")

(defun glassmacs-chunks--toolbar-map ()
  "Return a toolbar keymap with the document commands."
  (let ((map (make-sparse-keymap)))
    (dolist (entry glassmacs-chunks--toolbar-actions)
      (pcase-let ((`(,key ,label ,command ,icon) entry))
        (define-key-after map (vector key)
          `(menu-item ,label ,command
                      :image (and (display-graphic-p)
                                  (find-image
                                   (list (list :type 'xpm :file ,(concat icon ".xpm")))))
                      :help ,label))))
    map))

(define-minor-mode glassmacs-document-mode
  "Run, move between and insert R chunks in R Markdown, Quarto and Sweave.
In the document's prose buffer it also shows a toolbar with the main
commands when `glassmacs-r-show-toolbar' is non-nil; chunk buffers keep
the R toolbar.
\\{glassmacs-document-mode-map}"
  :keymap glassmacs-document-mode-map
  (when (and glassmacs-document-mode
             (bound-and-true-p glassmacs-r-show-toolbar)
             (not (derived-mode-p 'ess-r-mode)))
    (setq-local tool-bar-map (glassmacs-chunks--toolbar-map))))

(defun glassmacs-chunks--maybe-enable ()
  "Turn on `glassmacs-document-mode' in documents with R chunks.
Runs after every major-mode change, so it also covers the chunk buffers
polymode creates for the same document."
  (when (and (not (minibufferp)) (glassmacs-chunks-syntax))
    (glassmacs-document-mode 1)))

(add-hook 'after-change-major-mode-hook #'glassmacs-chunks--maybe-enable)

(provide 'glassmacs-chunks)
;;; glassmacs-chunks.el ends here
