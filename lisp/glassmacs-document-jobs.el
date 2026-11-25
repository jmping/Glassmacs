;;; glassmacs-document-jobs.el --- Research document job identities -*- lexical-binding: t; -*-

;; A small, process-independent contract for document builds.  This module
;; starts no processes, connects to no remote host and never replays work.
;; Local renderers, Shiny and remote durable jobs can adapt to these records
;; without sharing process ownership or changing upstream Emacs/ESS behavior.

(require 'cl-lib)
(require 'subr-x)
(require 'project)
(require 'tabulated-list)

(defgroup glassmacs-document-jobs nil
  "Document build context and lifecycle records."
  :group 'glassmacs)

(defcustom glassmacs-document-detect-project-root nil
  "When non-nil, attach local `project.el' roots to document contexts.
This is metadata only: it does not change working directories, choose
an R process or map remote paths.  Remote project probing is skipped."
  :type 'boolean
  :group 'glassmacs-document-jobs)

(cl-defstruct (glassmacs-document-context
               (:constructor glassmacs-document-context--make))
  "Snapshot describing one explicit document build target.
SOURCE and DIRECTORY are absolute file names.  LOCATION is `local' or
`remote', inferred only from SOURCE's TRAMP syntax.  PROJECT-ROOT is an
optional explicit absolute root in the same location.  TARGET-ID names a
selected execution target, if any; it does not authorize cross-host routing."
  source directory location project-root target-id)

(defun glassmacs-document-context-create (source &optional project-root target-id)
  "Snapshot SOURCE's directory and optional PROJECT-ROOT and TARGET-ID.
This is a path-only operation: it does not connect over TRAMP, inspect an R
process or infer an execution target.  Reject relative paths and a project
root in a different local/remote location."
  (unless (and (stringp source) (file-name-absolute-p source)
               (not (string-suffix-p "/" source)))
    (user-error "A document context requires an absolute source file"))
  (when (and project-root
             (not (and (stringp project-root)
                       (file-name-absolute-p project-root))))
    (user-error "A project root must be an absolute directory"))
  (let* ((remote (file-remote-p source))
         (root-remote (and project-root (file-remote-p project-root))))
    (when (and project-root (not (equal remote root-remote)))
      (user-error "Document and project root must have the same location"))
    (glassmacs-document-context--make
     :source source
     :directory (file-name-directory source)
     :location (if remote 'remote 'local)
     :project-root project-root
     :target-id target-id)))

(defun glassmacs-document-context-for-file (source &optional target-id)
  "Build SOURCE's context, optionally consulting local upstream project.el.
Project discovery is a local metadata hint only and never selects a remote
execution target or changes the document's working directory."
  (let ((root
         (when (and glassmacs-document-detect-project-root
                    (stringp source)
                    (file-name-absolute-p source)
                    (not (file-remote-p source)))
           (when-let* ((project (ignore-errors
                                 (project-current nil
                                                  (file-name-directory source)))))
             (ignore-errors (project-root project))))))
    (glassmacs-document-context-create source root target-id)))

(cl-defstruct (glassmacs-document-job
               (:constructor glassmacs-document-job--make))
  "A record of a document build, separate from any owned OS process.
KIND identifies the adapter (such as `rmarkdown' or `quarto').
STATUS is a conservative lifecycle marker.  An uncertain job must be
reconciled explicitly; this record never starts or replays work."
  id context kind status log-buffer output-file error process)

(defconst glassmacs-document-jobs--allowed-transitions
  '((pending . (running cancelled failed uncertain))
    (running . (succeeded failed cancelled uncertain))
    (uncertain . (succeeded failed cancelled)))
  "Allowed monotone document-job state transitions.
An adapter must supply evidence before resolving an uncertain job.")

(defun glassmacs-document-job-new (id context kind &optional log-buffer)
  "Create a pending job with ID, CONTEXT, KIND and optional LOG-BUFFER.
The caller owns ID uniqueness and any associated process.  No work starts."
  (unless (and (stringp id) (not (string= id "")))
    (user-error "Document job ID must be a nonempty string"))
  (unless (glassmacs-document-context-p context)
    (user-error "A document job requires an explicit document context"))
  (unless (symbolp kind)
    (user-error "Document job kind must be a symbol"))
  (glassmacs-document-job--make
   :id id :context context :kind kind :status 'pending
   :log-buffer log-buffer))

(defun glassmacs-document-job-transition (job status &optional output-file error)
  "Move JOB to STATUS, recording optional OUTPUT-FILE and ERROR.
Terminal states cannot be restarted.  In particular, `uncertain' cannot
transition back to `running' or `pending', preventing silent replay."
  (unless (glassmacs-document-job-p job)
    (user-error "Not a document job"))
  (let ((previous (glassmacs-document-job-status job)))
    (unless (memq status (alist-get previous
                                   glassmacs-document-jobs--allowed-transitions))
      (user-error "Invalid document job transition: %s to %s"
                  previous status))
    (setf (glassmacs-document-job-status job) status)
    (when output-file
      (setf (glassmacs-document-job-output-file job) output-file))
    (when error
      (setf (glassmacs-document-job-error job) error)))
  job)


;;; In-memory activity index and explicit, capability-scoped actions

(defconst glassmacs-document-jobs-limit 100
  "Maximum number of in-memory research job records retained per session.")

(defvar glassmacs-document-jobs--registry nil
  "Newest-first transient job records.  Never written to disk.")

(defun glassmacs-document-jobs-register (job)
  "Retain JOB for the session dashboard without changing its lifecycle.
Callers register only work they explicitly started.  No polling, file I/O,
process launch, remote connection or automatic job restoration occurs."
  (unless (glassmacs-document-job-p job)
    (user-error "Only a research job may be registered"))
  (when (cl-find (glassmacs-document-job-id job)
                 glassmacs-document-jobs--registry
                 :key #'glassmacs-document-job-id :test #'equal)
    (user-error "Research job ID already registered"))
  (push job glassmacs-document-jobs--registry)
  (when (> (length glassmacs-document-jobs--registry)
           glassmacs-document-jobs-limit)
    (setcdr (nthcdr (1- glassmacs-document-jobs-limit)
                    glassmacs-document-jobs--registry) nil))
  job)

(defun glassmacs-document-jobs-list ()
  "Return a fresh list of the current session's job records, newest first.
This is a shallow copy of the list, not a durable process registry."
  (copy-sequence glassmacs-document-jobs--registry))

(defun glassmacs-document-jobs--entries ()
  "Render immutable identifiers and current status for the dashboard."
  (mapcar
   (lambda (job)
     (list (glassmacs-document-job-id job)
           (vector
            (symbol-name (glassmacs-document-job-status job))
            (symbol-name (glassmacs-document-job-kind job))
            (glassmacs-document-job-id job)
            (glassmacs-document-context-source
             (glassmacs-document-job-context job))
            (or (glassmacs-document-job-output-file job) ""))))
   (glassmacs-document-jobs-list)))

(defvar glassmacs-document-jobs-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "g") #'glassmacs-document-jobs-refresh)
    (define-key map (kbd "RET") #'glassmacs-document-jobs-show-log)
    (define-key map (kbd "l") #'glassmacs-document-jobs-show-log)
    (define-key map (kbd "o") #'glassmacs-document-jobs-open-output)
    (define-key map (kbd "c") #'glassmacs-document-jobs-cancel)
    map)
  "Keys for the read-only research jobs dashboard.")

(define-derived-mode glassmacs-document-jobs-mode tabulated-list-mode "Glassmacs-Jobs"
  "Read-only in-session research activity, with explicitly requested actions."
  (setq tabulated-list-format
        [("Status" 12 t) ("Kind" 12 t) ("Job" 22 t)
         ("Source" 52 t) ("Output" 52 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-entries #'glassmacs-document-jobs--entries)
  (tabulated-list-init-header))

(defcustom glassmacs-document-jobs-display-placement
  'follow-preference
  "Where to present the research jobs dashboard and its retained logs.
On graphical macOS, 'follow-preference gives each utility an independent
native window.  'current-window uses ordinary Emacs display rules.
This option never changes process ownership or restarts a job."
  :type '(choice (const :tag "Native window on graphical macOS" follow-preference)
                 (const :tag "Standard Emacs display" current-window))
  :group 'glassmacs-document-jobs)

(defun glassmacs-document-jobs--display-auxiliary (buffer)
  "Present local utility BUFFER without replacing an active source document.
Only explicitly invoked commands reach this function.  Reuse an existing
suitable view; fall back to Emacs display in terminal sessions.  No job
state is changed, and no process or external viewer is started."
  (unless (buffer-live-p buffer)
    (user-error "Research utility buffer no longer exists"))
  (if (and (eq system-type 'darwin)
           (display-graphic-p)
           (eq glassmacs-document-jobs-display-placement 'follow-preference))
      (progn
        (require 'glassmacs-presentation-model)
        (or (glassmacs-presentation-find-suitable-view
             buffer 'open 'new-frame)
            (display-buffer-pop-up-frame
             buffer '((inhibit-same-window . t) (reusable-frames . nil)))))
    (display-buffer buffer)))

(defun glassmacs-document-jobs-show ()
  "Display opt-in local research jobs without starting or resuming any work.
The dashboard is a snapshot refreshed explicitly with g; it does not poll.
Only registered local document renders and Shiny apps are included.
Separate remote ESS and durable R jobs are not represented until accepted."
  (interactive)
  (let ((buffer (get-buffer-create "*Glassmacs Research Jobs*")))
    (with-current-buffer buffer
      (glassmacs-document-jobs-mode)
      (tabulated-list-print t))
    (glassmacs-document-jobs--display-auxiliary buffer)
    buffer))

(defun glassmacs-document-jobs-refresh ()
  "Refresh the read-only view; do not contact remote processes or filesystem."
  (interactive)
  (unless (derived-mode-p 'glassmacs-document-jobs-mode)
    (user-error "Not in the research jobs dashboard"))
  (tabulated-list-print t))

(defun glassmacs-document-jobs--selected ()
  "Return the exact row's live in-memory job record."
  (let ((id (tabulated-list-get-id)))
    (or (and id
             (cl-find id glassmacs-document-jobs--registry
                      :key #'glassmacs-document-job-id :test #'equal))
        (user-error "No registered research job selected"))))

(defun glassmacs-document-jobs-show-log ()
  "Explicitly show the selected job's retained log, if available."
  (interactive)
  (let ((buffer (glassmacs-document-job-log-buffer
                 (glassmacs-document-jobs--selected))))
    (unless (buffer-live-p buffer)
      (user-error "This job has no retained log"))
    (glassmacs-document-jobs--display-auxiliary buffer)))

(declare-function glassmacs-open-rendered-output "glassmacs-documents" (output))

(defun glassmacs-document-jobs-open-output ()
  "Explicitly open the selected completed local document output."
  (interactive)
  (let* ((job (glassmacs-document-jobs--selected))
         (output (glassmacs-document-job-output-file job)))
    (unless (and (eq (glassmacs-document-job-status job) 'succeeded)
                 (eq (glassmacs-document-context-location
                      (glassmacs-document-job-context job)) 'local)
                 (stringp output) (not (file-remote-p output)))
      (user-error "No completed local output available for this job"))
    (glassmacs-open-rendered-output output)))

(declare-function glassmacs-document-local-cancel "glassmacs-document-local" (job))
(declare-function glassmacs-shiny-stop "glassmacs-shiny" ())

(defun glassmacs-document-jobs-cancel ()
  "Confirm and cancel only the selected owned, running local process.
The dashboard never cancels an ESS process, an unverified remote job, or a
process it does not own.  Shiny continues to use its single-app owner."
  (interactive)
  (let* ((job (glassmacs-document-jobs--selected))
         (kind (glassmacs-document-job-kind job))
         (process (glassmacs-document-job-process job))
         (local (eq (glassmacs-document-context-location
                     (glassmacs-document-job-context job)) 'local)))
    (unless (and local (eq (glassmacs-document-job-status job) 'running)
                 (process-live-p process))
      (user-error "No safely cancellable local process for this job"))
    (cond
     ((and (eq kind 'shiny)
           (boundp 'glassmacs-shiny-job)
           (eq job glassmacs-shiny-job)
           (boundp 'glassmacs-shiny-process)
           (eq process glassmacs-shiny-process))
      (when (y-or-n-p "Stop the selected Shiny application? ")
        (glassmacs-shiny-stop)))
     ((and (memq kind '(rmarkdown quarto sweave))
           (fboundp 'glassmacs-document-local-cancel))
      (when (y-or-n-p "Cancel the selected local document build? ")
        (glassmacs-document-local-cancel job)))
     (t
      (user-error "No approved cancellation adapter for this job")))
    (when (derived-mode-p 'glassmacs-document-jobs-mode)
      (tabulated-list-print t))))

(provide 'glassmacs-document-jobs)
;;; glassmacs-document-jobs.el ends here
