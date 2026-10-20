;;; glassmacs-appearance.el --- Glassmacs light and dark themes -*- lexical-binding: t; -*-

(deftheme glassmacs-dark "A readable dark theme for scientific programming.")
(custom-theme-set-faces
 'glassmacs-dark
 '(default ((t (:foreground "#e6e6e6" :background "#20242b"))))
 '(cursor ((t (:background "#f0c674"))))
 '(region ((t (:background "#3e5368"))))
 '(highlight ((t (:background "#343b46"))))
 '(fringe ((t (:background "#20242b" :foreground "#7b8491"))))
 '(link ((t (:foreground "#81a2be" :underline t))))
 '(match ((t (:background "#4b5632" :foreground "#e6e6e6"))))
 '(show-paren-match ((t (:background "#46545f" :weight bold))))
 '(font-lock-builtin-face ((t (:foreground "#b294bb"))))
 '(font-lock-comment-face ((t (:foreground "#8b949e" :slant italic))))
 '(font-lock-constant-face ((t (:foreground "#de935f"))))
 '(font-lock-function-name-face ((t (:foreground "#81a2be"))))
 '(font-lock-keyword-face ((t (:foreground "#b294bb"))))
 '(font-lock-string-face ((t (:foreground "#b5bd68"))))
 '(font-lock-type-face ((t (:foreground "#8abeb7"))))
 '(font-lock-variable-name-face ((t (:foreground "#f0c674")))))
(provide-theme 'glassmacs-dark)

(deftheme glassmacs-light "A readable light theme for scientific programming.")
(custom-theme-set-faces
 'glassmacs-light
 '(default ((t (:foreground "#263238" :background "#fafafa"))))
 '(cursor ((t (:background "#ad5c00"))))
 '(region ((t (:background "#c9dff0"))))
 '(highlight ((t (:background "#e8edf2"))))
 '(fringe ((t (:background "#f3f5f7" :foreground "#65727e"))))
 '(link ((t (:foreground "#1769aa" :underline t))))
 '(match ((t (:background "#fff0a8" :foreground "#263238"))))
 '(show-paren-match ((t (:background "#d5e8da" :weight bold))))
 '(font-lock-builtin-face ((t (:foreground "#7040a0"))))
 '(font-lock-comment-face ((t (:foreground "#68737d" :slant italic))))
 '(font-lock-constant-face ((t (:foreground "#a04b00"))))
 '(font-lock-function-name-face ((t (:foreground "#075b91"))))
 '(font-lock-keyword-face ((t (:foreground "#7040a0"))))
 '(font-lock-string-face ((t (:foreground "#39733b"))))
 '(font-lock-type-face ((t (:foreground "#006b68"))))
 '(font-lock-variable-name-face ((t (:foreground "#805500")))))
(provide-theme 'glassmacs-light)

(defun glassmacs-load-theme (variant)
  "Load Glassmacs theme VARIANT, either `dark' or `light'."
  (interactive
   (list (intern (completing-read "Glassmacs theme: " '("dark" "light")
                                  nil t))))
  (let ((theme (intern (format "glassmacs-%s" variant))))
    (unless (memq theme '(glassmacs-dark glassmacs-light))
      (user-error "Unknown Glassmacs theme: %s" variant))
    (dolist (enabled custom-enabled-themes)
      (when (memq enabled '(glassmacs-dark glassmacs-light))
        (disable-theme enabled)))
    (enable-theme theme)))

(provide 'glassmacs-appearance)
;;; glassmacs-appearance.el ends here
