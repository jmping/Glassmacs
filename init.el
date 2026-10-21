;;; init.el --- Glassmacs isolated entry point -*- lexical-binding: t; -*-

(defun glassmacs--configure-native-compilation ()
  "Disable native JIT by default, unless GLASSMACS_NATIVE_COMP is 1."
  (setq native-comp-jit-compilation
        (equal (getenv "GLASSMACS_NATIVE_COMP") "1")))

(glassmacs--configure-native-compilation)

(defvar glassmacs-root
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the Glassmacs configuration.")

(add-to-list 'load-path (expand-file-name "lisp" glassmacs-root))
(require 'glassmacs)

;;; init.el ends here
