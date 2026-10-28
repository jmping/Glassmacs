;;; test-glassmacs-chunks.el --- R chunk tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs)

(defconst glassmacs-chunks-test--rmd
  "---
title: Test
---

Prose with `r 1 + 1` inline and `{r} 2 * 3` Quarto inline.

```{r setup, include = FALSE}
library(stats)
```

```{python}
print('not R')
```

```r
plain_markdown_code_not_a_chunk()
```

````{r fenced}
x <- \"```\"
y <- 2
````

```{r skipped, eval = FALSE}
stop('never')
```

```{r}
#| label: last
z <- x
```
"
  "An R Markdown document exercising the chunk parser.")

(defconst glassmacs-chunks-test--rnw
  "\\documentclass{article}
\\begin{document}
Value \\Sexpr{nrow(df)} here.
<<setup, echo = FALSE>>=
df <- data.frame(a = 1:3)
@
Prose.
<<py, engine = 'python'>>=
print(1)
@
<<model>>=
fit <- lm(a ~ 1, df)
<<next>>=
summary(fit)
@
\\end{document}
"
  "A Sweave document, including a chunk that ends where the next begins.")

(defmacro glassmacs-chunks-test--in (name text &rest body)
  "Run BODY in a buffer named NAME containing TEXT, point at the start."
  (declare (indent 2))
  `(with-temp-buffer
     (rename-buffer ,name t)
     (insert ,text)
     (goto-char (point-min))
     ,@body))

(defun glassmacs-chunks-test--codes ()
  "Return the code of every R chunk in the current buffer."
  (mapcar #'glassmacs-chunks-code (glassmacs-chunks-list)))

(defvar glassmacs-chunks-test--submitted nil
  "(SOURCE . ORIGIN) of each queue submission, oldest first.")

(defmacro glassmacs-chunks-test--capturing (&rest body)
  "Run BODY with the R queue stubbed, recording submissions.
Afterwards `glassmacs-chunks-test--submitted' holds them in order."
  `(progn
     (setq glassmacs-chunks-test--submitted nil)
     (cl-letf (((symbol-function 'glassmacs-sessions-resolve) (lambda (&rest _) 'session))
               ((symbol-function 'glassmacs-queue-submit)
                (lambda (source &optional _session origin)
                  (push (cons source origin) glassmacs-chunks-test--submitted))))
       ,@body)
     (setq glassmacs-chunks-test--submitted
           (nreverse glassmacs-chunks-test--submitted))))

;;; Parsing

(ert-deftest glassmacs-chunks-finds-only-r-chunks-in-r-markdown ()
  (glassmacs-chunks-test--in "report.Rmd" glassmacs-chunks-test--rmd
    (should (eq (glassmacs-chunks-syntax) 'markdown))
    (should (equal (glassmacs-chunks-test--codes)
                   '("library(stats)\n"
                     "x <- \"```\"\ny <- 2\n"
                     "stop('never')\n"
                     "#| label: last\nz <- x\n")))
    (should (equal (mapcar #'glassmacs-chunk-label (glassmacs-chunks-list))
                   '("setup" "fenced" "skipped" nil)))))

(ert-deftest glassmacs-chunks-finds-only-r-chunks-in-sweave ()
  (glassmacs-chunks-test--in "paper.Rnw" glassmacs-chunks-test--rnw
    (should (eq (glassmacs-chunks-syntax) 'noweb))
    (should (equal (glassmacs-chunks-test--codes)
                   '("df <- data.frame(a = 1:3)\n"
                     "fit <- lm(a ~ 1, df)\n"
                     "summary(fit)\n")))
    (should (equal (mapcar #'glassmacs-chunk-label (glassmacs-chunks-list))
                   '("setup" "model" "next")))))

(ert-deftest glassmacs-chunks-quarto-uses-markdown-chunks ()
  (glassmacs-chunks-test--in "analysis.qmd" "```{r}\n#| echo: false\nmean(1:3)\n```\n"
    (should (eq (glassmacs-chunks-syntax) 'markdown))
    (should (equal (glassmacs-chunks-test--codes) '("#| echo: false\nmean(1:3)\n")))))

(ert-deftest glassmacs-chunks-ordinary-files-have-no-chunks ()
  (glassmacs-chunks-test--in "notes.md" "```{r}\nx\n```\n"
    (should-not (glassmacs-chunks-syntax))
    (should-not (glassmacs-chunks-list))
    (should-error (glassmacs-chunks-run-all) :type 'user-error)))

(ert-deftest glassmacs-chunks-detects-disabled-evaluation ()
  (dolist (case '(("```{r, eval = FALSE}\nx\n```\n" . t)
                  ("```{r eval=F}\nx\n```\n" . t)
                  ("```{r}\n#| eval: false\nx\n```\n" . t)
                  ("```{r, eval = TRUE}\nx\n```\n" . nil)
                  ("```{r}\nevaluate(FALSE)\n```\n" . nil)))
    (glassmacs-chunks-test--in "case.Rmd" (car case)
      (should (eq (and (glassmacs-chunks-eval-disabled-p (car (glassmacs-chunks-list))) t)
                  (cdr case))))))

(ert-deftest glassmacs-chunks-locates-the-chunk-at-point ()
  (glassmacs-chunks-test--in "report.Rmd" glassmacs-chunks-test--rmd
    (search-forward "y <- 2")
    (should (equal (glassmacs-chunk-label (glassmacs-chunks-at)) "fenced"))
    (goto-char (point-min))
    (search-forward "````{r fenced}")
    (should (equal (glassmacs-chunk-label (glassmacs-chunks-at)) "fenced"))
    (goto-char (point-min))
    (search-forward "Prose with")
    (should-not (glassmacs-chunks-at))
    (search-forward "print('not R')")
    (should-not (glassmacs-chunks-at))))

;;; Running

(ert-deftest glassmacs-chunks-run-current-queues-the-chunk-as-one-unit ()
  (glassmacs-chunks-test--in "report.Rmd" glassmacs-chunks-test--rmd
    (search-forward "y <- 2")
    (glassmacs-chunks-test--capturing (glassmacs-chunks-run-current))
    (should (equal (mapcar #'car glassmacs-chunks-test--submitted) '("x <- \"```\"\ny <- 2\n")))
    (should (eq (plist-get (cdar glassmacs-chunks-test--submitted) :operation) 'chunk))
    (should (equal (plist-get (cdar glassmacs-chunks-test--submitted) :label) "fenced"))
    ;; Explicitly running an eval = FALSE chunk still runs it.
    (search-forward "stop('never')")
    (glassmacs-chunks-test--capturing (glassmacs-chunks-run-current))
    (should (equal (mapcar #'car glassmacs-chunks-test--submitted) '("stop('never')\n")))
    (goto-char (point-min))
    (should-error (glassmacs-chunks-run-current) :type 'user-error)))

(ert-deftest glassmacs-chunks-run-above-runs-earlier-chunks-in-order ()
  (glassmacs-chunks-test--in "report.Rmd" glassmacs-chunks-test--rmd
    (search-forward "z <- x")
    (glassmacs-chunks-test--capturing (glassmacs-chunks-run-above))
    ;; The eval = FALSE chunk is skipped, and the chunk at point is not run.
    (should (equal (mapcar #'car glassmacs-chunks-test--submitted)
                   '("library(stats)\n" "x <- \"```\"\ny <- 2\n")))))

(ert-deftest glassmacs-chunks-run-all-runs-every-evaluated-chunk ()
  (glassmacs-chunks-test--in "paper.Rnw" glassmacs-chunks-test--rnw
    (let (reported)
      (cl-letf (((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (setq reported (apply #'format format-string args)))))
        (glassmacs-chunks-test--capturing (glassmacs-chunks-run-all)))
      (should (equal (mapcar #'car glassmacs-chunks-test--submitted)
                     '("df <- data.frame(a = 1:3)\n" "fit <- lm(a ~ 1, df)\n"
                       "summary(fit)\n")))
      (should (equal reported "Queued 3 R chunks")))))

(ert-deftest glassmacs-chunks-run-inline-code ()
  (glassmacs-chunks-test--in "report.Rmd" glassmacs-chunks-test--rmd
    (search-forward "1 + ")
    (glassmacs-chunks-test--capturing (glassmacs-chunks-run-inline))
    (should (equal (mapcar #'car glassmacs-chunks-test--submitted) '("1 + 1")))
    (search-forward "2 * ")
    (glassmacs-chunks-test--capturing (glassmacs-chunks-run-inline))
    (should (equal (mapcar #'car glassmacs-chunks-test--submitted) '("2 * 3"))))
  (glassmacs-chunks-test--in "paper.Rnw" glassmacs-chunks-test--rnw
    (search-forward "nrow")
    (glassmacs-chunks-test--capturing (glassmacs-chunks-run-inline))
    (should (equal (mapcar #'car glassmacs-chunks-test--submitted) '("nrow(df)")))
    (goto-char (point-min))
    (should-error (glassmacs-chunks-run-inline) :type 'user-error)))

(ert-deftest glassmacs-chunks-run-in-a-real-r-session ()
  (unless (and (locate-library "ess-site") (executable-find "R"))
    (ert-skip "ESS and R are not installed"))
  (require 'ess-site)
  (let ((glassmacs-sessions--list nil)
        (glassmacs-sessions--history nil)
        (default-directory temporary-file-directory)
        (ess-ask-for-ess-directory nil)
        (ess-history-file nil)
        (inhibit-message t)
        console)
    (unwind-protect
        (progn
          (save-window-excursion (setq console (R)))
          (let* ((session (car (glassmacs-sessions-refresh)))
                 (process (glassmacs-session-process session)))
            (glassmacs-chunks-test--in "real.Rmd"
                "```{r}\nglassmacs_chunk_value <- 6 * 7\n```\n"
              (glassmacs-chunks-run-all))
            (let ((deadline (+ (float-time) 30)))
              (while (and (< (float-time) deadline)
                          (not (cl-every (lambda (e) (eq (glassmacs-entry-state e) 'completed))
                                         (glassmacs-session-entries session))))
                (accept-process-output process 0.1)
                (glassmacs-sessions--tick)))
            (should (equal (ess-get-words-from-vector
                            "as.character(glassmacs_chunk_value)\n" nil nil process)
                           '("42")))))
      (glassmacs-sessions--cancel-timer)
      (when (buffer-live-p console)
        (let ((kill-buffer-query-functions nil)) (kill-buffer console))))))

;;; Moving and inserting

(ert-deftest glassmacs-chunks-move-between-chunks ()
  (glassmacs-chunks-test--in "report.Rmd" glassmacs-chunks-test--rmd
    (glassmacs-chunks-next)
    (should (looking-at "library(stats)"))
    (glassmacs-chunks-next 2)
    (should (looking-at "stop('never')"))
    (glassmacs-chunks-previous)
    (should (looking-at "x <- "))
    (goto-char (point-max))
    (should-error (glassmacs-chunks-next) :type 'user-error)))

(ert-deftest glassmacs-chunks-insert-chunk-for-each-syntax ()
  (glassmacs-chunks-test--in "new.Rmd" "Prose\n"
    (goto-char (point-max))
    (glassmacs-chunks-insert)
    (insert "x <- 1")
    (should (equal (buffer-string) "Prose\n```{r}\nx <- 1\n```\n"))
    (should (glassmacs-chunks-at))
    (should-error (glassmacs-chunks-insert) :type 'user-error))
  (glassmacs-chunks-test--in "new.Rnw" "Prose "
    (goto-char (point-max))
    (glassmacs-chunks-insert)
    (should (equal (buffer-string) "Prose \n<<>>=\n\n@\n")))
  (glassmacs-chunks-test--in "wrap.Rmd" "a\nmean(x)\nb\n"
    (transient-mark-mode 1)
    (goto-char 3)
    (set-mark 3)
    (forward-line 1)
    (activate-mark)
    (glassmacs-chunks-insert)
    (should (equal (buffer-string) "a\n```{r}\nmean(x)\n```\nb\n"))))

;;; Document mode

(ert-deftest glassmacs-chunks-document-mode-turns-on-in-documents-only ()
  (glassmacs-chunks-test--in "report.Rmd" ""
    (text-mode)
    (should glassmacs-document-mode))
  (glassmacs-chunks-test--in "paper.Rnw" ""
    (text-mode)
    (should glassmacs-document-mode))
  (glassmacs-chunks-test--in "notes.txt" ""
    (text-mode)
    (should-not glassmacs-document-mode)))

(ert-deftest glassmacs-chunks-shortcuts-and-menu ()
  (dolist (entry '(("S-s-<return>" . glassmacs-chunks-run-current)
                   ("M-s-i" . glassmacs-chunks-insert)
                   ("M-s-p" . glassmacs-chunks-run-above)
                   ("M-s-r" . glassmacs-chunks-run-all)
                   ("M-s-<down>" . glassmacs-chunks-next)
                   ("M-s-<up>" . glassmacs-chunks-previous)))
    (should (eq (lookup-key glassmacs-document-mode-map (kbd (car entry)))
                (cdr entry))))
  (should (eq (lookup-key glassmacs-document-mode-map [menu-bar glassmacs-document])
              glassmacs-document-menu)))

(ert-deftest glassmacs-chunks-render-uses-the-documents-tool ()
  (dolist (case '(("a.Rmd" . glassmacs-render-rmarkdown)
                  ("a.qmd" . glassmacs-render-quarto)
                  ("a.Rnw" . glassmacs-knit-sweave-pdf)))
    (let (called)
      (cl-letf (((symbol-function 'glassmacs-render-rmarkdown)
                 (lambda () (setq called 'glassmacs-render-rmarkdown)))
                ((symbol-function 'glassmacs-render-quarto)
                 (lambda () (setq called 'glassmacs-render-quarto)))
                ((symbol-function 'glassmacs-knit-sweave-pdf)
                 (lambda () (setq called 'glassmacs-knit-sweave-pdf))))
        (with-temp-buffer
          (setq buffer-file-name (expand-file-name (car case) temporary-file-directory))
          (glassmacs-chunks-render)
          (setq buffer-file-name nil)))
      (should (eq called (cdr case))))))

;;; Toolbar and spelling

(ert-deftest glassmacs-chunks-toolbar-icons-are-bundled-with-emacs ()
  (require 'image)
  (dolist (entry glassmacs-chunks--toolbar-actions)
    (should (locate-file (concat (nth 3 entry) ".xpm") image-load-path))))

(ert-deftest glassmacs-chunks-prose-buffer-gets-the-document-toolbar ()
  (glassmacs-chunks-test--in "report.Rmd" ""
    (let ((glassmacs-r-show-toolbar t))
      (text-mode)
      (should (local-variable-p 'tool-bar-map))
      (should (eq (lookup-key tool-bar-map [run-chunk]) 'glassmacs-chunks-run-current))
      (should (eq (lookup-key tool-bar-map [render]) 'glassmacs-chunks-render)))))

(ert-deftest glassmacs-chunks-spelling-skips-chunk-and-inline-code ()
  (glassmacs-chunks-test--in "report.Rmd"
      "Prose teh.\n\n```{r}\nfoo_bar <- qzxv(1)\n```\n\nValue `r wqzx(2)` here.\n"
    (let ((glassmacs-spelling--r-names nil) skipped)
      (goto-char (point-min))
      (while (re-search-forward "[[:alpha:]]+" nil t)
        (let ((word (match-string 0)))
          (when (glassmacs-spelling-skip-word-p (match-beginning 0) (match-end 0))
            ;; The check must not disturb the caller's match data.
            (should (equal (match-string 0) word))
            (push word skipped))))
      ;; Everything inside the chunk and the inline code is skipped; the
      ;; misspelled prose word is still checked.
      (should (member "qzxv" skipped))
      (should (member "wqzx" skipped))
      (should-not (member "teh" skipped))
      (should-not (member "Prose" skipped)))))

(provide 'test-glassmacs-chunks)
;;; test-glassmacs-chunks.el ends here
