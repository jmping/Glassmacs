;;; glassmacs.el --- Glassmacs configuration entry point -*- lexical-binding: t; -*-

(require 'glassmacs-core)
(require 'glassmacs-keys)
(require 'glassmacs-r)
(require 'glassmacs-sessions)
(require 'glassmacs-r-ui)
(require 'glassmacs-remote)
(require 'glassmacs-documents)
(require 'glassmacs-frames)
(require 'glassmacs-diagnostics)
(require 'glassmacs-shiny)
(require 'glassmacs-appearance)

(defvar server-name)
(defvar server-socket-dir)
(declare-function server-running-p "server" (&optional name))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))
(when (equal (getenv "GLASSMACS_LAUNCHER_SERVER") "1")
  (require 'server)
  (setq server-name "glassmacs")
  (setq server-socket-dir (expand-file-name "server-sockets" glassmacs-home))
  (unless (server-running-p)
    (server-start)))
(glassmacs--install-hybrid-bindings)

(provide 'glassmacs)
;;; glassmacs.el ends here
