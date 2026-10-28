;;; glassmacs-recovery.el --- Safe document buffer snapshots -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)

(defgroup glassmacs-recovery nil
  "Durable recovery for ordinary Glassmacs document buffers."
  :group 'glassmacs)

(defcustom glassmacs-preserve-open-buffers-on-quit nil
  "When non-nil, offer prompt-free quit after preserving document buffers."
  :type 'boolean :group 'glassmacs-recovery)

(defcustom glassmacs-recovery-directory
  (expand-file-name "Glassmacs/Recovery/"
                    (or (getenv "XDG_DATA_HOME")
                        (expand-file-name "~/Library/Application Support/")))
  "Directory for private recovery snapshots."
  :type 'directory :group 'glassmacs-recovery)

(defcustom glassmacs-recovery-interval 60
  "Seconds between best-effort snapshots of modified document buffers."
  :type 'integer :group 'glassmacs-recovery)

(defvar glassmacs-recovery--timer nil)
(defvar glassmacs-recovery--restoring nil)
(defvar-local glassmacs-recovery--id nil)

(defun glassmacs-recovery--eligible-p (&optional buffer)
  "Return non-nil if BUFFER is an ordinary local document buffer.
Never snapshot process buffers, remote files, or special buffers."
  (with-current-buffer (or buffer (current-buffer))
    (and (not (minibufferp))
         (not (get-buffer-process (current-buffer)))
         (not (derived-mode-p 'special-mode 'comint-mode 'term-mode))
         (not (string-prefix-p " " (buffer-name)))
         (not (string-prefix-p "*" (buffer-name)))
         (or (null buffer-file-name)
             (not (file-remote-p buffer-file-name)))
         (not (bound-and-true-p glassmacs-recovery-exclude)))))

(defun glassmacs-recovery--documents ()
  "Return eligible live buffers; include clean file-backed buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (and (glassmacs-recovery--eligible-p buffer)
            (or buffer-file-name (buffer-modified-p)))))
   (buffer-list)))

