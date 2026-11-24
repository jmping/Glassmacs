;;; glassmacs-r-artifacts.el --- Explicit R output artifacts -*- lexical-binding: t; -*-

;; Opt-in remote artifacts.  No X11 forwarding, remote R code injection,
;; automatic path mapping or SSH connection occurs during path validation.

(require 'cl-lib)
(require 'subr-x)
(require 'glassmacs-remote)

(defgroup glassmacs-r-artifacts nil
  "Remote R plots and research artifacts." :group 'glassmacs-remote)

(defcustom glassmacs-r-artifacts-max-bytes (* 64 1024 1024)
  "Maximum size of an explicitly downloaded or previewed artifact."
  :type 'integer :group 'glassmacs-r-artifacts)

(defconst glassmacs-r-artifacts--extensions '("png" "jpg" "jpeg" "svg" "pdf" "html" "htm" "txt" "csv")
  "Allowed file extensions for explicit artifact operations.")

(defvar glassmacs-r-artifacts--history nil
  "Most recent artifact records, newest first. Each includes a source context.")
(defvar glassmacs-r-artifacts--history-position 0)

(defun glassmacs-r-artifacts--validate-relative (name)
  "Validate project-relative artifact NAME without opening a connection.
Do not accept TRAMP syntax, shell redirection, traversal or absolute paths."
  (unless (and (stringp name) (not (string-empty-p name))
               (not (file-name-absolute-p name))
               (not (string-match-p "[:\\\\\r\n\0]" name))
               (not (string-match-p "\\`[~/]" name))
               (not (member ".." (split-string name "/" t)))
               (not (member "." (split-string name "/" t)))
               (not (string-match-p "//" name))
               (not (string-suffix-p "/" name)))
    (user-error "Use a project-relative artifact path without traversal"))
  (let ((extension (downcase (or (file-name-extension name) ""))))
    (unless (member extension glassmacs-r-artifacts--extensions)
      (user-error "Unsupported artifact extension: %s" extension)))
  name)

(defun glassmacs-r-artifacts--location (host directory relative)
  "Return artifact context for HOST/DIRECTORY/RELATIVE without connecting."
  (glassmacs-r-artifacts--validate-relative relative)
  (let* ((root (glassmacs-remote-r-directory host directory))
         (path (concat root relative)))
    (list :host host :directory directory :relative relative
          :root root :remote-path path)))

(defun glassmacs-r-artifacts--bounded-file (context)
  "Return a regular file in CONTEXT, rejecting symlink escapes and oversized data.
Only call this after explicit user action; TRAMP may connect to the host."
  (let* ((path (plist-get context :remote-path))
         (root (plist-get context :root)))
    (unless (file-regular-p path)
      (user-error "Remote artifact is not a regular file"))
    (unless (file-in-directory-p (file-truename path) (file-truename root))
      (user-error "Remote artifact resolves outside its project root"))
    (let ((size (file-attribute-size (file-attributes path))))
      (unless (and (integerp size) (<= size glassmacs-r-artifacts-max-bytes))
        (user-error "Remote artifact exceeds the configured size limit")))
    path))

(defun glassmacs-r-artifacts--record (context &optional session-id job-id)
  "Remember CONTEXT, with its explicit SESSION-ID or JOB-ID provenance."
  (let ((record (append (copy-sequence context)
                        (list :session session-id :job job-id :opened-at (float-time)))))
    (push record glassmacs-r-artifacts--history)
    (setq glassmacs-r-artifacts--history-position 0)
    record))

(defun glassmacs-r-artifacts-preview (host directory relative)
  "Explicitly preview a bounded artifact from SSH HOST using Emacs viewers."
  (interactive (list (glassmacs-remote--read-host)
                     (read-string "Remote project directory: " "/")
                     (read-string "Relative plot or artifact path: ")))
  (let* ((context (glassmacs-r-artifacts--location host directory relative))
         (path (glassmacs-r-artifacts--bounded-file context)))
    (glassmacs-r-artifacts--record context)
    (find-file-read-only path)))

(defun glassmacs-r-artifacts-download (host directory relative destination)
  "Copy a bounded remote artifact explicitly to local DESTINATION.
Never overwrite an existing local file or write to another TRAMP host."
  (interactive (list (glassmacs-remote--read-host)
                     (read-string "Remote project directory: " "/")
                     (read-string "Relative artifact path: ")
                     (read-file-name "Save local copy as: " nil nil nil)))
  (when (file-remote-p destination)
    (user-error "Artifact destination must be local"))
  (when (file-exists-p destination)
    (user-error "Artifact destination exists; choose a new filename"))
  (let* ((context (glassmacs-r-artifacts--location host directory relative))
         (path (glassmacs-r-artifacts--bounded-file context)))
    (copy-file path destination nil)
    (glassmacs-r-artifacts--record context)
    (when (called-interactively-p 'interactive)
      (message "Saved %s" destination))
    destination))

(defun glassmacs-r-artifacts-preview-session (session relative)
  "Preview RELATIVE artifact from an explicitly selected remote ESS SESSION."
  (interactive (list
                (progn (require 'glassmacs-sessions)
                       (glassmacs-sessions-resolve))
                (read-string "Relative R plot or artifact path: ")))
  (require 'glassmacs-sessions)
  (unless (glassmacs-r-session-remote-p session)
    (user-error "Selected R console is local; choose a remote session"))
  (let* ((location (glassmacs-r-session-execution-identity session))
         (host (plist-get location :host))
         (remote-directory (glassmacs-sessions--console-directory session))
         (local-directory (plist-get (glassmacs-remote-context remote-directory) :localname))
         (context (glassmacs-r-artifacts--location host local-directory relative))
         (path (glassmacs-r-artifacts--bounded-file context)))
    (glassmacs-r-artifacts--record context (glassmacs-session-id session))
    (find-file-read-only path)))

(defun glassmacs-r-artifacts-list-history ()
  "Display recorded artifact paths and explicit R session associations."
  (interactive)
  (with-current-buffer (get-buffer-create "*Glassmacs R Artifacts*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "Explicit artifact previews/downloads, most recent first.\n\n")
      (dolist (record glassmacs-r-artifacts--history)
        (insert (format "%s  %s  %s\n"
                        (or (plist-get record :session) "manual")
                        (plist-get record :host)
                        (plist-get record :relative))))
      (special-mode))
    (display-buffer (current-buffer))))

(provide 'glassmacs-r-artifacts)
;;; glassmacs-r-artifacts.el ends here
