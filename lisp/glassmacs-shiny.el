;;; glassmacs-shiny.el --- Shiny apps and interactive documents -*- lexical-binding: t; -*-

;; Runs a local Shiny application (app.R, or ui.R and server.R), or an
;; interactive document (R Markdown with `runtime: shiny', Quarto with
;; `server: shiny'), as one background process whose output appears in
;; *Glassmacs Shiny*.  When the app reports the address it listens on,
;; Glassmacs remembers it and opens the preview in the web browser.  The
;; app only listens on 127.0.0.1.  Only one app runs at a time; Reload
;; restarts the last one.

(require 'glassmacs-core)
(require 'glassmacs-document-jobs)
(require 'cl-lib)
(require 'subr-x)
(require 'url-parse)

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

(defvar glassmacs-shiny-job nil
  "Optional document-job status record for the current local Shiny process.")

(defvar glassmacs-shiny--serial 0
  "Monotone identifier for Shiny job records in this Emacs session.")

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
    (when (and (glassmacs-document-job-p glassmacs-shiny-job)
               (eq (glassmacs-document-job-process glassmacs-shiny-job)
                   process)
               (eq (glassmacs-document-job-status glassmacs-shiny-job)
                   'running))
      (glassmacs-document-job-transition
       glassmacs-shiny-job
       (if (and (eq (process-status process) 'exit)
                (zerop (process-exit-status process)))
           'succeeded 'failed)
       nil
       (unless (and (eq (process-status process) 'exit)
                    (zerop (process-exit-status process)))
         (format "Shiny process %s (exit %d)"
                 (process-status process) (process-exit-status process)))))
    (setq glassmacs-shiny-process nil
          glassmacs-shiny-url nil)
    (unless (zerop (process-exit-status process))
      (message "Shiny process stopped (%s); see %s"
               (string-trim event) glassmacs-shiny-buffer-name))))

(defun glassmacs-shiny--loopback-url-p (url)
  "Whether URL is an HTTP(S) loopback address with an explicit port.
A child process log must not direct the browser to a remote host, even
if its output includes a line resembling Shiny's startup message."
  (and (stringp url)
       ;; \`url-port' supplies a scheme default even when none was written.
       ;; Require a literal authority port before accepting a child log URL.
       (string-match-p "\\`https?://\\(?:\\[[^]]+\\]\\|[^/:@?#]+\\):[0-9]+\\(?:[/#?]\\|\\'\\)" url)
       (ignore-errors
         (let* ((parsed (url-generic-parse-url url))
                (scheme (url-type parsed))
                (host (url-host parsed))
                (port (url-port parsed)))
           (and (member scheme '("http" "https"))
                (member (downcase (or host ""))
                        '("127.0.0.1" "localhost" "::1" "[::1]"))
                (not (url-user parsed))
                (integerp port) (<= 1 port 65535))))))

(defun glassmacs-shiny--reported-url (buffer)
  "Return the first complete loopback app address reported in BUFFER.
Output may arrive in pieces.  Ignore external or malformed URLs instead
of passing them to the browser."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (catch 'found
        (while (re-search-forward glassmacs-shiny--url-regexp nil t)
          (let ((url (match-string-no-properties 1)))
            (when (glassmacs-shiny--loopback-url-p url)
              (throw 'found url))))
        nil))))

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

(defun glassmacs-shiny--start (description command directory restart &optional source)
  "Start a local Shiny COMMAND in DIRECTORY with a captured SOURCE.
SOURCE is an explicit absolute local file name, never inferred from the
buffer selected when an asynchronous command runs.  For an application,
the canonical fallback is app.R or ui.R in DIRECTORY.  RESTART is the
explicit user-requested reload function; no process is replayed on startup."
  (when (glassmacs-shiny--running-p)
    (user-error "A Glassmacs Shiny app is already running; stop or reload it"))
  (unless (and (stringp directory) (file-name-absolute-p directory)
               (not (file-remote-p directory)))
    (user-error "Shiny requires a local absolute application directory"))
  (let* ((dir (file-name-as-directory (expand-file-name directory)))
         (origin (or source
                     (expand-file-name
                      (if (file-exists-p (expand-file-name "app.R" dir))
                          "app.R" "ui.R")
                      dir)))
         (buffer (get-buffer-create glassmacs-shiny-buffer-name))
         (record-p (bound-and-true-p glassmacs-document-use-job-adapter))
         (job nil)
         (process nil))
    (when (and record-p
               (not (and (stringp origin)
                         (file-name-absolute-p origin)
                         (not (file-remote-p origin))
                         (equal (file-name-directory (expand-file-name origin))
                                dir))))
      (user-error "Shiny job source must be a local file in its application directory"))
    (when record-p
      (setq job (glassmacs-document-job-new
                 (format "shiny-%d" (cl-incf glassmacs-shiny--serial))
                 (glassmacs-document-context-for-file origin)
                 'shiny buffer)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (setq glassmacs-shiny-url nil
          glassmacs-shiny-job job
          glassmacs-shiny-process nil)
    (when job
      (glassmacs-document-jobs-register job))
    (condition-case err
        (setq process
              (let ((default-directory dir))
                (make-process :name "glassmacs-shiny"
                              :buffer buffer
                              :command command
                              :connection-type 'pipe
                              :noquery t
                              :filter #'glassmacs-shiny--filter
                              :sentinel #'glassmacs-shiny--sentinel)))
      (error
       (when job
         (glassmacs-document-job-transition
          job 'failed nil (error-message-string err)))
       (signal (car err) (cdr err))))
    (setq glassmacs-shiny-process process
          glassmacs-shiny--last-start restart)
    (when job
      (setf (glassmacs-document-job-process job) process)
      (glassmacs-document-job-transition job 'running))
    ;; The child may have exited before the process was assigned.  A second
    ;; sentinel delivery is harmless because the former process is no
    ;; longer current and terminal job states are not transitioned twice.
    (when (memq (process-status process) '(exit signal))
      (glassmacs-shiny--sentinel process "already exited"))
    (message "Starting %s; see %s" description glassmacs-shiny-buffer-name)
    process))

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

(defun glassmacs-shiny-start (&optional source-file)
  "Start the current local Shiny app, retaining SOURCE-FILE on reload.
The app entry point is always app.R or ui.R, even when the selected buffer
visits server.R or an unrelated document in the same project."
  (interactive)
  (let* ((directory (glassmacs-shiny--app-directory))
         (source (or source-file
                     (expand-file-name
                      (if (file-exists-p (expand-file-name "app.R" directory))
                          "app.R" "ui.R")
                      directory)))
         (executable (glassmacs-shiny--require "Rscript"))
         (expression
          (format "shiny::runApp(appDir = %s, host = \"127.0.0.1\", launch.browser = FALSE)"
                  (glassmacs-r-quote directory))))
    (glassmacs-shiny--start
     "local Shiny application" (list executable "-e" expression) directory
     (lambda ()
       (with-temp-buffer
         (setq default-directory directory)
         (glassmacs-shiny-start source)))
     source)))

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
R Markdown uses rmarkdown::run(); Quarto uses quarto preview.  Reload
preserves the exact original document path without reopening its buffer."
  (interactive)
  (unless (glassmacs-shiny-interactive-document-p)
    (user-error "This document has no runtime: shiny (or Quarto server: shiny)"))
  (let* ((file (glassmacs--current-file))
         (directory (file-name-directory file))
         (quarto (string-match-p "\\.qmd\\'" file))
         (description (if quarto
                          "interactive Quarto document"
                        "interactive R Markdown document"))
         (command (if quarto
                      (list (glassmacs-shiny--require "quarto") "preview" file
                            "--no-browser" "--no-watch-inputs")
                    (list (glassmacs-shiny--require "Rscript") "-e"
                          (format
                           "rmarkdown::run(%s, shiny_args = list(host = \"127.0.0.1\", launch.browser = FALSE))"
                           (glassmacs-r-quote file))))))
    (letrec ((restart
              (lambda ()
                (glassmacs-shiny--start
                 description command directory restart file))))
      (glassmacs-shiny--start description command directory restart file))))

(defun glassmacs-shiny-stop ()
  "Stop the Shiny app or interactive document started by Glassmacs."
  (interactive)
  (if (glassmacs-shiny--running-p)
      (progn
        (when (and (glassmacs-document-job-p glassmacs-shiny-job)
                   (eq (glassmacs-document-job-status glassmacs-shiny-job)
                       'running))
          (glassmacs-document-job-transition glassmacs-shiny-job 'cancelled))
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
    (when (and (glassmacs-document-job-p glassmacs-shiny-job)
               (eq (glassmacs-document-job-status glassmacs-shiny-job)
                   'running))
      (glassmacs-document-job-transition glassmacs-shiny-job 'cancelled))
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
