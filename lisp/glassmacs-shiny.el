;;; glassmacs-shiny.el --- Shiny apps and interactive documents -*- lexical-binding: t; -*-

;; Runs a local Shiny application (app.R, or ui.R and server.R), or an
;; interactive document (R Markdown with `runtime: shiny', Quarto with
;; `server: shiny'), as one background process whose output appears in
;; *Glassmacs Shiny*.  When the app reports the address it listens on,
;; Glassmacs remembers it and opens the preview in the web browser.  The
;; app only listens on 127.0.0.1.  Only one app runs at a time; Reload
;; restarts the last one.

(require 'glassmacs-core)
(require 'subr-x)

(defgroup glassmacs-shiny nil
  "Local Shiny application support."
  :group 'glassmacs)

(defcustom glassmacs-shiny-launch-browser t
  "Whether Glassmacs opens the app in the web browser once it is ready.
Glassmacs waits for the address the app reports, so the browser does not
open on a page that is not listening yet.  The address is also kept for
\\[glassmacs-shiny-open-preview]."
  :type 'boolean
  :group 'glassmacs-shiny)

(defconst glassmacs-shiny-buffer-name "*Glassmacs Shiny*"
  "Buffer showing the output of the running app.")

(defconst glassmacs-shiny--url-regexp
  "\\(?:Listening on\\|Browse at\\) \\(https?://[^[:space:]]+\\)[ \t]*\r?\n"
  "Matches the address Shiny (\"Listening on\") or Quarto (\"Browse at\") reports.")

(defvar glassmacs-shiny-process nil
  "The process started by `glassmacs-shiny-start' or an interactive document.")

(defvar glassmacs-shiny-url nil
  "The address the running app reported, or nil.")

(defvar glassmacs-shiny--last-start nil
  "Function that starts the most recently started app again.")

(defun glassmacs-shiny--running-p ()
  "Return non-nil when an app started by Glassmacs is running."
  (and (processp glassmacs-shiny-process)
       (process-live-p glassmacs-shiny-process)))

(defun glassmacs-shiny--sentinel (process event)
  "Report when PROCESS exits with EVENT."
  (when (and (memq (process-status process) '(exit signal))
             (eq process glassmacs-shiny-process))
    (setq glassmacs-shiny-process nil
          glassmacs-shiny-url nil)
    (unless (zerop (process-exit-status process))
      (message "Shiny process stopped (%s); see %s"
               (string-trim event) glassmacs-shiny-buffer-name))))

(defun glassmacs-shiny--reported-url (buffer)
  "Return the first complete app address reported in BUFFER, or nil.
The address line must be complete, because output can arrive in pieces."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (and (re-search-forward glassmacs-shiny--url-regexp nil t)
           (match-string-no-properties 1)))))

(defun glassmacs-shiny--filter (process output)
  "Insert OUTPUT from PROCESS and open the app once it reports its address."
  (when (buffer-live-p (process-buffer process))
    (with-current-buffer (process-buffer process)
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (process-mark process))
          (insert output)
          (set-marker (process-mark process) (point)))))
    (when (and (eq process glassmacs-shiny-process)
               (not glassmacs-shiny-url))
      (when-let* ((url (glassmacs-shiny--reported-url (process-buffer process))))
        (setq glassmacs-shiny-url url)
        (glassmacs-shiny--announce url)))))

(defun glassmacs-shiny--announce (url)
  "Open URL in the browser or report it, per `glassmacs-shiny-launch-browser'."
  (if glassmacs-shiny-launch-browser
      (browse-url url)
    (message "Shiny app is running at %s" url)))

