;;; glassmacs-editing.el --- Mac editing defaults -*- lexical-binding: t; -*-

;; Editing behavior Mac users expect and that Aquamacs enabled by default,
;; built from standard GNU Emacs facilities.  Each behavior has its own
;; option in the `glassmacs-editing' group and can be turned off.
;;
;; Literal text policy: nothing here changes what you type.  Glassmacs
;; enables no automatic correction, smart quotes or punctuation, text
;; substitution or Aquamacs-style "smart word spacing" in any context
;; (programming, markup, mixed prose/code documents such as R Markdown,
;; consoles or the minibuffer).  Any such transformation must be an
;; explicit opt-in and must never apply to source code; the
;; `glassmacs-editing-literal-text-entry' test guards this.
;;
;; Soft wrap only changes how long lines are displayed, typing over a
;; selection inserts exactly the typed characters, and the right Option
;; key setting lets macOS deliver characters such as é literally.

(defgroup glassmacs-editing nil
  "Mac editing defaults for Glassmacs."
  :group 'glassmacs)

(defun glassmacs-editing--set-and-apply (symbol value)
  "Set SYMBOL to VALUE and reapply the editing defaults."
  (set-default symbol value)
  (when (fboundp 'glassmacs-editing-apply)
    (glassmacs-editing-apply)))

(defcustom glassmacs-typing-replaces-selection t
  "Whether typed text replaces the selected text, as in Mac applications.
This enables `delete-selection-mode'.  The typed characters are
inserted literally."
  :type 'boolean
  :set #'glassmacs-editing--set-and-apply
  :group 'glassmacs-editing)

(defcustom glassmacs-right-option-types-characters t
  "Whether the right Option key types special characters instead of Meta.
When non-nil, the left Option key stays Meta for Emacs commands and the
right Option key works as in other Mac applications, so characters such
as é, ü, € or (on many keyboard layouts) @ can be typed.  Applies to the
Cocoa build only."
  :type 'boolean
  :set #'glassmacs-editing--set-and-apply
  :group 'glassmacs-editing)

(defcustom glassmacs-soft-wrap-text t
  "Whether prose buffers wrap long lines on screen at word boundaries.
This enables `visual-line-mode' in `text-mode' and modes derived from it
(Markdown, R Markdown, Quarto, LaTeX).  It changes only the display; no
newlines are inserted into the file."
  :type 'boolean
  :set #'glassmacs-editing--set-and-apply
  :group 'glassmacs-editing)

(defcustom glassmacs-remember-positions t
  "Whether files reopen at the position where they were last edited.
This enables `save-place-mode' and `savehist-mode' (minibuffer history),
both stored in the Glassmacs home."
  :type 'boolean
  :set #'glassmacs-editing--set-and-apply
  :group 'glassmacs-editing)

(defcustom glassmacs-keep-backups-in-home t
  "Whether backup files are kept in the Glassmacs home.
Emacs normally writes FILE~ next to each file it saves, which clutters
project folders and Git working trees.  When non-nil, local backups go to
\"backups\" in the Glassmacs home instead; backups of remote (TRAMP)
files stay on the remote host beside the file.  Backups are still made,
unlike Aquamacs, which turned them off."
  :type 'boolean
  :set #'glassmacs-editing--set-and-apply
  :group 'glassmacs-editing)

(defcustom glassmacs-smooth-scrolling t
  "Whether trackpads and scroll wheels scroll by pixels instead of lines.
This enables `pixel-scroll-precision-mode' in graphical sessions."
  :type 'boolean
  :set #'glassmacs-editing--set-and-apply
  :group 'glassmacs-editing)

(defvar ns-right-alternate-modifier)
(defvar glassmacs-home)

(defconst glassmacs-editing--remote-file-regexp "\\`/[^/:|]+:"
  "Matches TRAMP file names such as /ssh:host:/path.")

(defvar glassmacs-editing--managed-backup-alist nil
  "The `backup-directory-alist' value Glassmacs installed, if any.")

(defun glassmacs-editing--backup-alist ()
  "Return the backup directory alist used when backups stay in the home."
  ;; A nil directory means \"beside the original\", so remote files are
  ;; backed up on their own host rather than copied to this Mac.
  `((,glassmacs-editing--remote-file-regexp . nil)
    ("." . ,(file-name-as-directory
             (expand-file-name "backups" glassmacs-home)))))

(defun glassmacs-editing--apply-backups ()
  "Install or remove Glassmacs's backup directory policy.
A `backup-directory-alist' set by the user is never replaced."
  (let ((managed (and backup-directory-alist
                      (equal backup-directory-alist
                             glassmacs-editing--managed-backup-alist))))
    (cond
     ((and glassmacs-keep-backups-in-home
           (or (null backup-directory-alist) managed))
      (setq backup-directory-alist (glassmacs-editing--backup-alist)
            glassmacs-editing--managed-backup-alist backup-directory-alist))
     ((and (not glassmacs-keep-backups-in-home) managed)
      (setq backup-directory-alist nil
            glassmacs-editing--managed-backup-alist nil)))))

(defun glassmacs-editing--enable (mode enable)
  "Turn global minor MODE on when ENABLE is non-nil, otherwise off."
  (when (fboundp mode)
    (funcall mode (if enable 1 -1))))

(defun glassmacs-editing-apply ()
  "Apply the Glassmacs editing options to the running session."
  (glassmacs-editing--enable 'delete-selection-mode
                             glassmacs-typing-replaces-selection)
  (when (eq system-type 'darwin)
    (setq ns-right-alternate-modifier
          (if glassmacs-right-option-types-characters 'none 'left)))
  (if glassmacs-soft-wrap-text
      (add-hook 'text-mode-hook #'visual-line-mode)
    (remove-hook 'text-mode-hook #'visual-line-mode))
  (when glassmacs-remember-positions
    (require 'saveplace)
    (require 'savehist))
  (glassmacs-editing--enable 'save-place-mode glassmacs-remember-positions)
  (glassmacs-editing--enable 'savehist-mode glassmacs-remember-positions)
  (glassmacs-editing--apply-backups)
  (when (display-graphic-p)
    (glassmacs-editing--enable 'pixel-scroll-precision-mode
                               glassmacs-smooth-scrolling)))

(defun glassmacs-toggle-right-option-types-characters ()
  "Toggle and persist whether the right Option key types characters."
  (interactive)
  (customize-save-variable 'glassmacs-right-option-types-characters
                           (not glassmacs-right-option-types-characters))
  (message "Right Option key: %s"
           (if glassmacs-right-option-types-characters
               "types special characters"
             "Meta, like the left Option key")))

(defun glassmacs-kill-to-line-start ()
  "Kill the text from the start of the line to point (Command-Delete)."
  (interactive)
  (kill-line 0))

(provide 'glassmacs-editing)
;;; glassmacs-editing.el ends here
