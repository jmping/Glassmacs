;;; glassmacs-core.el --- Shared Glassmacs setup -*- lexical-binding: t; -*-

(defgroup glassmacs nil
  "A modern Emacs configuration for macOS and reproducible research."
  :group 'environment)

(defcustom glassmacs-home
  (file-name-as-directory
   (expand-file-name
    (or (getenv "GLASSMACS_HOME") "~/.config/glassmacs")))
  "Directory for Glassmacs package data and generated state."
  :type 'directory
  :group 'glassmacs)

(defun glassmacs--initialize-packages ()
  "Initialize package.el using Glassmacs' isolated package directory."
  (require 'package)
  (setq user-emacs-directory (file-name-as-directory glassmacs-home)
        package-user-dir (expand-file-name "elpa" glassmacs-home)
        package-archives
        '(("gnu" . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/nongnu/")
          ("melpa" . "https://melpa.org/packages/")))
  (unless package--initialized
    (package-initialize)))

(glassmacs--initialize-packages)

(defun glassmacs-run-process (program arguments &optional directory)
  "Run PROGRAM with ARGUMENTS without a shell.
Use DIRECTORY as the working directory when non-nil.  Display output and
signal a user error when the executable is missing or exits unsuccessfully."
  (let ((executable (executable-find program))
        (output (get-buffer-create "*Glassmacs Process*")))
    (unless executable
      (user-error "Required executable not found on PATH: %s" program))
    (with-current-buffer output
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (let ((status
           (let ((default-directory (or directory default-directory)))
             (apply #'call-process executable nil output t arguments))))
      (display-buffer output)
      (unless (and (integerp status) (zerop status))
        (user-error "%s failed (exit status %s); see *Glassmacs Process*"
                    program status))
      status)))

(defun glassmacs-r-quote (string)
  "Return STRING as a safely escaped R string literal."
  (concat
   "\""
   (mapconcat
    (lambda (character)
      (pcase character
        (?\\ "\\\\")
        (?\" "\\\"")
        (?\n "\\n")
        (?\r "\\r")
        (?\t "\\t")
        (_ (if (or (< character 32) (= character 127))
               (if (<= character #xffff)
                   (format "\\u%04x" character)
                 (format "\\U%08x" character))
             (char-to-string character)))))
    (string-to-list string)
    "")
   "\""))

(provide 'glassmacs-core)
;;; glassmacs-core.el ends here
