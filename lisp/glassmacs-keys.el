;;; glassmacs-keys.el --- Optional macOS hybrid keyboard profile -*- lexical-binding: t; -*-

(defcustom glassmacs-keyboard-profile 'glassmacs-hybrid
  "Keyboard profile selected by Glassmacs."
  :type '(choice (const :tag "Disabled" nil) (const glassmacs-hybrid))
  :group 'glassmacs)

(defconst glassmacs-hybrid-keybindings
  '(([super-o] . find-file)
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

(defun glassmacs--install-hybrid-bindings (&optional frame)
  "Install the hybrid bindings only for a graphical macOS session.
FRAME is the frame being created, if called from `after-make-frame-functions'."
  (when (and (eq glassmacs-keyboard-profile 'glassmacs-hybrid)
             (eq system-type 'darwin)
             (display-graphic-p (or frame (selected-frame))))
    (dolist (binding glassmacs-hybrid-keybindings)
      (define-key global-map (car binding) (cdr binding)))))

(add-hook 'after-make-frame-functions #'glassmacs--install-hybrid-bindings)

(provide 'glassmacs-keys)
;;; glassmacs-keys.el ends here
