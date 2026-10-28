;;; glassmacs-diagnostics.el --- Local Glassmacs diagnostics -*- lexical-binding: t; -*-

(defun glassmacs-diagnostics ()
  "Display local startup and optional R/ESS availability information."
  (interactive)
  (let ((buffer (get-buffer-create "*Glassmacs Diagnostics*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert
         (format "Glassmacs diagnostics\n\nEmacs: %s\nOperating system: %s\nWindow system: %s\nGlassmacs home: %s\n\n"
                 emacs-version system-type
                 (if (display-graphic-p) (or window-system "graphical") "terminal")
                 glassmacs-home)
         (format "Shell environment: %s\n"
                 (if (boundp 'glassmacs-environment-status)
                     glassmacs-environment-status
                   "unknown"))
         (format "ESS: %s\nR: %s\nRscript: %s\n\n"
                 (if (locate-library "ess-site") "available" "not found")
                 (if (executable-find "R") "available" "not found")
                 (if (executable-find "Rscript") "available" "not found"))
         "Graphics guidance:\n"
         (if (and (eq system-type 'darwin) (display-graphic-p))
             (concat
              "In an ESS session, evaluate plot(cars) to check the R build's native macOS graphics device. "
              "If available, try ggplot2 separately. Use X11() only when XQuartz and its display are explicitly configured; Glassmacs does not select it automatically.\n")
           (concat
            "Graphics-device behavior depends on the R installation and display. "
            "A native macOS GUI graphics check requires graphical macOS Emacs and an ESS R session; X11 is optional and must be configured explicitly.\n"))
         "\nThis report is local. It does not include environment variables, credentials, process output, or project contents.\n")
        (special-mode)))
    (display-buffer buffer)))

(provide 'glassmacs-diagnostics)
;;; glassmacs-diagnostics.el ends here
