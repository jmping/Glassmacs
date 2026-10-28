;;; glassmacs-keys.el --- macOS keyboard profiles -*- lexical-binding: t; -*-

(defun glassmacs--set-keyboard-profile (symbol value)
  "Set keyboard profile SYMBOL to VALUE and apply the new bindings."
  (set-default symbol value)
  (when (fboundp 'glassmacs--install-hybrid-bindings)
    (glassmacs--install-hybrid-bindings)))

(defcustom glassmacs-keyboard-profile 'glassmacs-hybrid
  "Keyboard profile selected by Glassmacs on graphical macOS frames."
  :type '(choice (const :tag "Hybrid macOS / Emacs" glassmacs-hybrid)
                 (const :tag "Traditional Emacs" traditional-emacs)
                 (const :tag "Disabled" nil))
  :set #'glassmacs--set-keyboard-profile
  :group 'glassmacs)

(defconst glassmacs-hybrid-keybindings
  '(([?\s-o] . glassmacs-open-file)
    ([?\s-n] . glassmacs-new-document)
    ([?\s-s] . save-buffer)
    ([?\s-S] . write-file)
    ([?\s-w] . delete-frame)
    ([?\s-q] . glassmacs-recovery-quit)
    ([?\s-c] . kill-ring-save)
    ([?\s-v] . yank)
    ([?\s-x] . kill-region)
    ([?\s-a] . mark-whole-buffer)
    ([?\s-z] . undo)
    ([?\s-Z] . undo-redo)
    ([?\s-f] . isearch-forward))
  "Command-key bindings for the `glassmacs-hybrid' profile.
Control and Meta bindings, including C-x, C-c, and M-x, are untouched.
Cocoa delivers Command chords as integer events (`?\\s-n'), so they must
not be written as `super-n' symbols, which never match a keypress.")

(defvar glassmacs--saved-hybrid-keybindings nil
  "Bindings replaced while the Hybrid keyboard profile is active.")

(defun glassmacs--restore-hybrid-bindings ()
  "Restore bindings replaced by the Hybrid keyboard profile."
  (when glassmacs--saved-hybrid-keybindings
    (dolist (saved glassmacs--saved-hybrid-keybindings)
      (let ((key (car saved))
            (original (cdr saved)))
        (when (eq (lookup-key global-map key)
                  (alist-get key glassmacs-hybrid-keybindings nil nil #'equal))
          (define-key global-map key original))))
    (setq glassmacs--saved-hybrid-keybindings nil)))

(defun glassmacs--install-hybrid-bindings (&optional frame)
  "Apply the selected keyboard profile for a graphical macOS session.
FRAME is the frame being created, if called from `after-make-frame-functions'."
  (if (and (eq glassmacs-keyboard-profile 'glassmacs-hybrid)
           (eq system-type 'darwin)
           (display-graphic-p (or frame (selected-frame))))
      (unless glassmacs--saved-hybrid-keybindings
        (setq glassmacs--saved-hybrid-keybindings
              (mapcar (lambda (binding)
                        (cons (car binding)
                              (lookup-key global-map (car binding))))
                      glassmacs-hybrid-keybindings))
        (dolist (binding glassmacs-hybrid-keybindings)
          (define-key global-map (car binding) (cdr binding))))
    (glassmacs--restore-hybrid-bindings)))

(defun glassmacs-set-keyboard-profile (profile)
  "Set and persist keyboard PROFILE.
PROFILE must be `glassmacs-hybrid', `traditional-emacs', or nil."
  (interactive
   (list
    (intern
     (completing-read
      "Keyboard profile: "
      '("glassmacs-hybrid" "traditional-emacs" "nil")
      nil t nil nil
      (if glassmacs-keyboard-profile
          (symbol-name glassmacs-keyboard-profile)
        "nil")))))
  (unless (memq profile '(glassmacs-hybrid traditional-emacs nil))
    (user-error "Unknown Glassmacs keyboard profile: %s" profile))
  (setq glassmacs-keyboard-profile profile)
  (glassmacs--install-hybrid-bindings)
  (let ((user-init-file (or user-init-file custom-file)))
    (customize-save-variable 'glassmacs-keyboard-profile profile))
  (message "Glassmacs keyboard profile: %s"
           (or profile "disabled")))

(defun glassmacs-select-hybrid-keyboard-profile ()
  "Select and persist the Hybrid macOS / Emacs keyboard profile."
  (interactive)
  (glassmacs-set-keyboard-profile 'glassmacs-hybrid))

(defun glassmacs-select-traditional-keyboard-profile ()
  "Select and persist the Traditional Emacs keyboard profile."
  (interactive)
  (glassmacs-set-keyboard-profile 'traditional-emacs))

;; The bindings live in `global-map', so installing them once per new frame
;; is sufficient; Emacs has no per-frame-selection hook to add here.
(add-hook 'after-make-frame-functions #'glassmacs--install-hybrid-bindings)

(provide 'glassmacs-keys)
;;; glassmacs-keys.el ends here
