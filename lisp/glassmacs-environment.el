;;; glassmacs-environment.el --- Shell environment for macOS GUI launches -*- lexical-binding: t; -*-

;; Applications started from Finder or the Dock inherit launchd's minimal
;; environment (PATH=/usr/bin:/bin:/usr/sbin:/sbin), not the environment
;; users configure in their shell.  CRAN R (/usr/local/bin), Homebrew
;; (/opt/homebrew/bin), MacTeX (/Library/TeX/texbin) and Quarto are then
;; not found, so R, rendering and Shiny commands fail even though they work
;; from Terminal.  Aquamacs solved this by reading the login shell's
;; environment at startup (`mac-read-environment-vars-from-shell'); this
;; module does the same, bounded by a timeout, and also appends standard
;; tool directories that exist but are missing from PATH.

(require 'cl-lib)
(require 'subr-x)

(defgroup glassmacs-environment nil
  "Environment variables for Glassmacs started from Finder or the Dock."
  :group 'glassmacs)

(defcustom glassmacs-import-shell-environment t
  "Whether graphical macOS sessions import variables from the login shell.
When non-nil, Glassmacs runs your login shell once at startup, which
executes your shell startup files (for example ~/.zprofile and
~/.zshrc), and copies `glassmacs-shell-environment-variables' into
Emacs.  This makes tools on your Terminal PATH available to Glassmacs."
  :type 'boolean
  :group 'glassmacs-environment)

(defcustom glassmacs-shell-environment-variables
  '("PATH" "MANPATH" "LANG" "LC_ALL" "LC_CTYPE" "R_LIBS" "R_LIBS_USER"
    "TEXINPUTS" "BIBINPUTS")
  "Variables copied from the login shell when they are set there."
  :type '(repeat string)
  :group 'glassmacs-environment)

(defcustom glassmacs-shell-environment-timeout 5
  "Seconds to wait for the login shell before giving up.
If the shell takes longer, startup continues with the inherited
environment plus `glassmacs-standard-tool-directories'."
  :type 'number
  :group 'glassmacs-environment)

(defcustom glassmacs-standard-tool-directories
  '("/opt/homebrew/bin" "/usr/local/bin" "/Library/TeX/texbin"
    "/Applications/quarto/bin" "/opt/local/bin")
  "Directories appended to PATH when they exist and are not already on it.
These are the default install locations of Homebrew (Apple silicon and
Intel), CRAN R, MacTeX, Quarto and MacPorts.  They are appended, so
directories from your shell configuration keep precedence."
  :type '(repeat directory)
  :group 'glassmacs-environment)

(defvar glassmacs-environment-status "not run"
  "Human-readable outcome of the last shell environment import.")

(defconst glassmacs-environment--marker "__GLASSMACS_ENVIRONMENT__"
  "Line printed before the environment, separating it from shell noise.")

(defun glassmacs-environment--shell ()
  "Return the user's login shell."
  (or (getenv "SHELL") shell-file-name "/bin/zsh"))

(defun glassmacs-environment--shell-arguments (shell)
  "Return the arguments that make SHELL read the user's configuration.
csh and tcsh accept -l only as their sole flag, so they use -d to read
their startup files; fish reads its configuration in every login shell;
other shells are started as interactive login shells so that both
profile and rc files (where many users set PATH) are read."
  (let ((name (file-name-nondirectory shell)))
    (cond
     ((string-match-p "\\`t?csh\\'" name) '("-d"))
     ((string-equal name "fish") '("-l"))
     (t '("-l" "-i")))))

(defun glassmacs-environment--parse (output variables)
  "Return an alist of VARIABLES and their values found in OUTPUT.
OUTPUT is the text printed by the shell; only lines after
`glassmacs-environment--marker' are considered, and the first value
for each variable wins."
  (let ((start (string-search (concat glassmacs-environment--marker "\n")
                              output))
        result)
    (when start
      (dolist (line (split-string
                     (substring output (+ start 1
                                          (length glassmacs-environment--marker)))
                     "\n"))
        (when (string-match "\\`\\([A-Za-z_][A-Za-z0-9_]*\\)=\\(.*\\)\\'" line)
          (let ((name (match-string 1 line))
                (value (match-string 2 line)))
            (when (and (member name variables) (not (assoc name result)))
              (push (cons name value) result))))))
    (nreverse result)))

