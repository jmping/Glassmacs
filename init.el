;;; init.el --- Glassmacs isolated entry point -*- lexical-binding: t; -*-

(defun glassmacs--configure-native-compilation ()
  "Restrict native code to trusted directories and disable runtime compilation.
Inside the macOS app bundle only the bundle's own native-lisp directory is
used.  Elsewhere (a source checkout run with another Emacs), keep only the
existing directories the user cannot write, such as a distribution's
system native-lisp directory: built-in libraries still load natively,
while user-writable caches such as eln-cache stay excluded.
`LaunchConfiguration.nativeCompilationPolicy' in the Swift launcher
applies the same policy and must be kept in sync."
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
              (let (trusted)
                (dolist (directory native-comp-eln-load-path)
                  (when (and (file-directory-p directory)
                             (not (file-writable-p directory)))
                    (push directory trusted)))
                (nreverse trusted)))))))

(glassmacs--configure-native-compilation)

(defvar glassmacs-root
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the Glassmacs configuration.")

(add-to-list 'load-path (expand-file-name "lisp" glassmacs-root))
(require 'glassmacs)

;;; init.el ends here
