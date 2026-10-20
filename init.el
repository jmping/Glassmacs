;;; init.el --- Glassmacs isolated entry point -*- lexical-binding: t; -*-

(defvar glassmacs-root
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the Glassmacs configuration.")

(add-to-list 'load-path (expand-file-name "lisp" glassmacs-root))
(require 'glassmacs)

;;; init.el ends here
