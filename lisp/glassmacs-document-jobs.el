;;; glassmacs-document-jobs.el --- Research document job identities -*- lexical-binding: t; -*-

;; A small, process-independent contract for document builds.  This module
;; starts no processes, connects to no remote host and never replays work.
;; Local renderers, Shiny and remote durable jobs can adapt to these records
;; without sharing process ownership or changing upstream Emacs/ESS behavior.

(require 'cl-lib)
(require 'subr-x)
(require 'project)

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
    (unless (equal remote root-remote)
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

(provide 'glassmacs-document-jobs)
;;; glassmacs-document-jobs.el ends here
