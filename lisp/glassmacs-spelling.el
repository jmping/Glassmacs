;;; glassmacs-spelling.el --- Check-only spell checking -*- lexical-binding: t; -*-

;; Aquamacs checked spelling with the macOS system spell checker, built into
;; its patched Emacs.  GNU Emacs has no such integration; it talks to an
;; external checker through ispell.el.  Glassmacs finds one (preferring
;; enchant-2, whose AppleSpell provider uses the macOS system dictionaries;
;; `brew install enchant'), and offers spell checking that only ever
;; reports misspellings.
;;
;; Literal text policy: spell checking never changes text by itself.  There
;; is no autocorrect, no correction while typing and no abbrev creation
;; from corrections.  A word changes only when you choose a correction
;; explicitly (from the right-click menu, `ispell-word', or flyspell's
;; C-. and C-; commands).  Checking while typing is off by default and,
;; when turned on, applies to prose modes only, never to source code.

(require 'cl-lib)
(require 'subr-x)

(defgroup glassmacs-spelling nil
  "Spell checking for Glassmacs."
  :group 'glassmacs)

(defcustom glassmacs-spelling-programs '("enchant-2" "hunspell" "aspell")
  "Spell checking programs to use, in order of preference.
enchant-2 uses the macOS system dictionaries through its AppleSpell
provider (install it with `brew install enchant')."
  :type '(repeat string)
  :group 'glassmacs-spelling)

(defun glassmacs-spelling--set-while-typing (symbol value)
  "Set SYMBOL to VALUE and apply it to open prose buffers."
  (set-default symbol value)
  (when (fboundp 'glassmacs-spelling--apply-to-buffers)
    (glassmacs-spelling--apply-to-buffers)))

(defcustom glassmacs-check-spelling-while-typing nil
  "Whether prose buffers underline misspelled words as you type.
This only highlights words; it never changes text.  It applies to
`text-mode' and modes derived from it, not to programming modes."
  :type 'boolean
  :set #'glassmacs-spelling--set-while-typing
  :group 'glassmacs-spelling)

(defvar ispell-program-name)
(defvar flyspell-mode-map)

;; Keep M-TAB as completion rather than a correction key.  Set before
;; flyspell.el loads, because flyspell builds its keymap from this value.
(unless (boundp 'flyspell-use-meta-tab)
  (defvar flyspell-use-meta-tab)
  (setq flyspell-use-meta-tab nil))
;; Never turn a correction into an abbrev, which would later rewrite text
;; automatically when `abbrev-mode' is on.
(unless (boundp 'flyspell-abbrev-p)
  (defvar flyspell-abbrev-p)
  (setq flyspell-abbrev-p nil))

(with-eval-after-load 'flyspell
  (unless (get 'flyspell-use-meta-tab 'saved-value)
    (define-key flyspell-mode-map (kbd "M-TAB") nil)))

(defun glassmacs-spelling-program ()
  "Return the full name of the first available spell checking program."
  (cl-some #'executable-find glassmacs-spelling-programs))

(defun glassmacs-spelling-configure ()
  "Use the preferred available checker unless the user chose one.
Return the program, or nil when none is installed."
  (let ((program (glassmacs-spelling-program)))
    (when (and program
               (not (get 'ispell-program-name 'saved-value))
               (not (get 'ispell-program-name 'customized-value)))
      (require 'ispell)
      (setq ispell-program-name program))
    program))

(defun glassmacs-spelling--maybe-enable ()
  "Turn on check-only spell checking in this prose buffer when enabled."
  (when (and glassmacs-check-spelling-while-typing
             (derived-mode-p 'text-mode)
             (glassmacs-spelling-program))
    (flyspell-mode 1)))

(add-hook 'text-mode-hook #'glassmacs-spelling--maybe-enable)

(defun glassmacs-spelling--apply-to-buffers ()
  "Apply `glassmacs-check-spelling-while-typing' to open prose buffers."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'text-mode)
        (if glassmacs-check-spelling-while-typing
            (glassmacs-spelling--maybe-enable)
          (when (bound-and-true-p flyspell-mode)
            (flyspell-mode -1)))))))

(defun glassmacs-spelling--require-program ()
  "Return the configured checker or explain how to install one."
  (or (glassmacs-spelling-configure)
      (user-error "No spell checker found; install one with `brew install enchant' (uses the macOS dictionaries) or `brew install hunspell'")))

(defun glassmacs-toggle-spell-checking ()
  "Toggle and persist checking spelling while typing in prose buffers."
  (interactive)
  (unless glassmacs-check-spelling-while-typing
    (glassmacs-spelling--require-program))
  (customize-save-variable 'glassmacs-check-spelling-while-typing
                           (not glassmacs-check-spelling-while-typing))
  (message "Check spelling while typing: %s"
           (if glassmacs-check-spelling-while-typing "on" "off")))

(defun glassmacs-check-spelling ()
  "Check the spelling of the region or the whole document interactively.
Each misspelled word is shown with suggestions; nothing changes unless
you pick a replacement."
  (interactive)
  (glassmacs-spelling--require-program)
  (require 'ispell)
  (when glassmacs-spelling-skip-r-names
    (glassmacs-spelling-refresh-r-names t))
  (let* ((start (if (use-region-p) (region-beginning) (point-min)))
         (end (if (use-region-p) (region-end) (point-max)))
         ;; Session-only: ispell accepts these words for this check and
         ;; nothing is written to the document or a dictionary.
         (ispell-buffer-session-localwords
          (append (glassmacs-spelling--skipped-words start end)
                  ispell-buffer-session-localwords)))
    (ispell-region start end)))

;;; Words that are not prose
;;
;; Code, identifiers and the names of loaded R objects and functions are
;; not misspellings.  They are skipped by checking, never added to a file:
;; flyspell asks a buffer-local predicate before checking each word, which
;; Glassmacs chains after the mode's own predicate (which already skips,
;; for example, Markdown code), and an explicit document check passes the
;; skipped words to ispell as session-only accepted words.

(defcustom glassmacs-spelling-skip-code t
  "Whether spell checking skips code.
Skips R chunks and inline R code in R Markdown, Quarto and Sweave
documents, words shown in a code face (`glassmacs-spelling-code-faces') and
identifier-shaped words: containing an underscore, a dot or a digit, or a
lowercase letter followed by a capital (my_data, data.frame, ggplot2,
readRDS)."
  :type 'boolean
  :group 'glassmacs-spelling)

(defcustom glassmacs-spelling-code-faces
  '(markdown-code-face markdown-inline-code-face markdown-pre-face
    font-latex-math-face font-latex-verbatim-face)
  "Faces marking code or math, whose words spell checking skips."
  :type '(repeat face)
  :group 'glassmacs-spelling)

(defcustom glassmacs-spelling-skip-r-names t
  "Whether spell checking skips the names of loaded R objects and functions.
The names come from the buffer's R session: its explicit target, or the
only live session.  Glassmacs reads them with a hidden ls() over the
workspace and attached packages, only while R is idle (it never waits
for, queues behind or interrupts your work), when spell checking starts
in a buffer or a document check begins, and on
\[glassmacs-spelling-refresh-r-names].  While R is busy the previous
list is kept."
  :type 'boolean
  :group 'glassmacs-spelling)

(defcustom glassmacs-spelling-skip-emacs-symbols nil
  "Whether spell checking skips names of loaded Emacs functions and variables.
Off by default: ordinary words such as \"list\" and \"message\" are also
Emacs function names, so this mainly helps when writing about Emacs."
  :type 'boolean
  :group 'glassmacs-spelling)

(defvar glassmacs-r-target-session)
(declare-function glassmacs-sessions-live "glassmacs-sessions" ())
(declare-function glassmacs-sessions-find "glassmacs-sessions" (id-or-process))
(declare-function glassmacs-session-process "glassmacs-sessions" (session))
(declare-function ess-get-words-from-vector "ess-inf"
                  (command &optional no-prompt-check wait proc timeout))
(declare-function flyspell-get-word "flyspell" (&optional following extra-otherchars))
(defvar flyspell-generic-check-word-predicate)
(defvar ispell-buffer-session-localwords)

(defvar glassmacs-spelling--r-names nil
  "Hash table of R names read from a session, or nil before the first read.")

(defconst glassmacs-spelling--r-names-command
  (concat "local({ out <- try({ envs <- c(list(globalenv()), "
          "lapply(search()[-1], as.environment)); "
          "unique(unlist(lapply(envs, function(e) tryCatch(ls(e, all.names = TRUE), "
          "error = function(c) character())))) }, silent = TRUE); "
          "if (inherits(out, \"try-error\")) out <- character(); "
          "print(out, max = 1e6) })\n")
  "R code listing workspace objects and attached packages' names.
It only reads; `print' with a large max avoids truncating long lists.")

(defun glassmacs-spelling--r-session ()
  "Return this buffer's R session without prompting, or nil.
That is its explicit target when live, otherwise the only live session."
  (when (fboundp 'glassmacs-sessions-live)
    (let ((live (glassmacs-sessions-live)))
      (if (bound-and-true-p glassmacs-r-target-session)
          (car (memq (glassmacs-sessions-find glassmacs-r-target-session) live))
        (and live (null (cdr live)) (car live))))))

(defun glassmacs-spelling-refresh-r-names (&optional quiet)
  "Read the loaded R object and function names spell checking skips.
Only reads when the buffer's R session is idle.  With QUIET, report
nothing.  Return the number of names, or nil when nothing was read."
  (interactive)
  (let* ((session (glassmacs-spelling--r-session))
         (process (and session (glassmacs-session-process session))))
    (cond
     ((not (and process (process-live-p process)
                (fboundp 'ess-get-words-from-vector)))
      (unless quiet (message "No R session to read names from"))
      nil)
     ((process-get process 'busy)
      (unless quiet (message "R is busy; keeping the previous names"))
      nil)
     (t
      (let ((names (ess-get-words-from-vector
                    glassmacs-spelling--r-names-command nil nil process 10))
            (table (make-hash-table :test #'equal)))
        (dolist (name names)
          (puthash name t table))
        (setq glassmacs-spelling--r-names table)
        (unless quiet
          (message "Spell checking skips %d R names" (hash-table-count table)))
        (hash-table-count table))))))

(defun glassmacs-spelling--identifier (start end characters)
  "Return the run of CHARACTERS around the word from START to END.
Trailing dots are dropped, so a sentence's final period is not part of it."
  (save-excursion
    (let ((from (progn (goto-char start) (skip-chars-backward characters) (point)))
          (to (progn (goto-char end) (skip-chars-forward characters) (point))))
      (string-trim-right (buffer-substring-no-properties from to) "\\.+"))))

(defun glassmacs-spelling--code-face-p (position)
  "Return non-nil when POSITION has one of `glassmacs-spelling-code-faces'."
  (let ((face (get-text-property position 'face)))
    (cl-some (lambda (f) (memq f glassmacs-spelling-code-faces))
             (if (listp face) face (list face)))))

(defun glassmacs-spelling--code-like-p (identifier)
  "Return non-nil when IDENTIFIER looks like code rather than a word."
  (let ((case-fold-search nil))
    (string-match-p "[_.0-9]\\|[[:lower:]][[:upper:]]" identifier)))

(defun glassmacs-spelling-skip-word-p (start end)
  "Return non-nil when the word from START to END is not prose to check."
  (let ((word (buffer-substring-no-properties start end))
        (identifier (glassmacs-spelling--identifier start end "[:alnum:]_.")))
    (or (and glassmacs-spelling-skip-code
             (or (glassmacs-spelling--code-face-p start)
                 ;; R chunks and inline R code in R Markdown, Quarto, Sweave.
                 (and (fboundp 'glassmacs-chunks-code-position-p)
                      (glassmacs-chunks-code-position-p start))
                 (glassmacs-spelling--code-like-p identifier)))
        (and glassmacs-spelling-skip-r-names
             glassmacs-spelling--r-names
             (or (gethash identifier glassmacs-spelling--r-names)
                 (gethash word glassmacs-spelling--r-names)))
        (and glassmacs-spelling-skip-emacs-symbols
             (let ((symbol (intern-soft
                            (glassmacs-spelling--identifier start end "[:alnum:]_.-"))))
               (and symbol (or (fboundp symbol) (boundp symbol))))))))

(defvar-local glassmacs-spelling--mode-predicate nil
  "The mode's own flyspell word predicate, called before Glassmacs's.")

(defun glassmacs-spelling--flyspell-predicate ()
  "Check the word at point only if the mode and Glassmacs both allow it."
  (and (or (not (functionp glassmacs-spelling--mode-predicate))
           (funcall glassmacs-spelling--mode-predicate))
       (let ((word (save-excursion (flyspell-get-word))))
         (not (and word
                   (glassmacs-spelling-skip-word-p (nth 1 word) (nth 2 word)))))))

(defun glassmacs-spelling--install-predicate ()
  "Chain Glassmacs's word filter after the mode's flyspell predicate."
  (when (and (bound-and-true-p flyspell-mode)
             (not (eq flyspell-generic-check-word-predicate
                      #'glassmacs-spelling--flyspell-predicate)))
    (setq glassmacs-spelling--mode-predicate flyspell-generic-check-word-predicate)
    (setq flyspell-generic-check-word-predicate
          #'glassmacs-spelling--flyspell-predicate)
    (when glassmacs-spelling-skip-r-names
      (glassmacs-spelling-refresh-r-names t))))

(add-hook 'flyspell-mode-hook #'glassmacs-spelling--install-predicate)

(defun glassmacs-spelling--skipped-words (start end)
  "Return the distinct words from START to END that checking should skip."
  (let ((case-fold-search nil) words)
    (save-excursion
      (goto-char start)
      (while (re-search-forward "[[:alpha:]]+" end t)
        (let ((word (match-string-no-properties 0)))
          (when (and (not (member word words))
                     (glassmacs-spelling-skip-word-p (match-beginning 0)
                                                     (match-end 0)))
            (push word words)))))
    words))

(glassmacs-spelling-configure)

(provide 'glassmacs-spelling)
;;; glassmacs-spelling.el ends here
