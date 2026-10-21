;;; init.el --- Glassmacs isolated entry point -*- lexical-binding: t; -*-

(defun glassmacs--configure-native-compilation ()
  "Restrict native code to the Emacs bundle and disable runtime compilation."
  (when (boundp 'native-comp-jit-compilation)
    (setq native-comp-jit-compilation nil))
  (when (boundp 'native-comp-enable-subr-trampolines)
    (setq native-comp-enable-subr-trampolines nil))
  (when (boundp 'native-comp-eln-load-path)
    (setq native-comp-eln-load-path
          (let* ((contents (expand-file-name "../../" data-directory))
                 (native-lisp
                  (expand-file-name "Frameworks/native-lisp/" contents)))
            (if (and (eq system-type 'darwin)
                     (file-readable-p (expand-file-name "Info.plist" contents))
                     (file-directory-p native-lisp))
                (list (file-name-as-directory
                       (file-truename native-lisp)))
              nil)))))

(glassmacs--configure-native-compilation)

(defvar glassmacs-root
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the Glassmacs configuration.")

(add-to-list 'load-path (expand-file-name "lisp" glassmacs-root))
(require 'glassmacs)

;;; init.el ends here
