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
  '(([super-o] . glassmacs-open-file)
    ([super-n] . glassmacs-new-document)
    ([super-s] . save-buffer)
    ([super-S] . write-file)
    ([super-w] . delete-frame)
    ([super-q] . save-buffers-kill-emacs)
    ([super-c] . kill-ring-save)
    ([super-v] . yank)
    ([super-x] . kill-region)
    ([super-a] . mark-whole-buffer)
    ([super-z] . undo)
    ([super-f] . isearch-forward))
  "Command-key bindings for the `glassmacs-hybrid' profile.
Control and Meta bindings, including C-x, C-c, and M-x, are untouched.")

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

(add-hook 'after-make-frame-functions #'glassmacs--install-hybrid-bindings)
(add-hook 'select-frame-functions #'glassmacs--install-hybrid-bindings)

(provide 'glassmacs-keys)
;;; glassmacs-keys.el ends here
