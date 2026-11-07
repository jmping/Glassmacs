;;; glassmacs-presentation-model.el --- Read-only presentation roles -*- lexical-binding: t; -*-

;; This module deliberately has no startup hooks, window mutations, or advice.
;; It classifies buffers; it does not assign ownership of frames or processes.

(require 'cl-lib)

(defun glassmacs-presentation-buffer-role (buffer)
  "Return the presentation role of live BUFFER, or nil if it is dead.
Roles are `document', `r-source', `r-console', `r-help',
`preferences', `utility', and `internal'.  Classification is
read-only and does not infer that any existing view is suitable.
An indirect buffer inherits its base document's role unless it is
itself an R source chunk."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (let* ((name (buffer-name))
             (base (buffer-base-buffer))
             (base-file (and base (buffer-file-name base))))
        (cond
         ((derived-mode-p 'inferior-ess-r-mode) 'r-console)
         ((and (boundp 'ess-help-mode) ess-help-mode) 'r-help)
         ((or (derived-mode-p 'ess-help-mode)
              (string-match-p "\\*help\\[R\\]\\|\\*R Help\\|\\*help\\[R" name))
          'r-help)
         ((or (derived-mode-p 'ess-r-mode 'R-mode)
              (and (or buffer-file-name base-file)
                   (string-match-p "\\.[Rr]\\'" (or buffer-file-name base-file))))
          'r-source)
         ((or (derived-mode-p 'Custom-mode)
              (string-match-p "\\*Customize\\|\\*Glassmacs Preferences" name))
          'preferences)
         ((or buffer-file-name base-file) 'document)
         ((string-prefix-p " " name) 'internal)
         ((string-prefix-p "*" name) 'utility)
         (t 'document))))))

(provide 'glassmacs-presentation-model)
;;; glassmacs-presentation-model.el ends here