(defun glassmacs-environment--read-shell (shell variables timeout)
  "Run SHELL and return VARIABLES from its environment, or a status string.
Return an alist on success.  Return a string describing the failure when
the shell cannot start, exits unsuccessfully or exceeds TIMEOUT seconds."
  (let* ((output (generate-new-buffer " *glassmacs-shell-environment*" t))
         (errors (generate-new-buffer " *glassmacs-shell-environment-stderr*" t))
         (default-directory (expand-file-name "~/"))
         (command (format "printf '%%s\\n' %s; /usr/bin/env"
                          glassmacs-environment--marker))
         process)
    (unwind-protect
        (condition-case error-data
            (progn
              (setq process
                    (make-process
                     :name "glassmacs-shell-environment"
                     :buffer output
                     :stderr errors
                     :command (append (list shell)
                                      (glassmacs-environment--shell-arguments shell)
                                      (list "-c" command))
                     :connection-type 'pipe
                     :noquery t
                     :sentinel #'ignore))
              (process-send-eof process)
              (let ((deadline (+ (float-time) timeout)))
                (while (and (process-live-p process)
                            (< (float-time) deadline))
                  (accept-process-output process 0.05)))
              (cond
               ((process-live-p process)
                (format "timed out after %s seconds" timeout))
               ((not (zerop (process-exit-status process)))
                (format "%s exited with status %d"
                        shell (process-exit-status process)))
               (t
                (or (glassmacs-environment--parse
                     (with-current-buffer output (buffer-string))
                     variables)
                    "the shell printed no environment"))))
          (error (format "could not run %s: %s"
                         shell (error-message-string error-data))))
      (when (processp process)
        (delete-process process))
      (when-let* ((stderr-process (get-buffer-process errors)))
        (delete-process stderr-process))
      (kill-buffer output)
      (kill-buffer errors))))

(defun glassmacs-environment--set-path (path)
  "Set the PATH environment variable and `exec-path' from PATH."
  (setenv "PATH" path)
  (setq exec-path (append (parse-colon-path path) (list exec-directory))))

(defun glassmacs-environment--append-standard-directories ()
  "Append existing `glassmacs-standard-tool-directories' missing from PATH.
Return the list of directories that were added."
  (let* ((path (or (getenv "PATH") ""))
         (current (mapcar #'directory-file-name (parse-colon-path path)))
         added)
    (dolist (directory glassmacs-standard-tool-directories)
      (let ((directory (directory-file-name (expand-file-name directory))))
        (when (and (file-directory-p directory)
                   (not (member directory current)))
          (push directory added)
          (push directory current))))
    (when added
      (setq added (nreverse added))
      (glassmacs-environment--set-path
       (mapconcat #'identity
                  (append (and (not (string-empty-p path)) (list path)) added)
                  path-separator)))
    added))

(defun glassmacs-import-shell-environment ()
  "Import the login shell's environment and standard tool directories.
Copy `glassmacs-shell-environment-variables' from the login shell (when
`glassmacs-import-shell-environment' is non-nil), then append existing
`glassmacs-standard-tool-directories'.  Record the outcome in
`glassmacs-environment-status' and return it."
  (interactive)
  (let ((started (float-time))
        (status nil))
    (if (not glassmacs-import-shell-environment)
        (setq status "shell import disabled")
      (let* ((shell (glassmacs-environment--shell))
             (result (glassmacs-environment--read-shell
                      shell glassmacs-shell-environment-variables
                      glassmacs-shell-environment-timeout)))
        (if (stringp result)
            (progn
              (setq status (format "shell import failed: %s" result))
              (display-warning
               'glassmacs
               (format "Could not import your shell environment (%s); tools on your Terminal PATH may not be found.  See `glassmacs-import-shell-environment'."
                       result)
               :warning))
          (dolist (entry result)
            (if (equal (car entry) "PATH")
                (glassmacs-environment--set-path (cdr entry))
              (setenv (car entry) (cdr entry))))
          (setq status (format "imported %d variable(s) from %s in %.1fs"
                               (length result) shell
                               (- (float-time) started))))))
    (let ((added (glassmacs-environment--append-standard-directories)))
      (when added
        (setq status (format "%s; appended %s" status
                             (mapconcat #'identity added ", ")))))
    (setq glassmacs-environment-status status)
    (when (called-interactively-p 'interactive)
      (message "Glassmacs environment: %s" status))
    status))

(defun glassmacs-environment--gui-launch-p ()
  "Return non-nil for a graphical macOS session, where launchd sets PATH."
  (and (eq system-type 'darwin)
       (not noninteractive)
       (display-graphic-p)))

(defun glassmacs-environment-initialize ()
  "Import the shell environment at startup in graphical macOS sessions."
  (if (glassmacs-environment--gui-launch-p)
      (glassmacs-import-shell-environment)
    (setq glassmacs-environment-status
          "not needed (not a graphical macOS session)")))

(provide 'glassmacs-environment)
;;; glassmacs-environment.el ends here
