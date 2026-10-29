;;; glassmacs-core.el --- Shared Glassmacs setup -*- lexical-binding: t; -*-

(defgroup glassmacs nil
  "A modern Emacs configuration for macOS and reproducible research."
  :group 'environment)

(defun glassmacs--default-home ()
  "Return the Glassmacs home named by GLASSMACS_HOME, or the default.
An empty GLASSMACS_HOME counts as unset, as in the macOS launcher, so
state is never written into whatever directory Emacs started in."
  (let ((configured (getenv "GLASSMACS_HOME")))
    (file-name-as-directory
     (expand-file-name
      (if (and configured (not (equal configured "")))
          configured
        "~/.config/glassmacs")))))

(defcustom glassmacs-home (glassmacs--default-home)
  "Directory for Glassmacs package data and generated state."
  :type 'directory
  :group 'glassmacs)

(defun glassmacs--ensure-home ()
  "Create `glassmacs-home' if it does not exist yet.
The macOS launcher creates it before starting Emacs, but source checkouts
started with scripts/glassmacs do not.  Without it, files Emacs writes
there on its own (the `recentf' list on exit, `custom-file') fail to save.
A failure is reported as a warning rather than aborting startup."
  (condition-case error-data
      (make-directory glassmacs-home t)
    (file-error
     (display-warning
      'glassmacs
      (format "Could not create Glassmacs home %s: %s"
              glassmacs-home (error-message-string error-data))
      :warning))))

(defun glassmacs--initialize-packages ()
  "Initialize package.el using Glassmacs' isolated package directory."
  (glassmacs--ensure-home)
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

(defconst glassmacs-process-buffer-name "*Glassmacs Process*"
  "Buffer that receives output from `glassmacs-run-process'.")

(defvar glassmacs--current-process nil
  "The process most recently started by `glassmacs-run-process'.")

(defun glassmacs--process-sentinel (process _event)
  "Report the outcome of PROCESS, started by `glassmacs-run-process'.
On success, also call the process's on-success function, if any."
  (when (memq (process-status process) '(exit signal))
    (let ((program (process-get process 'glassmacs-program))
          (status (process-exit-status process))
          (on-success (process-get process 'glassmacs-on-success)))
      (if (and (eq (process-status process) 'exit) (zerop status))
          (progn
            (message "%s finished; see %s" program glassmacs-process-buffer-name)
            (when on-success
              (funcall on-success)))
        (message "%s failed (exit status %s); see %s"
                 program status glassmacs-process-buffer-name)
        (display-buffer (process-buffer process))))))

(defun glassmacs-run-process (program arguments &optional directory on-success)
  "Start PROGRAM with ARGUMENTS asynchronously, without a shell.
Use DIRECTORY as the working directory when non-nil.  Call ON-SUCCESS,
a function of no arguments, if PROGRAM exits with status 0.  Output is shown in
`glassmacs-process-buffer-name' as it arrives, and a message reports
success or the exit status when PROGRAM finishes.  Return the process.

The process runs asynchronously so that long renders (Quarto, R Markdown,
knitr) do not freeze Emacs.  Only one such process runs at a time,
because they share one output buffer: signal a user error if the previous
one is still running, or if PROGRAM is not on PATH."
  (let ((executable (executable-find program))
        (output (get-buffer-create glassmacs-process-buffer-name)))
    (unless executable
      (user-error "Required executable not found on PATH: %s" program))
    (when (process-live-p glassmacs--current-process)
      (user-error "%s is still running; wait for it or kill %s"
                  (process-get glassmacs--current-process 'glassmacs-program)
                  glassmacs-process-buffer-name))
    (with-current-buffer output
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (let ((process
           (let ((default-directory (or directory default-directory)))
             (make-process :name "glassmacs-process"
                           :buffer output
                           :command (cons executable arguments)
                           :connection-type 'pipe
                           :sentinel #'glassmacs--process-sentinel))))
      (process-put process 'glassmacs-program program)
      (process-put process 'glassmacs-on-success on-success)
      (setq glassmacs--current-process process)
      (display-buffer output)
      (message "Running %s; see %s" program glassmacs-process-buffer-name)
      process)))

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
