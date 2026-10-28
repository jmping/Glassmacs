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
(require 'glassmacs-spelling)
(require 'glassmacs-frames)
(require 'glassmacs-macos)
(require 'glassmacs-diagnostics)
(require 'glassmacs-shiny)
(require 'glassmacs-appearance)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))
;; After custom.el, so the user's environment preferences apply.
(glassmacs-environment-initialize)
(glassmacs-editing-apply)
(glassmacs--install-hybrid-bindings)

(provide 'glassmacs)
;;; glassmacs.el ends here
