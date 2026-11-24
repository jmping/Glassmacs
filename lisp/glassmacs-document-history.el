;;; glassmacs-document-history.el --- Opt-in local build output index -*- lexical-binding: t; -*-

;; This is metadata, not a process registry.  It never starts a renderer,
;; reconnects SSH, replays code or opens a remembered output automatically.

(require 'json)
(require 'cl-lib)
(require 'glassmacs-core)
(require 'glassmacs-document-jobs)

(defgroup glassmacs-document-history nil
  "Remember explicitly produced local document outputs."
  :group 'glassmacs)

(defcustom glassmacs-document-remember-build-outputs nil
  "When non-nil, remember successful LOCAL document build outputs.
The private index contains source/output paths, renderer kind and time;
it contains no source code, job logs, credentials or remote job details.
Restored output paths are never opened without a user command."
  :type 'boolean
  :group 'glassmacs-document-history)

(defconst glassmacs-document-history-file-name "document-build-outputs.json")
(defconst glassmacs-document-history-limit 100)
(defconst glassmacs-document-history-max-bytes 1048576)

(defun glassmacs-document-history--file ()
  "Return the local private build-output index location."
  (expand-file-name glassmacs-document-history-file-name glassmacs-home))

(defun glassmacs-document-history--local-path-p (path)
  "Whether PATH is a syntactically absolute, local file name."
  (and (stringp path) (file-name-absolute-p path) (not (file-remote-p path))))

(defun glassmacs-document-history--read ()
  "Read the validated private index, or return nil if absent.
A malformed existing index is left untouched and reported as an error."
  (let ((file (glassmacs-document-history--file)))
    (when (file-exists-p file)
      (when (> (file-attribute-size (file-attributes file))
               glassmacs-document-history-max-bytes)
        (user-error "Document build index exceeds its size limit"))
      (let* ((json-object-type 'alist)
             (json-array-type 'list)
             (json-key-type 'symbol)
             (data (condition-case err
                       (with-temp-buffer
                         (insert-file-contents file)
                         (json-read-from-string (buffer-string)))
                     (error
                      (user-error "Cannot read document build index: %s"
                                  (error-message-string err)))))
             (entries (alist-get 'entries data)))
        (unless (and (equal (alist-get 'version data) 1)
                     (listp entries)
                     (<= (length entries) glassmacs-document-history-limit)
                     (cl-every
                      (lambda (entry)
                        (and (listp entry)
                             (glassmacs-document-history--local-path-p
                              (alist-get 'source entry))
                             (glassmacs-document-history--local-path-p
                              (alist-get 'output entry))
                             (stringp (alist-get 'kind entry))
                             (stringp (alist-get 'time entry))))
                      entries))
          (user-error "Invalid document build index format"))
        entries))))

(defun glassmacs-document-history--write (entries)
  "Atomically write bounded ENTRIES to a mode-0600 index."
  (let* ((file (glassmacs-document-history--file))
         (directory (file-name-directory file))
         temp)
    (make-directory directory t)
    (unwind-protect
        (progn
          (setq temp (make-temp-file (expand-file-name ".document-builds-" directory)))
          (set-file-modes temp #o600)
          (with-temp-file temp
            (insert (json-encode
                     (list (cons 'version 1)
                           (cons 'entries (vconcat entries)))))
            (insert "\n"))
          (when (> (file-attribute-size (file-attributes temp))
                   glassmacs-document-history-max-bytes)
            (user-error "Document build index would exceed its size limit"))
          (rename-file temp file t)
          (setq temp nil)
          (set-file-modes file #o600))
      (when (and temp (file-exists-p temp))
        (delete-file temp)))))

(defun glassmacs-document-history-record (job)
  "Remember JOB's successful local source/output association if opted in.
Refuse to record remote jobs or paths; never serialize commands or logs."
  (when glassmacs-document-remember-build-outputs
    (unless (and (glassmacs-document-job-p job)
                 (eq (glassmacs-document-job-status job) 'succeeded))
      (user-error "Only successful document jobs can be remembered"))
    (let* ((context (glassmacs-document-job-context job))
           (source (glassmacs-document-context-source context))
           (output (glassmacs-document-job-output-file job)))
      (unless (and (eq (glassmacs-document-context-location context) 'local)
                   (glassmacs-document-history--local-path-p source)
                   (glassmacs-document-history--local-path-p output))
        (user-error "Only local document outputs can be remembered"))
      (let* ((previous (glassmacs-document-history--read))
             (entry (list (cons 'source source)
                          (cons 'output output)
                          (cons 'kind (symbol-name
                                       (glassmacs-document-job-kind job)))
                          (cons 'time (format-time-string "%FT%TZ" nil t))))
             (rest (cl-remove source previous
                              :key (lambda (item) (alist-get 'source item))
                              :test #'equal)))
        (glassmacs-document-history--write
         (cl-subseq (cons entry rest) 0
                    (min glassmacs-document-history-limit
                         (1+ (length rest)))))))))

(defun glassmacs-document-history-find (source)
  "Return remembered local output path for exact SOURCE, or nil.
Does not probe or open the output file."
  (when (glassmacs-document-history--local-path-p source)
    (alist-get 'output
               (cl-find source (glassmacs-document-history--read)
                        :key (lambda (entry) (alist-get 'source entry))
                        :test #'equal))))

(provide 'glassmacs-document-history)
;;; glassmacs-document-history.el ends here