(defun glassmacs-recovery--ensure-directory ()
  "Create a private recovery directory or signal an error."
  (when (file-symlink-p glassmacs-recovery-directory)
    (error "Recovery directory must not be a symbolic link"))
  (make-directory glassmacs-recovery-directory t)
  (when (file-symlink-p glassmacs-recovery-directory)
    (error "Recovery directory must not be a symbolic link"))
  (set-file-modes glassmacs-recovery-directory #o700)
  (unless (file-writable-p glassmacs-recovery-directory)
    (error "Glassmacs recovery directory is not writable")))

(defun glassmacs-recovery--id ()
  "Return a stable unique identifier for the current live buffer."
  (or glassmacs-recovery--id
      (setq glassmacs-recovery--id
            (secure-hash 'sha256
                         (format "%s:%s:%s:%s"
                                 (emacs-pid) (float-time)
                                 (random most-positive-fixnum)
                                 (buffer-name))))))

(defun glassmacs-recovery--write-private (path content)
  "Atomically write CONTENT to PATH with owner-only permissions."
  (unless (and (equal (file-name-directory (expand-file-name path))
                      (file-name-as-directory
                       (expand-file-name glassmacs-recovery-directory)))
               (not (file-symlink-p path)))
    (error "Unsafe recovery destination: %s" path))
  (let ((temporary (make-temp-file
                    (expand-file-name ".pending-" glassmacs-recovery-directory))))
    (unwind-protect
        (progn
          (set-file-modes temporary #o600)
          (with-temp-buffer
            (insert content)
            (let ((coding-system-for-write 'utf-8-unix))
              (write-region (point-min) (point-max) temporary nil 'silent)))
          (rename-file temporary path t))
      (when (file-exists-p temporary)
        (delete-file temporary)))))

(defun glassmacs-recovery--snapshot (buffer)
  "Write a snapshot for modified eligible BUFFER and return its record."
  (with-current-buffer buffer
    (let* ((id (glassmacs-recovery--id))
           (dirty (buffer-modified-p))
           (path (and dirty (expand-file-name (concat id "-" (format-time-string "%Y%m%d%H%M%S%N") "-" (number-to-string (random most-positive-fixnum)) ".text")
                                             glassmacs-recovery-directory))))
      (when dirty
        (glassmacs-recovery--write-private
         path (buffer-substring-no-properties (point-min) (point-max))))
      (list :id id :name (buffer-name) :file buffer-file-name
            :modified dirty :snapshot (and dirty (file-name-nondirectory path))
            :time (float-time)))))

(defun glassmacs-recovery--manifest-path ()
  "Return the latest preserved-buffer manifest path."
  (expand-file-name "buffers.eldata" glassmacs-recovery-directory))

(defun glassmacs-recovery-preserve ()
  "Durably snapshot all eligible document buffers and record a manifest.
Return the number of recorded buffers.  Never write original documents."
  (interactive)
  (glassmacs-recovery--ensure-directory)
  (let* ((records (mapcar #'glassmacs-recovery--snapshot
                          (glassmacs-recovery--documents)))
         (print-length nil)
         (print-level nil))
    (glassmacs-recovery--write-private
     (glassmacs-recovery--manifest-path)
     (prin1-to-string (list :version 1 :buffers records)))
    (when (called-interactively-p 'interactive)
      (message "Preserved %d document buffers" (length records)))
    (length records)))

(defun glassmacs-recovery--read-manifest ()
  "Read the stored manifest as data, not executable Lisp."
  (let ((path (glassmacs-recovery--manifest-path)))
    (when (file-symlink-p path)
      (error "Refusing symlinked recovery manifest"))
    (when (file-readable-p path)
      (with-temp-buffer
        (insert-file-contents path)
        (let ((read-eval nil))
          (let ((data (read (current-buffer))))
            (skip-chars-forward " \t\r\n")
            (unless (eobp) (error "Trailing recovery manifest data"))
            data))))))

(defun glassmacs-recovery-restore-crash ()
  "Restore snapshots from the latest periodic crash-recovery index."
  (interactive)
  (let ((manifest (glassmacs-recovery--manifest-path))
        (crash (expand-file-name "crash.eldata" glassmacs-recovery-directory)))
    (unless (file-readable-p crash)
      (user-error "No crash-recovery index available"))
    (when (file-symlink-p crash)
      (user-error "Refusing symlinked crash index"))
    (let ((temporary (and (file-exists-p manifest)
                          (with-temp-buffer
                            (insert-file-contents manifest)
                            (buffer-string)))))
      (unwind-protect
          (progn
            (glassmacs-recovery--write-private
             manifest
             (with-temp-buffer (insert-file-contents crash) (buffer-string)))
            (glassmacs-recovery-restore))
        (if temporary
            (glassmacs-recovery--write-private manifest temporary)
          (when (file-exists-p manifest) (delete-file manifest)))))))

(defun glassmacs-recovery-restore ()
  "Restore preserved document buffers without executing process commands.
Unsaved edits are restored in separate untitled buffers; original files are
never overwritten.  Calling this repeatedly does not duplicate buffers."
  (interactive)
  (let* ((manifest (glassmacs-recovery--read-manifest))
         (records (plist-get manifest :buffers))
         (count 0))
    (unless (or (null manifest) (eq (plist-get manifest :version) 1))
      (user-error "Unsupported Glassmacs recovery manifest"))
    (let ((glassmacs-recovery--restoring t))
      (dolist (record records)
        (let* ((id (plist-get record :id))
               (name (plist-get record :name))
               (file (plist-get record :file))
               (dirty (plist-get record :modified))
               (snapshot (plist-get record :snapshot))
               (snapshot-path (and snapshot
                                   (expand-file-name snapshot
                                                     glassmacs-recovery-directory))))
          (when (and (stringp id) (stringp name)
                     (or (null file) (and (stringp file)
                                          (not (file-remote-p file))))
                     (not (cl-find id (buffer-list)
                                   :key (lambda (buffer)
                                          (buffer-local-value
                                           'glassmacs-recovery--id buffer))
                                   :test #'equal)))
            (cond
             ((and dirty (stringp snapshot)
                   (equal snapshot (file-name-nondirectory snapshot))
                   (not (file-symlink-p snapshot-path))
                   (file-readable-p snapshot-path))
              (let ((buffer (generate-new-buffer
                             (format "%s (Recovered)" name))))
                (with-current-buffer buffer
                  (insert-file-contents snapshot-path)
                  (setq-local glassmacs-recovery--id id)
                  (setq-local buffer-file-name nil)
                  (setq-local glassmacs-recovery-source-file file)
                  (set-buffer-modified-p t))
                (cl-incf count)))
             ((and (not dirty) file (file-readable-p file))
              (let ((buffer (find-file-noselect file)))
                (with-current-buffer buffer
                  (setq-local glassmacs-recovery--id id))
                (cl-incf count))))))))
    (when (called-interactively-p 'interactive)
      (message "Restored %d preserved document buffers" count))
    count))

(defun glassmacs-recovery-discard-preserved ()
  "Discard the active manifest after confirmation.
Snapshot files are retained for manual recovery until explicit cleanup."
  (interactive)
  (when (yes-or-no-p "Discard preserved buffer list? ")
    (let ((path (glassmacs-recovery--manifest-path)))
      (when (file-exists-p path) (delete-file path)))))

(defun glassmacs-recovery-toggle-preserve ()
  "Toggle the opt-in buffer-preservation quit policy and persist it."
  (interactive)
  (customize-save-variable
   'glassmacs-preserve-open-buffers-on-quit
   (not glassmacs-preserve-open-buffers-on-quit))
  (message "Preserve Open Buffers on Quit: %s"
           (if glassmacs-preserve-open-buffers-on-quit "on" "off")))

(defun glassmacs-recovery--startup ()
  "Offer preserved documents on startup; never execute saved commands."
  (when (and (not noninteractive)
             (file-readable-p (glassmacs-recovery--manifest-path))
             (y-or-n-p "Glassmacs has preserved document buffers. Restore them? "))
    (glassmacs-recovery-restore)))

(defun glassmacs-recovery-quit ()
  "Quit without per-document prompts only after successful preservation.
If preservation fails, remain in Emacs and display the error."
  (interactive)
  (if (not glassmacs-preserve-open-buffers-on-quit)
      (save-buffers-kill-emacs)
    (condition-case err
        (progn
          (glassmacs-recovery-preserve)
          ;; The built-in quit command prompts for modified buffers.
          ;; After a durable snapshot, suppress only that document prompt;
          ;; preserve other kill-emacs queries.
          (let ((buffer-offer-save nil)
                (save-silently t))
            (cl-letf (((symbol-function 'save-some-buffers)
                       (lambda (&rest _) nil)))
              (save-buffers-kill-emacs))))
      (error (message "Glassmacs quit canceled: %s" (error-message-string err))
             nil))))

(defun glassmacs-recovery--periodic-snapshot ()
  "Best-effort snapshots for crash recovery; do not replace quit manifest."
  (unless glassmacs-recovery--restoring
    (condition-case err
        (progn
          (glassmacs-recovery--ensure-directory)
          (let ((records nil))
            (dolist (buffer (glassmacs-recovery--documents))
              (when (buffer-modified-p buffer)
                (push (glassmacs-recovery--snapshot buffer) records)))
            (when records
              (glassmacs-recovery--write-private
               (expand-file-name "crash.eldata" glassmacs-recovery-directory)
               (prin1-to-string
                (list :version 1 :buffers (nreverse records)))))))
      (error (display-warning 'glassmacs-recovery
                              (error-message-string err) :warning)))))

(defun glassmacs-recovery-start ()
  "Enable periodic snapshots without modifying visited files."
  (interactive)
  (unless (timerp glassmacs-recovery--timer)
    (setq glassmacs-recovery--timer
          (run-with-idle-timer
           glassmacs-recovery-interval t
           #'glassmacs-recovery--periodic-snapshot))))

(add-hook 'emacs-startup-hook #'glassmacs-recovery--startup)
(glassmacs-recovery-start)

(provide 'glassmacs-recovery)
;;; glassmacs-recovery.el ends here
