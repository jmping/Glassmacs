;;; glassmacs.el --- Glassmacs configuration entry point -*- lexical-binding: t; -*-

(require 'glassmacs-core)
(require 'glassmacs-environment)
(require 'glassmacs-packages)
(require 'glassmacs-editing)
(require 'glassmacs-recovery)
(require 'glassmacs-keys)
(require 'glassmacs-r)
(require 'glassmacs-sessions)
(require 'glassmacs-r-ui)
(require 'glassmacs-remote)
(require 'glassmacs-documents)
(require 'glassmacs-latex)
(require 'glassmacs-chunks)
(require 'glassmacs-spelling)
(require 'glassmacs-workspace)
(require 'glassmacs-frames)
(require 'glassmacs-macos)
(require 'glassmacs-diagnostics)
(require 'glassmacs-shiny)
(require 'glassmacs-appearance)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
;; Glassmacs starts Emacs with -Q, so Emacs believes no init file was read
;; and refuses to save customizations ("would overwrite existing
;; customizations"): preference toggles, M-x customize and "!" for safe
;; local variables then change the session only.  Glassmacs's init.el is
;; the init file that was loaded; recording it lets every save go to
;; custom-file in the Glassmacs home.
(unless user-init-file
  (setq user-init-file
        (expand-file-name "init.el" (or (bound-and-true-p glassmacs-root)
                                        (file-name-directory
                                         (directory-file-name
                                          (file-name-directory
                                           (or load-file-name buffer-file-name))))))))
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))
;; After custom.el, so the user's environment preferences apply.
(glassmacs-environment-initialize)
(glassmacs-editing-apply)
(glassmacs--install-hybrid-bindings)
;; Last, so restored windows get the final settings and keymaps.
(glassmacs-workspace-restore-at-startup)

(provide 'glassmacs)
;;; glassmacs.el ends here
