;;; glassmacs-shiny.el --- Local Shiny application workflow -*- lexical-binding: t; -*-

(require 'glassmacs-core)

(defgroup glassmacs-shiny nil
  "Local Shiny application support."
  :group 'glassmacs)

(defcustom glassmacs-shiny-launch-browser nil
  "Whether `shiny::runApp' should open the local preview in a browser."
  :type 'boolean
  :group 'glassmacs-shiny)

(defvar glassmacs-shiny-process nil
  "The process started by `glassmacs-shiny-start'.")

(defun glassmacs-shiny--sentinel (process event)
  "Report when PROCESS exits with EVENT."
  (when (and (memq (process-status process) '(exit signal))
             (eq process glassmacs-shiny-process))
    (setq glassmacs-shiny-process nil)
    (unless (zerop (process-exit-status process))
      (message "Shiny process stopped (%s); see *Glassmacs Shiny*" event))))

(defun glassmacs-shiny--app-directory ()
  "Return the current Shiny project directory."
  (let ((directory
         (if (and buffer-file-name
                  (member (file-name-nondirectory buffer-file-name)
                          '("app.R" "ui.R" "server.R")))
             (file-name-directory buffer-file-name)
           default-directory)))
    (unless (or (file-exists-p (expand-file-name "app.R" directory))
                (and (file-exists-p (expand-file-name "ui.R" directory))
                     (file-exists-p (expand-file-name "server.R" directory))))
      (user-error "No app.R or ui.R/server.R Shiny application in %s" directory))
    directory))

(defun glassmacs-shiny-start ()
  "Start the current local Shiny application using Rscript."
  (interactive)
  (when (and (processp glassmacs-shiny-process)
             (process-live-p glassmacs-shiny-process))
    (user-error "A Glassmacs Shiny process is already running"))
  (let* ((directory (glassmacs-shiny--app-directory))
         (executable (executable-find "Rscript"))
         (buffer (get-buffer-create "*Glassmacs Shiny*"))
         (expression
          (format "shiny::runApp(appDir=%s, host=\"127.0.0.1\", launch.browser=%s)"
                  (glassmacs-r-quote directory)
                  (if glassmacs-shiny-launch-browser "TRUE" "FALSE"))))
    (unless executable
      (user-error "Rscript not found on PATH; install R and make it available"))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (setq glassmacs-shiny-process
          (make-process :name "glassmacs-shiny"
                        :buffer buffer
                        :command (list executable "-e" expression)
                        :noquery t
                        :sentinel #'glassmacs-shiny--sentinel))
    (message "Starting local Shiny application; see *Glassmacs Shiny*")))

(defun glassmacs-shiny-stop ()
  "Stop the Shiny process started by Glassmacs."
  (interactive)
  (if (and (processp glassmacs-shiny-process)
           (process-live-p glassmacs-shiny-process))
      (progn
        (delete-process glassmacs-shiny-process)
        (setq glassmacs-shiny-process nil)
        (message "Stopped Glassmacs Shiny process"))
    (setq glassmacs-shiny-process nil)
    (user-error "No Glassmacs Shiny process is running")))

(provide 'glassmacs-shiny)
;;; glassmacs-shiny.el ends here
