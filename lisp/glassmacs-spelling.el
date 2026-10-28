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
  (if (use-region-p)
      (ispell-region (region-beginning) (region-end))
    (ispell-buffer)))

(glassmacs-spelling-configure)

(provide 'glassmacs-spelling)
;;; glassmacs-spelling.el ends here
