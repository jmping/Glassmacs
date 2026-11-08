;;; glassmacs-recovery.el --- Safe document buffer snapshots -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)
(require 'json)

(defgroup glassmacs-recovery nil
  "Durable recovery for ordinary Glassmacs document buffers."
  :group 'glassmacs)

(defcustom glassmacs-preserve-open-buffers-on-quit nil
  "When non-nil, offer prompt-free quit after preserving document buffers."
  :type 'boolean :group 'glassmacs-recovery)

(defun glassmacs-recovery--default-directory ()
  "Return the recovery directory inside the configured Glassmacs home.
Use the same application-home policy as packages, preferences and workspace
state.  In particular, GLASSMACS_HOME must take precedence over XDG_DATA_HOME
so isolated test launches never inspect another application's snapshots."
  (expand-file-name
   "Recovery/"
   (if (boundp 'glassmacs-home)
       glassmacs-home
     (glassmacs--default-home))))

(defcustom glassmacs-recovery-directory
  (glassmacs-recovery--default-directory)
  "Directory for private recovery snapshots.
Defaults to Recovery/ within GLASSMACS_HOME (or the Glassmacs default
home).  Existing recovery directories are not moved or deleted."
  :type 'directory :group 'glassmacs-recovery)

(defcustom glassmacs-recovery-interval 60
  "Seconds between best-effort snapshots of modified document buffers."
  :type 'integer :group 'glassmacs-recovery)

(defcustom glassmacs-recovery-max-buffer-bytes (* 8 1024 1024)
  "Maximum UTF-8 bytes of a single dirty buffer eligible for a snapshot.
A larger dirty buffer blocks preserve-on-quit rather than being silently
omitted.  Clean file-backed buffers require no snapshot."
  :type 'integer :group 'glassmacs-recovery)

(defcustom glassmacs-recovery-max-total-bytes (* 256 1024 1024)
  "Maximum snapshot storage budget in bytes.
A quit that cannot safely fit within this budget fails closed.  Existing
snapshots are not silently deleted to make room."
  :type 'integer :group 'glassmacs-recovery)

(defvar glassmacs-recovery--timer nil)
(defvar glassmacs-recovery--last-snapshots (make-hash-table :test 'equal)
  "Cache of (buffer ID . (content hash . snapshot filename)).")
(defvar glassmacs-recovery--save-reviewed-quit nil
  "Dynamically bound when the normal Emacs save/review quit path is active.")
(defvar glassmacs-recovery--restoring-index nil
  "Dynamically bound recovery index used by the restore command.")

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

(defun glassmacs-recovery--storage-bytes ()
  "Return total bytes in regular files directly inside the recovery directory."
  (let ((total 0))
    (dolist (file (directory-files glassmacs-recovery-directory t
                                   directory-files-no-dot-files-regexp))
      (when (and (file-regular-p file) (not (file-symlink-p file)))
        (cl-incf total (file-attribute-size (file-attributes file)))))
    total))

(defun glassmacs-recovery--read-index (filename)
  "Read FILENAME safely as a recovery index, or return nil if absent."
  (let ((path (expand-file-name filename glassmacs-recovery-directory)))
    (when (file-symlink-p path)
      (error "Refusing symlinked recovery index: %s" filename))
    (when (file-readable-p path)
      (with-temp-buffer
        (insert-file-contents path)
        (let* ((read-eval nil)
               (data (read (current-buffer))))
          (skip-chars-forward " \t\r\n")
          (unless (and (eobp) (listp data)
                       (eq (plist-get data :version) 1)
                       (listp (plist-get data :buffers)))
            (error "Invalid recovery index: %s" filename))
          data)))))

(defun glassmacs-recovery--transaction-path ()
  "Return the durable in-flight recovery transaction path."
  (expand-file-name "transaction.eldata" glassmacs-recovery-directory))

(defun glassmacs-recovery--write-index-transaction (index records &optional windows)
  "Publish RECORDS to INDEX with an in-flight transaction marker.
A failed publication retains the marker, preventing reclamation."
  (glassmacs-recovery--require-clean-transaction)
  (let* ((target (expand-file-name index glassmacs-recovery-directory))
         (marker (glassmacs-recovery--transaction-path))
         (old (glassmacs-recovery--read-index index))
         (new (append (list :version 1 :buffers records)
                      (when windows (list :windows windows)))))
    (glassmacs-recovery--write-private
     marker (prin1-to-string
             (list :version 1 :index index :old old :new new)))
    (glassmacs-recovery--write-private target (prin1-to-string new))
    (delete-file marker)))

(defun glassmacs-recovery--transaction-pending-p ()
  "Return non-nil if an incomplete index transaction needs review."
  (let ((marker (glassmacs-recovery--transaction-path)))
    (or (file-exists-p marker) (file-symlink-p marker))))

(defun glassmacs-recovery--require-clean-transaction ()
  "Refuse cleanup while any recovery transaction may be incomplete."
  (when (glassmacs-recovery--transaction-pending-p)
    (error "Recovery transaction pending; review before reclaiming snapshots")))

(defun glassmacs-recovery-transaction-status ()
  "Report whether an interrupted recovery transaction needs review."
  (interactive)
  (message "%s" (if (glassmacs-recovery--transaction-pending-p)
                    "Recovery transaction pending: snapshots protected; do not clean"
                  "No pending recovery transaction")))

(defun glassmacs-recovery--protected-files ()
  "Return snapshot filenames referenced by either durable index.
Fail rather than collect if an index cannot be parsed."
  (let (names)
    (dolist (index '("buffers.eldata" "crash.eldata"))
      (dolist (record (plist-get (glassmacs-recovery--read-index index)
                                :buffers))
        (let ((name (plist-get record :snapshot)))
          (when (and (stringp name)
                     (equal name (file-name-nondirectory name)))
            (push name names)))))
    names))

(defun glassmacs-recovery--reclaimable-files ()
  "Return unreferenced snapshot files, never indexed recovery copies."
  (glassmacs-recovery--require-clean-transaction)
  (let ((protected (glassmacs-recovery--protected-files)))
    (cl-remove-if-not
     (lambda (file)
       (and (string-suffix-p ".text" file)
            (not (file-symlink-p file))
            (file-regular-p file)
            (not (member (file-name-nondirectory file) protected))))
     (directory-files glassmacs-recovery-directory t
                      directory-files-no-dot-files-regexp))))

(defun glassmacs-recovery-reclaim ()
  "Delete unreferenced snapshots only; preserve both recovery indexes.
Returns reclaimed bytes.  Never remove a file referenced by an index."
  (interactive)
  (glassmacs-recovery--ensure-directory)
  (let ((files (glassmacs-recovery--reclaimable-files))
        (bytes 0))
    (when (or (not (called-interactively-p 'interactive))
              (yes-or-no-p (format "Delete %d unreferenced snapshots? "
                                  (length files))))
      (dolist (file files)
        (cl-incf bytes (file-attribute-size (file-attributes file)))
        (delete-file file)))
    (when (called-interactively-p 'interactive)
      (message "Reclaimed %d bytes" bytes))
    bytes))

(defun glassmacs-recovery-storage-status ()
  "Report recovery storage usage and reclaimable snapshot space."
  (interactive)
  (glassmacs-recovery--ensure-directory)
  (let* ((used (glassmacs-recovery--storage-bytes))
         (files (glassmacs-recovery--reclaimable-files))
         (reclaimable (cl-loop for file in files
                               sum (file-attribute-size (file-attributes file)))))
    (message "Recovery storage: %d / %d bytes; reclaimable: %d bytes (%d files)"
             used glassmacs-recovery-max-total-bytes reclaimable
             (length files))))

(defun glassmacs-recovery--snapshot-reference (id hash)
  "Return an existing immutable snapshot filename for ID and HASH.
Only reuse snapshots that remain protected by a durable index."
  (let ((cached (gethash id glassmacs-recovery--last-snapshots)))
    (when (and cached (equal (car cached) hash)
               (member (cdr cached) (glassmacs-recovery--protected-files))
               (file-readable-p
                (expand-file-name (cdr cached) glassmacs-recovery-directory)))
      (cdr cached))))

(defun glassmacs-recovery--snapshot (buffer)
  "Snapshot dirty BUFFER, reusing an unchanged protected snapshot."
  (with-current-buffer buffer
    (let* ((id (glassmacs-recovery--id))
           (dirty (buffer-modified-p))
           (text (and dirty (buffer-substring-no-properties (point-min) (point-max))))
           (bytes (and dirty (string-bytes (encode-coding-string text 'utf-8))))
           (hash (and dirty (secure-hash 'sha256 text)))
           (reuse (and dirty (glassmacs-recovery--snapshot-reference id hash)))
           (filename (and dirty
                          (or reuse
                              (concat id "-" (format-time-string "%Y%m%d%H%M%S%N")
                                      "-" (number-to-string
                                           (random most-positive-fixnum))
                                      ".text")))))
      (when dirty
        (when (> bytes glassmacs-recovery-max-buffer-bytes)
          (error "Recovery snapshot for %s exceeds %d bytes; save or review before quit"
                 (buffer-name) glassmacs-recovery-max-buffer-bytes))
        (unless reuse
          (when (> (+ (glassmacs-recovery--storage-bytes) bytes)
                   glassmacs-recovery-max-total-bytes)
            (error "Recovery storage budget exhausted; save or review before quit"))
          (glassmacs-recovery--write-private
           (expand-file-name filename glassmacs-recovery-directory) text))
        (puthash id (cons hash filename) glassmacs-recovery--last-snapshots))
      (list :id id :name (buffer-name) :file buffer-file-name
            :modified dirty :snapshot filename :time (float-time)))))

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
    (glassmacs-recovery--write-index-transaction "buffers.eldata" records)
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

(defun glassmacs-recovery--safe-frame-dimension (value minimum maximum)
  "Return bounded integer VALUE for a recovered frame, or nil."
  (when (and (integerp value) (<= minimum value) (<= value maximum))
    value))

(defun glassmacs-recovery--restore-view (window record)
  "Restore WINDOW's point and scroll start from bounded data-only RECORD."
  (when (and (window-live-p window) (listp record))
    (let* ((buffer (window-buffer window))
           (limit (with-current-buffer buffer (point-max)))
           (point (plist-get record :point))
           (start (plist-get record :start)))
      (when (and (integerp point) (<= 1 point limit))
        (set-window-point window point))
      (when (and (integerp start) (<= 1 start limit))
        (set-window-start window start t)))))

(defun glassmacs-recovery--buffer-for-id (id)
  "Resolve a durable recovery ID to an existing live document buffer."
  (when (stringp id)
    (cl-find-if (lambda (candidate)
                  (and (buffer-live-p candidate)
                       (equal (buffer-local-value
                               'glassmacs-recovery--id candidate) id)))
                (buffer-list))))

(defun glassmacs-recovery--restore-tab (frame record)
  "Restore one document tab RECORD in FRAME, without starting processes.
Return non-nil if the tab has any recoverable documents."
  (when (and (listp record) (listp (plist-get record :buffers)))
    (let ((buffers (delq nil
                         (mapcar #'glassmacs-recovery--buffer-for-id
                                 (plist-get record :buffers)))))
      (when buffers
        (with-selected-frame frame
          (delete-other-windows)
          (set-window-buffer (selected-window) (car buffers))
          (dolist (buffer (cdr buffers))
            (condition-case nil
                (let ((window (split-window (selected-window) nil 'right)))
                  (set-window-buffer window buffer)
                  (select-window window))
              (error
               (display-buffer buffer))))
          (dolist (window (window-list frame 'never))
            (let* ((buffer (window-buffer window))
                   (id (and (buffer-live-p buffer)
                            (buffer-local-value
                             'glassmacs-recovery--id buffer)))
                   (view (cl-find id (plist-get record :views)
                                  :key (lambda (entry)
                                         (plist-get entry :id))
                                  :test #'equal)))
              (glassmacs-recovery--restore-view window view)))
          (let* ((selected-id (plist-get record :selected))
                 (selected (and (stringp selected-id)
                                (cl-find-if
                                 (lambda (window)
                                   (equal (buffer-local-value
                                           'glassmacs-recovery--id
                                           (window-buffer window))
                                          selected-id))
                                 (window-list frame 'never)))))
            (when selected (select-window selected))))
        t))))

(defun glassmacs-recovery--restore-window-layout (manifest)
  "Recreate saved document frames and tabs using bounded data-only records.
Legacy frame records without :tabs restore exactly one layout.  Missing
documents are skipped, without launching any R processes."
  (when (display-graphic-p)
    (dolist (record (plist-get manifest :windows))
      (when (listp record)
        (let* ((tabs (if (and (plist-member record :tabs)
                              (listp (plist-get record :tabs)))
                         (plist-get record :tabs)
                       (list record)))
               (recoverable (cl-remove-if-not
                             (lambda (tab)
                               (and (listp tab)
                                    (listp (plist-get tab :buffers))
                                    (cl-some #'glassmacs-recovery--buffer-for-id
                                             (plist-get tab :buffers))))
                             tabs))
               (width (glassmacs-recovery--safe-frame-dimension
                       (plist-get record :width) 20 500))
               (height (glassmacs-recovery--safe-frame-dimension
                        (plist-get record :height) 8 300))
               (left (glassmacs-recovery--safe-frame-dimension
                      (plist-get record :left) -10000 10000))
               (top (glassmacs-recovery--safe-frame-dimension
                     (plist-get record :top) -10000 10000))
               (active (plist-get record :active-tab)))
          (when recoverable
            (let ((frame (make-frame))
                  (restored-indices nil))
              (with-selected-frame frame
                (cl-loop for tab in tabs
                         for index from 1
                         when (memq tab recoverable)
                         do (progn
                              (when restored-indices
                                (require 'tab-bar)
                                (tab-bar-mode 1)
                                (tab-bar-new-tab))
                              (when (glassmacs-recovery--restore-tab frame tab)
                                (push index restored-indices))))
                (when (and (integerp active)
                           (memq active restored-indices)
                           (bound-and-true-p tab-bar-mode))
                  (tab-bar-select-tab
                   (1+ (cl-position active (reverse restored-indices)))))
                (when (and width height)
                  (condition-case nil
                      (set-frame-size frame width height)
                    (error nil)))
                (when (and left top)
                  (condition-case nil
                      (set-frame-position frame left top)
                    (error nil))))))))))

(defun glassmacs-recovery-restore-crash ()
  "Restore the crash index without modifying the preserved-buffer index."
  (interactive)
  (let ((glassmacs-recovery--restoring-index
         (or (glassmacs-recovery--read-index "crash.eldata")
             (user-error "No crash-recovery index available"))))
    (glassmacs-recovery-restore)))

(defun glassmacs-recovery-restore ()
  "Restore preserved document buffers without executing process commands.
Unsaved edits are restored in separate untitled buffers; original files are
never overwritten.  Calling this repeatedly does not duplicate buffers."
  (interactive)
  (let* ((manifest (or glassmacs-recovery--restoring-index
                       (glassmacs-recovery--read-manifest)))
         (records (plist-get manifest :buffers))
         (restored nil)
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
                (push buffer restored)
                (cl-incf count)))
             ((and (not dirty) file (file-readable-p file))
              (let ((buffer (find-file-noselect file)))
                (with-current-buffer buffer
                  (setq-local glassmacs-recovery--id id))
                (push buffer restored)
                (cl-incf count))))))))
    ;; On confirmed startup recovery, reconstruct visible document frames.
    ;; Older manifests have no :windows metadata and retain the original
    ;; interactive-only presentation behavior.
    (if (plist-get manifest :windows)
        (glassmacs-recovery--restore-window-layout manifest)
      (when (and (called-interactively-p 'interactive)
                 (display-graphic-p)
                 (fboundp 'glassmacs-present-buffer))
        (dolist (buffer (nreverse restored))
          (glassmacs-present-buffer buffer 'open 'new-frame))))
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

(defcustom glassmacs-recovery-quarantine-days 90
  "Minimum age in days before an unresolved recovery is reviewed for expiry."
  :type 'integer :group 'glassmacs-recovery)

(defcustom glassmacs-recovery-auto-expire-quarantine t
  "Whether twice-reviewed, unclaimed quarantine files may be removed at a later startup."
  :type 'boolean :group 'glassmacs-recovery)

(defvar glassmacs-recovery--quarantine-session-reviewed nil
  "Quarantine items reviewed during this interactive application session.")

(defun glassmacs-recovery--quarantine-path ()
  "Return the persistent quarantine review-state filename."
  (expand-file-name "quarantine.eldata" glassmacs-recovery-directory))

(defun glassmacs-recovery--quarantine-state ()
  "Return saved quarantine entries, rejecting malformed state."
  (let ((path (glassmacs-recovery--quarantine-path)))
    (when (file-symlink-p path)
      (error "Refusing symlinked quarantine state"))
    (if (not (file-exists-p path))
        nil
      (with-temp-buffer
        (insert-file-contents path)
        (let* ((read-eval nil)
               (data (read (current-buffer))))
          (skip-chars-forward " \t\r\n")
          (unless (and (eobp) (listp data)
                       (cl-every
                        (lambda (entry)
                          (and (listp entry)
                               (stringp (plist-get entry :name))
                               (numberp (plist-get entry :since))
                               (integerp (plist-get entry :reviews))
                               (<= 0 (plist-get entry :reviews) 2)
                               (or (null (plist-get entry :queued))
                                   (eq (plist-get entry :queued) t))))
                        data))
            (error "Invalid quarantine state; automatic expiry disabled"))
          data)))))

(defun glassmacs-recovery--quarantine-candidates ()
  "Find unreferenced snapshots and interrupted metadata for review.
Never classify active index references or symlinks as disposable."
  (glassmacs-recovery--ensure-directory)
  (let ((protected (glassmacs-recovery--protected-files))
        (pending (glassmacs-recovery--transaction-pending-p)))
    (cl-loop for file in (directory-files glassmacs-recovery-directory t
                                          directory-files-no-dot-files-regexp)
             for name = (file-name-nondirectory file)
             when (and (file-regular-p file) (not (file-symlink-p file))
                       (or (and (string-suffix-p ".text" name)
                                (not (member name protected)))
                           (and pending (equal name "transaction.eldata"))))
             collect name)))

(defun glassmacs-recovery--quarantine-review (&optional now)
  "Run a single interactive-startup review cycle at timestamp NOW.
No file is deleted until the startup after two unanswered reviews.
A positive retain decision resets the review count for the item."
  (when (and (not noninteractive) (display-graphic-p)
             (not glassmacs-recovery--quarantine-session-reviewed))
    (setq glassmacs-recovery--quarantine-session-reviewed t)
    (condition-case err
        (let* ((now (or now (float-time)))
               (candidates (glassmacs-recovery--quarantine-candidates))
               (state (glassmacs-recovery--quarantine-state))
               (next nil)
               (expired nil))
          (dolist (name candidates)
            (let* ((file (expand-file-name name glassmacs-recovery-directory))
                   (old (cl-find name state :key (lambda (e) (plist-get e :name))
                                 :test #'equal))
                   (since (if old (plist-get old :since)
                            (or (file-attribute-modification-time
                                 (file-attributes file))
                                (current-time))))
                   (since (if (numberp since) since (float-time since)))
                   (reviews (if old (plist-get old :reviews) 0))
                   (queued (and old (plist-get old :queued)))
                   (entry (list :name name :since since
                                :reviews reviews :queued queued)))
              (if (>= (- now since)
                      (* glassmacs-recovery-quarantine-days 86400))
                  (push entry expired)
                (push entry next))))
          (when expired
            (let ((choice (read-char-choice
                           (format
                            "%d expired recovery item(s): [r]etain, [d]etails, [n]ot now? "
                            (length expired))
                           '(?r ?d ?n))))
              (when (= choice ?d)
                (with-help-window "*Glassmacs Expired Recovery*"
                  (princ "Expired recovery candidates (no deletion yet):\n\n")
                  (dolist (entry expired)
                    (princ (format "%s — %d prior review(s)\n"
                                   (plist-get entry :name)
                                   (plist-get entry :reviews)))))
                (setq choice (read-char-choice
                              "Retain [r] or defer [n]? " '(?r ?n))))
              (dolist (entry expired)
                (cond
                 ((= choice ?r)
                  (setq entry (plist-put entry :since now))
                  (setq entry (plist-put entry :reviews 0))
                  (setq entry (plist-put entry :queued nil)))
                 ((and (plist-get entry :queued)
                       glassmacs-recovery-auto-expire-quarantine
                       (not (glassmacs-recovery--transaction-pending-p))
                       (not (member (plist-get entry :name)
                                    (glassmacs-recovery--protected-files)))
                       (not (cl-some
                             (lambda (buffer)
                               (with-current-buffer buffer
                                 (and (buffer-modified-p)
                                      (equal
                                       (cdr (gethash
                                             (glassmacs-recovery--id)
                                             glassmacs-recovery--last-snapshots))
                                       (plist-get entry :name)))))
                             (glassmacs-recovery--documents))))
                  ;; This is the third separate interactive startup.  Only
                  ;; delete exact regular, non-symlinked candidate files.
                  (let ((file (expand-file-name
                               (plist-get entry :name)
                               glassmacs-recovery-directory)))
                    (when (and (file-regular-p file) (not (file-symlink-p file)))
                      (delete-file file)
                      (setq entry nil))))
                 ((>= (plist-get entry :reviews) 1)
                  (setq entry (plist-put entry :reviews 2))
                  (setq entry (plist-put entry :queued t)))
                 (t (setq entry (plist-put entry :reviews 1))))
                (when entry (push entry next)))))
          (glassmacs-recovery--write-private
           (glassmacs-recovery--quarantine-path)
           (prin1-to-string (nreverse next))))
      (error (display-warning 'glassmacs-recovery
                              (format "Quarantine review skipped: %s"
                                      (error-message-string err))
                              :warning)))))

(defun glassmacs-recovery--startup ()
  "Offer preserved documents or crash snapshots on startup."
  (unless noninteractive
    (when (glassmacs-recovery--transaction-pending-p)
      (display-warning 'glassmacs-recovery
                       "Interrupted recovery transaction: automatic cleanup disabled"
                       :warning))
    (glassmacs-recovery--quarantine-review)
    (let ((manifest (glassmacs-recovery--manifest-path))
          (crash (expand-file-name "crash.eldata" glassmacs-recovery-directory)))
      (cond
       ((and (file-readable-p manifest)
             (y-or-n-p "Glassmacs has preserved document buffers. Restore them? "))
        (glassmacs-recovery-restore))
       ((and (file-readable-p crash)
             (y-or-n-p "Glassmacs has crash-recovery snapshots. Review them? "))
        (glassmacs-recovery-restore-crash))))))

(defun glassmacs-recovery--native-quit-decision (buffer)
  "Return (ACTION . APPLY-ALL) from a fresh macOS alert for BUFFER.
The checkbox is created anew, with state explicitly set to zero.  If
the native dialog cannot run, return nil and use the safe fallback."
  (let* ((open (executable-find "open"))
         (helper-app (expand-file-name
                      "../Helpers/GlassmacsQuitAlert.app" invocation-directory))
         (helper (expand-file-name "Contents/MacOS/GlassmacsQuitAlert"
                                   helper-app)))
    (when (and (eq system-type 'darwin) (display-graphic-p))
      (cond
       ((not open)
        (message "Glassmacs native quit helper unavailable: `open' was not found")
        nil)
       ((not (file-executable-p helper))
        (message "Glassmacs native quit helper is not executable: %s" helper)
        nil)
       (t
        (let ((response-file (make-temp-file "glassmacs-quit-response-"))
              (output (generate-new-buffer " *glassmacs-quit-helper*")))
        (unwind-protect
            (condition-case err
                (let ((status (process-file open nil output nil "-n" "-W" "-a"
                                            helper-app "--args" response-file
                                            (buffer-name buffer))))
                  (if (and (zerop status) (file-readable-p response-file))
                      (with-temp-buffer
                        (let ((json-object-type 'alist))
                          (insert-file-contents response-file)
                          (goto-char (point-min))
                          (let* ((response (json-read))
                                 (error-text (cdr (assq 'error response)))
                                 (action (cdr (assq 'action response)))
                                 (all (cdr (assq 'all response))))
                            (cond
                             (error-text
                              (message "Glassmacs native quit helper failed: %s" error-text)
                              nil)
                             ((member action '("save" "discard" "cancel"))
                              (cons (intern action) (eq all t)))
                             (t
                              (message "Glassmacs native quit helper returned an invalid action")
                              nil)))))
                    (message "Glassmacs native quit helper failed (status %s): %s"
                             status
                             (with-current-buffer output
                               (string-trim (buffer-string))))
                    nil))
              (error
               (message "Glassmacs native quit helper failed: %s"
                         (error-message-string err))
               nil))
          (ignore-errors (delete-file response-file))
          (kill-buffer output))))))))

(defun glassmacs-recovery--quit-decision (buffer)
  "Ask about BUFFER; the scope checkbox defaults unchecked each time.
A non-native fallback asks scope separately, defaulting to current file."
  (or (glassmacs-recovery--native-quit-decision buffer)
      (let* ((action
              (pcase (condition-case nil
                         (car (read-multiple-choice
                               (format "Save changes to %s? " (buffer-name buffer))
                               '((?s "Save" "Save this document")
                                 (?d "Don't Save" "Discard changes on quit")
                                 (?c "Cancel" "Keep Glassmacs open"))))
                       (quit ?c))
                (?s 'save) (?d 'discard) (_ 'cancel)))
             (all (and (not (eq action 'cancel))
                       (eq (condition-case nil
                               (car (read-multiple-choice
                                     "Apply this choice to all remaining documents? "
                                     '((?n "No" "Only this document")
                                       (?y "Yes" "All remaining documents"))))
                             ;; Never broaden the decision on a dismissed or
                             ;; failed scope prompt.
                             ((quit error) ?n))
                           ?y))))
        (cons action all))))

(defun glassmacs-recovery--quit-reviewed ()
  "Review modified documents individually; never reuse checkbox state.
Discard decisions are staged until quit, and restored if quit is vetoed."
  (let ((dirty (cl-remove-if-not #'buffer-modified-p
                                  (glassmacs-recovery--documents)))
        (discard nil)
        (apply-action nil)
        (cancelled nil))
    (catch 'cancel
      (dolist (buffer dirty)
        (when (and (buffer-live-p buffer) (buffer-modified-p buffer))
          (let* ((decision (if apply-action
                               (cons apply-action nil)
                             (glassmacs-recovery--quit-decision buffer)))
                 (action (car decision)))
            (when (eq action 'cancel)
              (setq cancelled t)
              (throw 'cancel nil))
            (when (cdr decision)
              (setq apply-action action))
            (pcase action
              ('save
               (condition-case err
                   (with-current-buffer buffer
                     (save-buffer)
                     (when (buffer-modified-p)
                       (error "Document remains modified")))
                 ((error quit)
                  (message "Quit canceled: %s" (error-message-string err))
                  (setq cancelled t)
                  (throw 'cancel nil))))
              ('discard (push buffer discard))
              (_ (setq cancelled t) (throw 'cancel nil)))))))
    (if cancelled
        (progn (message "Quit canceled") nil)
      (unwind-protect
          (progn
            (dolist (buffer discard)
              (when (buffer-live-p buffer)
                (with-current-buffer buffer (set-buffer-modified-p nil))))
            ;; Suppress Emacs's nine-choice prompt only after every document
            ;; has been reviewed; other quit hooks still run.
            (cl-letf (((symbol-function 'save-some-buffers)
                       (lambda (&rest _) nil)))
              (let ((glassmacs-recovery--save-reviewed-quit t))
                (save-buffers-kill-emacs))))
        (dolist (buffer discard)
          (when (buffer-live-p buffer)
            (with-current-buffer buffer (set-buffer-modified-p t))))))))

(defun glassmacs-recovery-quit ()
  "Quit without per-document prompts only after successful preservation.
If preservation fails, remain in Emacs and display the error."
  (interactive)
  (if (not glassmacs-preserve-open-buffers-on-quit)
      (glassmacs-recovery--quit-reviewed)
    (condition-case err
        (progn
          (glassmacs-recovery-preserve)
          ;; The built-in quit command prompts for modified buffers.
          ;; After a durable snapshot, suppress only that document prompt;
          ;; preserve other kill-emacs queries.
          (let ((buffer-offer-save nil)
                (save-silently t)
                (glassmacs-recovery--save-reviewed-quit t))
            (cl-letf (((symbol-function 'save-some-buffers)
                       (lambda (&rest _) nil)))
              (save-buffers-kill-emacs))))
      (error (message "Glassmacs quit canceled: %s" (error-message-string err))
             nil))))

(defun glassmacs-recovery--quit-safety-check ()
  "Prevent native or alternate quit paths from silently losing dirty documents.
This hook runs for `kill-emacs' even if Cocoa bypasses Command-Q.
When preservation is enabled, commit a fresh recovery index before allowing
termination; when disabled, refuse a direct dirty-buffer termination."
  (let ((dirty (cl-remove-if-not #'buffer-modified-p
                                  (glassmacs-recovery--documents))))
    (cond
     ((null dirty) t)
     (glassmacs-preserve-open-buffers-on-quit
      (condition-case err
          (progn (glassmacs-recovery-preserve) t)
        (error (message "Glassmacs blocked quit: %s"
                        (error-message-string err))
               nil)))
     (glassmacs-recovery--save-reviewed-quit t)
     (t
      (message "Glassmacs blocked direct quit with unsaved documents; use Save/Review or Quit Glassmacs")
      nil))))

(defun glassmacs-recovery--reviewed-quit-advice (original &rest args)
  "Route native direct quit calls through Glassmacs review.
ORIGINAL and ARGS are used only for the guarded, already-reviewed quit."
  (if glassmacs-recovery--save-reviewed-quit
      (apply original args)
    (glassmacs-recovery-quit)))

(advice-add 'save-buffers-kill-emacs :around
            #'glassmacs-recovery--reviewed-quit-advice)
(advice-add 'kill-emacs :around
            #'glassmacs-recovery--reviewed-quit-advice)
(add-hook 'kill-emacs-query-functions #'glassmacs-recovery--quit-safety-check)

(defun glassmacs-recovery--tab-window-record (frame)
  "Snapshot the current tab of FRAME using only document identifiers.
A tab without recoverable documents is omitted; R processes and special
buffers are not serialized or restarted."
  (let* ((windows (window-list frame 'never))
         (buffers (cl-remove-duplicates
                   (cl-loop for window in windows
                            for buffer = (window-buffer window)
                            when (glassmacs-recovery--eligible-p buffer)
                            collect (with-current-buffer buffer
                                      (glassmacs-recovery--id)))
                   :test #'equal)))
    (when buffers
      (list :buffers buffers
            :selected (let ((selected (window-buffer
                                       (frame-selected-window frame))))
                        (when (glassmacs-recovery--eligible-p selected)
                          (with-current-buffer selected
                            (glassmacs-recovery--id))))
            :views (cl-loop for window in windows
                            for buffer = (window-buffer window)
                            when (glassmacs-recovery--eligible-p buffer)
                            collect (list :id (with-current-buffer buffer
                                                (glassmacs-recovery--id))
                                          :point (window-point window)
                                          :start (window-start window)))))))

(defun glassmacs-recovery--frame-tab-records (frame)
  "Collect every recoverable tab in FRAME without changing final selection."
  (with-selected-frame frame
    (if (not (and (bound-and-true-p tab-bar-mode)
                  (> (length (funcall tab-bar-tabs-function frame)) 1)))
        (list (glassmacs-recovery--tab-window-record frame))
      (let ((original (1+ (tab-bar--current-tab-index)))
            (count (length (funcall tab-bar-tabs-function frame)))
            records)
        (unwind-protect
            (dotimes (index count)
              (tab-bar-select-tab (1+ index))
              (push (glassmacs-recovery--tab-window-record frame) records))
          (tab-bar-select-tab original))
        (nreverse records)))))

(defun glassmacs-recovery--open-window-records ()
  "Record recoverable document tabs in visible frames without process data.
The :tabs field preserves tab order, including tabs without documents;
:active-tab preserves the selected tab.  Legacy :buffers, :selected and
:views fields mirror the selected tab for older recovery consumers."
  (let (records)
    (dolist (frame (frame-list))
      (when (and (frame-live-p frame) (frame-visible-p frame)
                 (not (frame-parameter frame 'minibuffer-only)))
        (let* ((tabs (glassmacs-recovery--frame-tab-records frame))
               (active (if (and (bound-and-true-p tab-bar-mode)
                                (> (length tabs) 1))
                           (with-selected-frame frame
                             (1+ (tab-bar--current-tab-index)))
                         1))
               (selected (nth (1- active) tabs)))
          (when (cl-some #'identity tabs)
            (push (list :buffers (plist-get selected :buffers)
                        :left (frame-parameter frame 'left)
                        :top (frame-parameter frame 'top)
                        :width (frame-width frame)
                        :height (frame-height frame)
                        :selected (plist-get selected :selected)
                        :views (plist-get selected :views)
                        :tabs tabs :active-tab active)
                  records)))))
    (nreverse records)))

(defun glassmacs-recovery--periodic-snapshot ()
  "Best-effort snapshots for crash recovery; do not replace quit manifest."
  (unless glassmacs-recovery--restoring
    (condition-case err
        (progn
          (glassmacs-recovery--ensure-directory)
          (let ((records nil)
                (windows (glassmacs-recovery--open-window-records)))
            ;; Include clean, file-backed documents so a forced quit can
            ;; reconstruct visible source windows, not just dirty snapshots.
            (dolist (buffer (glassmacs-recovery--documents))
              (when (or (buffer-modified-p buffer)
                        (and (buffer-file-name buffer)
                             (not (file-remote-p (buffer-file-name buffer)))))
                (push (glassmacs-recovery--snapshot buffer) records)))
            (when (or records windows)
              (glassmacs-recovery--write-index-transaction
               "crash.eldata" (nreverse records) windows))))
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