(defun glassmacs-shiny--start (description command directory restart)
  "Start COMMAND in DIRECTORY as the Glassmacs Shiny process.
DESCRIPTION names what runs, for messages.  RESTART is a function that
starts the same app again, used by `glassmacs-shiny-reload'."
  (when (glassmacs-shiny--running-p)
    (user-error "A Glassmacs Shiny app is already running; stop or reload it"))
  (let ((buffer (get-buffer-create glassmacs-shiny-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (setq glassmacs-shiny-url nil
          glassmacs-shiny--last-start restart
          glassmacs-shiny-process
          (let ((default-directory directory))
            (make-process :name "glassmacs-shiny"
                          :buffer buffer
                          :command command
                          :connection-type 'pipe
                          :noquery t
                          :filter #'glassmacs-shiny--filter
                          :sentinel #'glassmacs-shiny--sentinel)))
    (message "Starting %s; see %s" description glassmacs-shiny-buffer-name)
    glassmacs-shiny-process))

(defun glassmacs-shiny--require (program)
  "Return the full name of PROGRAM, or explain that it is missing."
  (or (executable-find program)
      (user-error "%s not found on PATH; install it and make it available" program)))

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

(defun glassmacs-shiny-app-file-p ()
  "Return non-nil when the current buffer visits a Shiny app file."
  (and buffer-file-name
       (member (file-name-nondirectory buffer-file-name) '("app.R" "ui.R" "server.R"))))

(defun glassmacs-shiny-start ()
  "Start the current local Shiny application using Rscript."
  (interactive)
  (let* ((directory (glassmacs-shiny--app-directory))
         (executable (glassmacs-shiny--require "Rscript"))
         (expression
          (format "shiny::runApp(appDir = %s, host = \"127.0.0.1\", launch.browser = FALSE)"
                  (glassmacs-r-quote directory))))
    (glassmacs-shiny--start
     "local Shiny application" (list executable "-e" expression) directory
     (lambda ()
       ;; Restart the same app, whatever buffer is current at reload time.
       (with-temp-buffer
         (setq default-directory directory)
         (glassmacs-shiny-start))))))

(defun glassmacs-shiny-interactive-document-p ()
  "Return non-nil when the current buffer is an interactive Shiny document.
That is R Markdown with `runtime: shiny' (or shiny_prerendered) or Quarto
with `server: shiny' in its YAML front matter."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (when (looking-at "---[ \t]*\n")
        (let ((end (save-excursion
                     (forward-line 1)
                     (and (re-search-forward "^\\(?:---\\|\\.\\.\\.\\)[ \t]*$" nil t)
                          (point)))))
          (and end
               (re-search-forward
                "^\\(?:runtime:[ \t]*['\"]?shiny\\(?:_prerendered\\|rmd\\)?\\|server:[ \t]*['\"]?shiny\\)\\b"
                end t)))))))

(declare-function glassmacs--current-file "glassmacs-documents" ())

(defun glassmacs-run-interactive-document ()
  "Run the current interactive document as a local Shiny app.
R Markdown runs with rmarkdown::run(); Quarto with `quarto preview'.
Glassmacs opens it in the browser when it is ready."
  (interactive)
  (unless (glassmacs-shiny-interactive-document-p)
    (user-error "This document has no runtime: shiny (or Quarto server: shiny)"))
  (let* ((file (glassmacs--current-file))
         (directory (file-name-directory file))
         (buffer (current-buffer))
         (restart (lambda ()
                    (with-current-buffer buffer
                      (glassmacs-run-interactive-document)))))
    (if (string-match-p "\\.qmd\\'" file)
        (glassmacs-shiny--start
         "interactive Quarto document"
         (list (glassmacs-shiny--require "quarto") "preview" file
               "--no-browser" "--no-watch-inputs")
         directory restart)
      (glassmacs-shiny--start
       "interactive R Markdown document"
       (list (glassmacs-shiny--require "Rscript") "-e"
             (format "rmarkdown::run(%s, shiny_args = list(host = \"127.0.0.1\", launch.browser = FALSE))"
                     (glassmacs-r-quote file)))
       directory restart))))

(defun glassmacs-shiny-stop ()
  "Stop the Shiny app or interactive document started by Glassmacs."
  (interactive)
  (if (glassmacs-shiny--running-p)
      (progn
        (delete-process glassmacs-shiny-process)
        (setq glassmacs-shiny-process nil
              glassmacs-shiny-url nil)
        (message "Stopped Glassmacs Shiny process"))
    (setq glassmacs-shiny-process nil)
    (user-error "No Glassmacs Shiny process is running")))

(defun glassmacs-shiny-reload ()
  "Restart the most recently started Shiny app, for example after edits."
  (interactive)
  (unless glassmacs-shiny--last-start
    (user-error "No Shiny app has been started yet"))
  (when (glassmacs-shiny--running-p)
    (delete-process glassmacs-shiny-process)
    (setq glassmacs-shiny-process nil
          glassmacs-shiny-url nil))
  (funcall glassmacs-shiny--last-start))

(defun glassmacs-shiny-open-preview ()
  "Open the running Shiny app in the web browser."
  (interactive)
  (unless (and (glassmacs-shiny--running-p) glassmacs-shiny-url)
    (user-error "No running Shiny app has reported its address yet"))
  (browse-url glassmacs-shiny-url))

(provide 'glassmacs-shiny)
;;; glassmacs-shiny.el ends here
