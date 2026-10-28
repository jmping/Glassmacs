;;; glassmacs-latex.el --- LaTeX and Sweave PDF preview -*- lexical-binding: t; -*-

;; Aquamacs configured AUCTeX for the Mac (auctex-config.el): PDF output,
;; SyncTeX, and Skim as the viewer, so that C-c C-v jumps from the source
;; to the PDF and Command-Shift-click in Skim jumps back.  This module does
;; the same for an installed AUCTeX, and adds a knit-to-PDF command for
;; Sweave/knitr documents.  It configures AUCTeX only after AUCTeX loads,
;; and never replaces a value the user has customized.
;;
;; Literal text policy: AUCTeX binds \" to `TeX-insert-quote', which turns
;; it into `` or '', and with babel German-style hyphenation turns - into
;; \"=.  These are automatic substitutions in markup, so Glassmacs makes
;; \" insert a literal \" (unless `glassmacs-latex-smart-quotes' is set) and
;; keeps AUCTeX's electric insertion options off.  TeX's MacTeX binaries
;; are found through the shell environment import (glassmacs-environment).

(require 'glassmacs-core)
(require 'glassmacs-documents)

(defgroup glassmacs-latex nil
  "LaTeX and Sweave PDF workflows for Glassmacs."
  :group 'glassmacs)

(defcustom glassmacs-latex-smart-quotes nil
  "Whether \" in TeX buffers inserts typographic quotes (`` and '').
Off by default: Glassmacs inserts exactly the characters you type.  Set
this to opt in to AUCTeX's `TeX-insert-quote'."
  :type 'boolean
  :group 'glassmacs-latex)

(defcustom glassmacs-latex-pdf-viewer 'auto
  "PDF viewer for LaTeX output.
`auto' uses Skim when it is installed (it supports SyncTeX forward and
inverse search) and Preview otherwise.  `skim' and `preview' force one."
  :type '(choice (const :tag "Skim if installed, else Preview" auto)
                 (const :tag "Skim" skim)
                 (const :tag "Preview" preview))
  :group 'glassmacs-latex)

(defconst glassmacs-latex-skim-displayline
  "/Applications/Skim.app/Contents/SharedSupport/displayline"
  "Skim's command-line tool for showing a PDF at a source line.")

(defconst glassmacs-latex--viewers
  `(("Glassmacs Skim" ,(concat glassmacs-latex-skim-displayline " -b %n %o %b"))
    ("Glassmacs Preview" "open -a Preview %o"))
  "AUCTeX `TeX-view-program-list' entries added by Glassmacs.
For Skim, -b shows the reading bar at the line, %n is the source line,
%o the PDF and %b the source file.")

(defconst glassmacs-latex--literal-defaults
  '((TeX-electric-math nil)
    (TeX-electric-sub-and-superscript nil)
    (TeX-electric-escape nil)
    (TeX-refuse-unmatched-dollar nil)
    (LaTeX-electric-left-right-brace nil)
    (LaTeX-babel-hyphen ""))
  "AUCTeX options that keep typed text literal, with their values.")

(defvar TeX-mode-map)
(defvar TeX-view-program-list)
(defvar TeX-view-program-selection)
(defvar TeX-source-correlate-mode)
(declare-function TeX-insert-quote "tex" (force))
(declare-function TeX-source-correlate-mode "tex" (&optional arg))

(defun glassmacs-latex--user-set-p (symbol)
  "Return non-nil when the user has customized SYMBOL."
  (or (get symbol 'saved-value) (get symbol 'customized-value)))

(defun glassmacs-latex--default (symbol value)
  "Set SYMBOL to VALUE if it is defined and not customized by the user."
  (when (and (boundp symbol) (not (glassmacs-latex--user-set-p symbol)))
    (set-default symbol value)))

(defun glassmacs-latex--viewer-name ()
  "Return the `TeX-view-program-list' name of the PDF viewer to use."
  (if (and (memq glassmacs-latex-pdf-viewer '(auto skim))
           (or (eq glassmacs-latex-pdf-viewer 'skim)
               (file-executable-p glassmacs-latex-skim-displayline)))
      "Glassmacs Skim"
    "Glassmacs Preview"))

(defun glassmacs-latex-configure ()
  "Configure a loaded AUCTeX for PDF output, SyncTeX and literal typing.
Safe to call repeatedly; settings the user customized are kept."
  ;; Typed text stays literal.
  (dolist (entry glassmacs-latex--literal-defaults)
    (glassmacs-latex--default (car entry) (cadr entry)))
  ;; Replace only AUCTeX's stock binding, so a user's own binding survives.
  (when (and (boundp 'TeX-mode-map)
             (memq (lookup-key TeX-mode-map "\"")
                   '(TeX-insert-quote self-insert-command)))
    (define-key TeX-mode-map "\""
      (if glassmacs-latex-smart-quotes #'TeX-insert-quote #'self-insert-command)))
  ;; PDF output with SyncTeX source correlation.
  (glassmacs-latex--default 'TeX-PDF-mode t)
  (glassmacs-latex--default 'TeX-source-correlate-start-server t)
  (when (and (fboundp 'TeX-source-correlate-mode)
             (not (glassmacs-latex--user-set-p 'TeX-source-correlate-mode)))
    (TeX-source-correlate-mode 1))
  ;; Viewer, only on macOS, where Preview and Skim exist.
  (when (and (eq system-type 'darwin) (boundp 'TeX-view-program-list))
    (dolist (viewer glassmacs-latex--viewers)
      (unless (assoc (car viewer) TeX-view-program-list)
        (push viewer TeX-view-program-list)))
    (unless (glassmacs-latex--user-set-p 'TeX-view-program-selection)
      (setf (alist-get 'output-pdf TeX-view-program-selection)
            (list (glassmacs-latex--viewer-name))))))

(with-eval-after-load 'tex (glassmacs-latex-configure))
(with-eval-after-load 'latex (glassmacs-latex-configure))

(defun glassmacs-latex-open-pdf (pdf)
  "Show PDF in the configured viewer without waiting for it."
  (unless (file-readable-p pdf)
    (user-error "No PDF was produced: %s" pdf))
  (if (eq system-type 'darwin)
      (call-process "open" nil 0 nil "-a"
                    (if (equal (glassmacs-latex--viewer-name) "Glassmacs Skim")
                        "Skim" "Preview")
                    pdf)
    (find-file-other-window pdf)))

(defun glassmacs-knit-sweave-pdf ()
  "Knit the current Sweave/knitr document to PDF and show it.
Runs knitr::knit2pdf() with Rscript in the document's directory, without
blocking Emacs, then opens the PDF.  SyncTeX positions refer to the
generated .tex file, not the .Rnw source."
  (interactive)
  (let* ((file (glassmacs--current-file))
         (pdf (concat (file-name-sans-extension file) ".pdf")))
    (glassmacs-run-process
     "Rscript"
     (list "-e" (format "knitr::knit2pdf(%s)" (glassmacs-r-quote file)))
     (file-name-directory file)
     (lambda () (glassmacs-latex-open-pdf pdf)))))

(provide 'glassmacs-latex)
;;; glassmacs-latex.el ends here
