;;; test-glassmacs-polymode.el --- Mixed documents with real polymode -*- lexical-binding: t; -*-

;; These tests use the real polymode, poly-R and ESS packages and are
;; skipped when they are not installed.  CI's integration job installs
;; pinned versions of them.

(require 'ert)
(require 'cl-lib)
(require 'glassmacs)

(declare-function pm-switch-to-buffer "polymode-core" (&optional pos-or-span))
(defvar polymode-mode)

(defun glassmacs-polymode-test--require ()
  "Load ESS and poly-R, or skip the current test."
  (unless (and (locate-library "poly-R") (locate-library "ess-site")
               (locate-library "markdown-mode"))
    (ert-skip "polymode, poly-R, markdown-mode and ESS are not all installed"))
  (require 'ess-site)
  (require 'poly-R))

(defmacro glassmacs-polymode-test--visiting (name text &rest body)
  "Visit a new file NAME containing TEXT in the selected window and run BODY.
The document's buffers are killed afterwards."
  (declare (indent 2))
  `(let* ((directory (make-temp-file "glassmacs-polymode-" t))
          (file (expand-file-name ,name directory)))
     (write-region ,text nil file)
     (save-window-excursion
       (let ((base (find-file-noselect file)))
         (unwind-protect
             (progn
               (switch-to-buffer base)
               (goto-char (point-min))
               ,@body)
           (with-current-buffer base (set-buffer-modified-p nil))
           (kill-buffer base)
           (delete-directory directory t))))))

(defun glassmacs-polymode-test--go-to (text)
  "Move point to just after TEXT and select the buffer polymode uses there."
  (goto-char (point-min))
  (search-forward text)
  (pm-switch-to-buffer))

(defconst glassmacs-polymode-test--rmd
  "---\ntitle: Test\n---\n\nSome prose here.\n\n```{r setup}\nx <- 1\n```\n\nMore prose.\n\n```{r}\ny <- x + 1\n```\n")

(ert-deftest glassmacs-polymode-r-markdown-uses-poly-r ()
  (glassmacs-polymode-test--require)
  (glassmacs-polymode-test--visiting "report.Rmd" glassmacs-polymode-test--rmd
    (should polymode-mode)
    (should (derived-mode-p 'markdown-mode))
    (should glassmacs-document-mode)
    (glassmacs-polymode-test--go-to "y <- x")
    (should (derived-mode-p 'ess-r-mode))
    (should (buffer-base-buffer))
    ;; Chunk buffers get the document commands too.
    (should glassmacs-document-mode)))

(ert-deftest glassmacs-polymode-sweave-uses-poly-noweb ()
  (glassmacs-polymode-test--require)
  (glassmacs-polymode-test--visiting "paper.Rnw"
      "\\documentclass{article}\n\\begin{document}\nProse.\n<<setup>>=\nx <- 1\n@\n\\end{document}\n"
    (should polymode-mode)
    (should (derived-mode-p 'latex-mode))
    (glassmacs-polymode-test--go-to "x <- ")
    (should (derived-mode-p 'ess-r-mode))))

(ert-deftest glassmacs-polymode-target-chosen-in-a-chunk-survives-switching ()
  "polymode copies variables between its buffers on every switch; the
document's R target must not be lost or diverge."
  (glassmacs-polymode-test--require)
  (glassmacs-polymode-test--visiting "report.Rmd" glassmacs-polymode-test--rmd
    (cl-letf (((symbol-function 'glassmacs-sessions-find)
               (lambda (_id) (glassmacs-session--make :id "R-7" :state 'ready)))
              ((symbol-function 'glassmacs-sessions--process-live-p) (lambda (_) t)))
      (glassmacs-polymode-test--go-to "y <- x")
      (glassmacs-r-select-session "R-7")
      (glassmacs-polymode-test--go-to "More prose")
      (should-not (buffer-base-buffer))
      (should (equal glassmacs-r-target-session "R-7"))
      (glassmacs-polymode-test--go-to "x <- 1")
      (should (equal glassmacs-r-target-session "R-7"))
      (glassmacs-r-clear-session-target)
      (glassmacs-polymode-test--go-to "Some prose")
      (should-not glassmacs-r-target-session))))

(ert-deftest glassmacs-polymode-run-chunk-from-inside-the-chunk ()
  (glassmacs-polymode-test--require)
  (glassmacs-polymode-test--visiting "report.Rmd" glassmacs-polymode-test--rmd
    (let (submitted)
      (cl-letf (((symbol-function 'glassmacs-sessions-resolve) (lambda (&rest _) 'session))
                ((symbol-function 'glassmacs-queue-submit)
                 (lambda (source &rest _) (push source submitted))))
        (glassmacs-polymode-test--go-to "y <- x")
        (glassmacs-chunks-run-current)
        (glassmacs-polymode-test--go-to "More prose")
        (glassmacs-chunks-run-above))
      (should (equal (nreverse submitted)
                     '("y <- x + 1\n" "x <- 1\n"))))))

(ert-deftest glassmacs-polymode-typing-is-literal-in-prose-and-chunks ()
  (glassmacs-polymode-test--require)
  (glassmacs-polymode-test--visiting "report.Rmd" glassmacs-polymode-test--rmd
    (let ((prose "\"Quoted\" -- it's teh ... `r 1`")
          (code "z_value <- \"a\" # 'b' -- ..."))
      (glassmacs-polymode-test--go-to "Some prose here.")
      (execute-kbd-macro (concat " " prose))
      (glassmacs-polymode-test--go-to "x <- 1")
      (execute-kbd-macro (concat "\n" code))
      (let ((text (with-current-buffer (or (buffer-base-buffer) (current-buffer))
                    (buffer-substring-no-properties (point-min) (point-max)))))
        (should (string-search (concat "Some prose here. " prose) text))
        (should (string-search (concat "x <- 1\n" code) text))))))

(ert-deftest glassmacs-polymode-spelling-skips-chunk-code ()
  (glassmacs-polymode-test--require)
  (glassmacs-polymode-test--visiting "report.Rmd"
      "Prose teh.\n\n```{r}\nqzxv_wq <- zqxw(1)\n```\n"
    (let ((glassmacs-spelling--r-names nil))
      (goto-char (point-min))
      (search-forward "zqxw")
      (should (glassmacs-spelling-skip-word-p (match-beginning 0) (match-end 0)))
      (goto-char (point-min))
      (search-forward "teh")
      (should-not (glassmacs-spelling-skip-word-p (match-beginning 0) (match-end 0))))))

(provide 'test-glassmacs-polymode)
;;; test-glassmacs-polymode.el ends here
