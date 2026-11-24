;;; glassmacs-remote.el --- Remote file and terminal helpers -*- lexical-binding: t; -*-

(require 'subr-x)

(defgroup glassmacs-remote nil
  "Remote file and terminal workflows for Glassmacs."
  :group 'glassmacs)

(eval-when-compile
  (require 'term)
  (require 'tramp))

(defconst glassmacs-remote--local-tools '("ssh" "mosh" "tmux")
  "Optional remote-workflow executables checked on the local machine.")

(defun glassmacs-remote--validate-host (host)
  "Return HOST when it is a simple SSH host name or alias."
  (unless (and (stringp host)
               (string-match-p "\\`[[:alnum:]_.-]+\\'" host))
    (user-error "Use an SSH host name or alias without user@, wildcards, or separators"))
  host)

(defun glassmacs-remote--validate-path (path)
  "Return PATH when it is an absolute remote POSIX path."
  (unless (and (stringp path) (file-name-absolute-p path))
    (user-error "Remote path must be absolute: %s" path))
  path)

(defun glassmacs-remote-make-path (host path)
  "Construct a TRAMP SSH path for HOST and absolute remote PATH.
HOST is an SSH host name or alias, so OpenSSH continues to apply the
user's existing SSH configuration and authentication settings."
  (require 'tramp)
  (tramp-make-tramp-file-name
   (make-tramp-file-name
    :method "ssh"
    :host (glassmacs-remote--validate-host host)
    :localname (glassmacs-remote--validate-path path))))

(defun glassmacs-remote-context (&optional path)
  "Return remote context for PATH, or the current buffer when PATH is nil.
The returned plist contains :method, :user, :host, :port, and :localname.
It is nil for a local path.  This read-only interface is available to
future integrations without coupling them to remote process management."
  (let* ((path
          (or path
              (and buffer-file-name
                   (file-remote-p buffer-file-name)
                   buffer-file-name)
              default-directory))
         (remote (and path (file-remote-p path))))
    (when remote
      (require 'tramp)
      (let ((vector (tramp-dissect-file-name path)))
        (list :method (tramp-file-name-method vector)
              :user (tramp-file-name-user vector)
              :host (tramp-file-name-host vector)
              :port (tramp-file-name-port vector)
              :localname (tramp-file-name-localname vector))))))

(defun glassmacs-remote--require-executable (program)
  "Return the local executable path for PROGRAM or signal a user error."
  (or (executable-find program)
      (user-error "Required local executable not found on PATH: %s" program)))


(defun glassmacs-remote-execution-identity (&optional directory)
  "Return a stable, path-free identity for DIRECTORY's execution context.
This only parses a directory's TRAMP syntax.  It neither connects nor
asserts that any remote R process has been successfully started."
  (let ((context (and directory (file-remote-p directory)
                      (glassmacs-remote-context directory))))
    (if context
        (list :kind 'remote
              :method (plist-get context :method)
              :host (plist-get context :host)
              :user (plist-get context :user)
              :port (plist-get context :port))
      (list :kind 'local))))

(defun glassmacs-remote-execution-label (identity)
  "Return a concise location label for path-free IDENTITY."
  (if (eq (plist-get identity :kind) 'local)
      "local"
    (format "%s:%s%s%s"
            (or (plist-get identity :method) "remote")
            (if-let* ((user (plist-get identity :user)))
                (concat user "@") "")
            (or (plist-get identity :host) "?")
            (if-let* ((port (plist-get identity :port)))
                (format "#%s" port) ""))))

(defun glassmacs-remote-cross-location-p (source target)
  "Whether remote SOURCE and TARGET identities conflict.
A local source is intentionally permitted to target a remote process.
A remote source requires a matching method, host, user and port unless
the user explicitly approves a specific cross-location R target."
  (and (eq (plist-get source :kind) 'remote)
       (not (equal source target))))


;;; Explicit remote ESS startup over SSH/TRAMP.

(defun glassmacs-remote-r-directory (host directory)
  "Return an SSH TRAMP directory for HOST and absolute DIRECTORY.
Reject malformed names before establishing any connection."
  (file-name-as-directory
   (glassmacs-remote-make-path host directory)))

(defun glassmacs-remote-r-launch-context (host directory)
  "Return a validated, network-free remote ESS launch descriptor.
Only SSH aliases and absolute remote directories are supported.
A descriptor is not proof of a connection or of an executable R."
  (let ((path (glassmacs-remote-r-directory host directory)))
    (list :directory path
          :identity (glassmacs-remote-execution-identity path))))

(defun glassmacs-remote-r--ensure-ess ()
  "Require ESS R startup support or signal a clear error."
  (unless (locate-library "ess-site")
    (user-error "Remote R requires ESS; install the ess package first"))
  (require 'ess-site)
  (unless (fboundp 'R)
    (user-error "ESS does not provide the R startup command")))

(defun glassmacs-remote-r--start-ess (directory)
  "Start an ESS R process from remote DIRECTORY through TRAMP.
ESS owns the process, filter, prompts, process buffer and connection.
This function does not interpret R output or create an independent queue."
  (glassmacs-remote-r--ensure-ess)
  ;; ESS owns startup.  Give it a transient source buffer whose actual
  ;; default-directory is remote, without changing the user's document.
  ;; ESS may switch buffers by selecting windows or by changing the current
  ;; buffer; prefer its reported process name for resolving the console.
  (let ((origin (current-buffer))
        (launch-buffer (generate-new-buffer " *Glassmacs remote R launch*"))
        console)
    (unwind-protect
        (with-current-buffer launch-buffer
          (setq default-directory directory)
          (call-interactively #'R)
          (let* ((name (and (boundp 'ess-local-process-name)
                            ess-local-process-name))
                 (proc (and (stringp name) (get-process name))))
            (setq console (and (processp proc) (process-buffer proc)))))
      (when (buffer-live-p launch-buffer)
        (kill-buffer launch-buffer)))
    (unless (and (buffer-live-p console) (not (eq console origin)))
      (user-error "ESS did not create a distinct remote R console"))
    console))

(defun glassmacs-remote-r--verify-process (process directory)
  "Ensure PROCESS is live and associated with remote DIRECTORY.
Never relabel a local R process as remote.  The ESS console's remote
directory is a location check, not an independent query to R getwd()."
  (unless (and (processp process) (process-live-p process))
    (user-error "ESS did not start a live remote R process"))
  (let* ((buffer (process-buffer process))
         (actual (and (buffer-live-p buffer)
                      (buffer-local-value 'default-directory buffer)))
         (expected-id (glassmacs-remote-execution-identity directory))
         (actual-id (glassmacs-remote-execution-identity actual)))
    (unless (and actual
                 (file-remote-p actual)
                 (equal expected-id actual-id))
      (user-error
       "ESS R process was not created on the requested remote execution host"))
    process))

(defun glassmacs-remote-tool-status ()
  "Return local availability of SSH, Mosh, and tmux executables."
  (mapcar (lambda (program)
            (cons program (executable-find program)))
          glassmacs-remote--local-tools))

(defun glassmacs-remote-check-tools ()
  "Display local availability of SSH, Mosh, and tmux."
  (interactive)
  (with-current-buffer (get-buffer-create "*Glassmacs Remote Tools*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "Local remote-workflow tools\n\n")
      (dolist (tool (glassmacs-remote-tool-status))
        (insert (format "%-6s %s\n"
                        (car tool)
                        (or (cdr tool) "not found on local PATH"))))
      (insert "\nThis does not probe remote hosts or install software.\n")
      (special-mode))
    (display-buffer (current-buffer))))

(defun glassmacs-remote--read-host ()
  "Read and validate an SSH host name or alias."
  (glassmacs-remote--validate-host (read-string "SSH host name or alias: ")))

(defun glassmacs-remote-open (host path)
  "Open remote PATH on SSH HOST using ordinary Emacs file commands."
  (interactive
   (list (glassmacs-remote--read-host)
         (read-string "Absolute remote file or directory: " "/")))
  (let ((remote-path (glassmacs-remote-make-path host path)))
    (glassmacs-remote--require-executable "ssh")
    (condition-case error-data
        (find-file remote-path)
      (file-error
       (user-error "TRAMP could not open %s: %s"
                   remote-path (error-message-string error-data))))))

(defun glassmacs-remote-shell (host directory)
  "Open an Emacs shell in remote DIRECTORY on SSH HOST."
  (interactive
   (list (glassmacs-remote--read-host)
         (read-string "Absolute remote working directory: " "/")))
  (let* ((remote-directory
          (file-name-as-directory
           (glassmacs-remote-make-path host directory)))
         (buffer-name (generate-new-buffer-name
                       (format "Glassmacs Shell %s" host))))
    (glassmacs-remote--require-executable "ssh")
    (condition-case error-data
        (let ((default-directory remote-directory))
          (shell buffer-name))
      (file-error
       (user-error "TRAMP could not start a shell on %s: %s"
                   remote-directory (error-message-string error-data))))))

(defun glassmacs-remote--current-path ()
  "Return the current remote file or directory, or signal a user error."
  (let ((context (glassmacs-remote-context)))
    (unless context
      (user-error "The current buffer is not associated with a TRAMP path"))
    (or (and buffer-file-name
             (file-remote-p buffer-file-name)
             buffer-file-name)
        default-directory)))

(defun glassmacs-remote-inspect ()
  "Show the current TRAMP host and whether its connection is active.
This inspects only Emacs' existing TRAMP connection buffer and does not
initiate a network connection."
  (interactive)
  (let* ((path (glassmacs-remote--current-path))
         (context (glassmacs-remote-context path)))
    (require 'tramp)
    (let* ((vector (tramp-dissect-file-name path))
           (connection (tramp-get-connection-buffer vector t))
           (process (and connection (get-buffer-process connection)))
           (status
            (cond
             ((and process (process-live-p process))
              (format "live (%s)" (process-status process)))
             (connection "connection buffer exists without a live process")
             (t "no existing connection buffer"))))
      (with-current-buffer (get-buffer-create "*Glassmacs Remote*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "TRAMP method: %s\nHost: %s\nUser: %s\nPort: %s\n"
                          (plist-get context :method)
                          (plist-get context :host)
                          (or (plist-get context :user) "(SSH default)")
                          (or (plist-get context :port) "(SSH default)")))
          (insert (format "Remote path: %s\nConnection: %s\n"
                          (plist-get context :localname) status))
          (special-mode))
        (display-buffer (current-buffer))))))

(defun glassmacs-remote-cleanup-connection ()
  "Clean up the current TRAMP connection without changing SSH settings.
The TRAMP password cache is preserved.  The next explicit access to the
remote path can establish a new connection; no commands are replayed."
  (interactive)
  (let* ((path (glassmacs-remote--current-path)))
    (require 'tramp)
    (tramp-cleanup-connection (tramp-dissect-file-name path) nil t)
    (message "Cleaned up the TRAMP connection for %s"
             (file-remote-p path 'host))))

(defun glassmacs-remote-mosh (host)
  "Start an optional Mosh terminal to SSH HOST using Emacs `term'."
  (interactive (list (glassmacs-remote--read-host)))
  (let ((host (glassmacs-remote--validate-host host)))
    (glassmacs-remote--require-executable "ssh")
    (let* ((mosh (glassmacs-remote--require-executable "mosh"))
           (buffer
            (make-term (generate-new-buffer-name
                        (format "Glassmacs Mosh %s" host))
                       mosh nil host)))
      (with-current-buffer buffer
        (term-char-mode))
      (pop-to-buffer buffer))))

(provide 'glassmacs-remote)
;;; glassmacs-remote.el ends here
