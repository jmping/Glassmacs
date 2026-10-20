;;; glassmacs-sessions.el --- ESS session registry and R command queue -*- lexical-binding: t; -*-

;; Session lifecycle tracking and a conservative per-session FIFO queue for
;; R commands.  ESS keeps ownership of processes, buffers and process
;; filters; this file only observes ESS processes (via the `busy' process
;; property ESS maintains), sends through `ess-send-string', and polls with a
;; timer, so Emacs is never blocked waiting for R.
;;
;; Completion means "ESS reports R is back at its primary prompt".  It does
;; NOT mean the R code succeeded: R-level errors are not detected.  Any
;; situation where execution status cannot be established is recorded as
;; `uncertain' and is never replayed automatically.

(require 'cl-lib)
(require 'project)
(require 'subr-x)

(defgroup glassmacs-sessions nil
  "R session registry and command queue."
  :group 'glassmacs-r)

(defconst glassmacs-sessions-poll-interval 0.1
  "Seconds between nonblocking queue polls while work is outstanding.")

;;; Data model

(cl-defstruct (glassmacs-session (:constructor glassmacs-session--make)
                                 (:copier nil))
  id process buffer name directory
  (state 'ready)                        ; ready, terminated
  (paused nil)
  (entries nil)                         ; all entries, oldest first
  started-at ended-at)

(cl-defstruct (glassmacs-entry (:constructor glassmacs-entry--make)
                               (:copier nil))
  id session-id source origin
  (state 'pending)   ; pending running completed failed uncertain orphaned removed
  reason submitted-at started-at finished-at removed-at original-position)

(defvar glassmacs-sessions--list nil "Registered sessions, oldest first.")
(defvar glassmacs-sessions--counter 0)
(defvar glassmacs-sessions--entry-counter 0)
(defvar glassmacs-sessions--history nil
  "Newest-first list of lifecycle events (plists) for reproducibility.")
(defvar glassmacs-sessions--timer nil)
(defvar-local glassmacs-r-target-session nil
  "Session id explicitly selected for this buffer, or nil.")

(define-minor-mode glassmacs-r-target-indicator-mode
  "Show this buffer's explicitly selected R execution target."
  :lighter (:eval (glassmacs-r--target-lighter)))

(defun glassmacs-r--target-lighter ()
  "Return the modeline indicator for the current buffer's R target."
  (when glassmacs-r-target-session
    (let ((session (glassmacs-sessions-find glassmacs-r-target-session)))
      (format " R[%s%s]" glassmacs-r-target-session
              (if (and session
                       (eq (glassmacs-session-state session) 'ready)
                       (glassmacs-sessions--process-live-p
                        (glassmacs-session-process session)))
                  ""
                "!")))))

(defvar ess-process-name-list)
(defvar ess-local-process-name)
(defvar inferior-ess-r-program)
(defvar glassmacs-r-executable)

(defun glassmacs-sessions--record (kind &rest plist)
  "Record a history event of KIND with PLIST and a timestamp."
  (push (append (list :event kind :time (current-time)) plist)
        glassmacs-sessions--history))

(defun glassmacs-sessions-history ()
  "Return the execution history, oldest first."
  (reverse glassmacs-sessions--history))

;;; Sessions

(defun glassmacs-sessions--process-live-p (process)
  (and (processp process) (eq (process-status process) 'run)))

(defun glassmacs-sessions--process-busy-p (process)
  "Return non-nil when ESS marks PROCESS busy."
  (process-get process 'busy))

(defun glassmacs-sessions--send (process string)
  "Send STRING to PROCESS through ESS."
  (unless (fboundp 'ess-send-string)
    (error "ESS is unavailable"))
  ;; ESS's presend hooks consult buffer-local state of the process buffer.
  (with-current-buffer (process-buffer process)
    (funcall (intern "ess-send-string") process string)))

(defun glassmacs-sessions-find (id-or-process)
  "Return the session for ID-OR-PROCESS, or nil."
  (cl-find-if (lambda (s)
                (or (equal (glassmacs-session-id s) id-or-process)
                    (eq (glassmacs-session-process s) id-or-process)))
              glassmacs-sessions--list))

(defun glassmacs-sessions--watch (session)
  "Observe termination of SESSION without replacing ESS's sentinel."
  (let ((process (glassmacs-session-process session)))
    (when (processp process)
      (add-function :after (process-sentinel process)
                    (lambda (proc _event)
                      (let ((s (glassmacs-sessions-find proc)))
                        (when (and s (not (glassmacs-sessions--process-live-p proc)))
                          (glassmacs-sessions--terminate s))))))))

(defun glassmacs-sessions-register (process)
  "Register PROCESS as an R session (idempotent) and return the session."
  (or (glassmacs-sessions-find process)
      (let* ((buffer (process-buffer process))
             (session (glassmacs-session--make
                       :id (format "R-%d" (cl-incf glassmacs-sessions--counter))
                       :process process :buffer buffer
                       :name (process-name process)
                       :directory (and (buffer-live-p buffer)
                                       (buffer-local-value 'default-directory buffer))
                       :started-at (current-time))))
        (setq glassmacs-sessions--list
              (append glassmacs-sessions--list (list session)))
        (glassmacs-sessions--watch session)
        (glassmacs-sessions--record :session-started
                                    :session (glassmacs-session-id session))
        session)))

(defun glassmacs-sessions-refresh ()
  "Discover live ESS R processes and detect terminated ones.
Return the list of live sessions."
  (when (boundp 'ess-process-name-list)
    (dolist (entry ess-process-name-list)
      (let* ((name (if (consp entry) (car entry) entry))
             (process (and (stringp name) (get-process name))))
        (when (and (glassmacs-sessions--process-live-p process)
                   (glassmacs-sessions--r-process-p process))
          (glassmacs-sessions-register process)))))
  (dolist (s glassmacs-sessions--list)
    (when (and (eq (glassmacs-session-state s) 'ready)
               (not (glassmacs-sessions--process-live-p
                     (glassmacs-session-process s))))
      (glassmacs-sessions--terminate s)))
  (glassmacs-sessions-live))

(defun glassmacs-sessions--r-process-p (process)
  (let ((buffer (process-buffer process)))
    (or (not (buffer-live-p buffer))
        (not (boundp 'ess-dialect))
        (member (buffer-local-value 'ess-dialect buffer) '("R" nil)))))

(defun glassmacs-sessions-live ()
  "Return live registered sessions."
  (cl-remove-if-not
   (lambda (s) (and (eq (glassmacs-session-state s) 'ready)
                    (glassmacs-sessions--process-live-p
                     (glassmacs-session-process s))))
   glassmacs-sessions--list))

(defun glassmacs-sessions-ready-p (session)
  "Return non-nil when SESSION is live and at an idle prompt."
  (and (glassmacs-session-p session)
       (eq (glassmacs-session-state session) 'ready)
       (glassmacs-sessions--process-live-p (glassmacs-session-process session))
       (not (glassmacs-sessions--process-busy-p (glassmacs-session-process session)))))

(defun glassmacs-sessions--terminate (session)
  "Mark SESSION terminated, preserving its queue as unsafe-to-run records.
Running work becomes `uncertain'; pending work becomes `orphaned'.  Nothing is
deleted or replayed."
  (unless (eq (glassmacs-session-state session) 'terminated)
    (setf (glassmacs-session-state session) 'terminated
          (glassmacs-session-ended-at session) (current-time)
          (glassmacs-session-paused session) t)
    (dolist (e (glassmacs-session-entries session))
      (pcase (glassmacs-entry-state e)
        ('running
         (setf (glassmacs-entry-state e) 'uncertain
               (glassmacs-entry-reason e) "R terminated while running"
               (glassmacs-entry-finished-at e) (current-time))
         (glassmacs-sessions--record :uncertain :entry (glassmacs-entry-id e)
                                     :session (glassmacs-session-id session)))
        ('pending
         (setf (glassmacs-entry-state e) 'orphaned
               (glassmacs-entry-reason e) "R terminated before dispatch")
         (glassmacs-sessions--record :orphaned :entry (glassmacs-entry-id e)
                                     :session (glassmacs-session-id session)))))
    (glassmacs-sessions--record :session-terminated
                                :session (glassmacs-session-id session))))

(defun glassmacs-sessions--describe (session)
  (format "%s [%s] %s%s" (glassmacs-session-id session)
          (glassmacs-session-name session)
          (or (glassmacs-session-directory session) "")
          (if (glassmacs-session-paused session) " (paused)" "")))

(defun glassmacs-sessions-resolve (&optional session)
  "Return the session commands should go to, never guessing among several.
SESSION may be a session object or id.  Otherwise use the buffer's selected
session, the only live session, or the session matching ESS's
`ess-local-process-name'; with several candidates prompt interactively."
  (glassmacs-sessions-refresh)
  (let ((live (glassmacs-sessions-live)))
    (cond
     (session (or (glassmacs-sessions-find
                   (if (glassmacs-session-p session)
                       (glassmacs-session-id session) session))
                  (user-error "Unknown R session: %s" session)))
     (glassmacs-r-target-session
      (let ((target (glassmacs-sessions-find glassmacs-r-target-session)))
        (if (and target (memq target live))
            target
          (user-error "Selected R session %s is no longer live; clear or select its target explicitly"
                     glassmacs-r-target-session))))
     ((null live) (user-error "No live R session; start one with M-x glassmacs-r-start"))
     ((null (cdr live)) (car live))
     ((and (boundp 'ess-local-process-name) ess-local-process-name
           (cl-find-if (lambda (s) (equal (glassmacs-session-name s)
                                          ess-local-process-name))
                       live)))
     (t (glassmacs-sessions--prompt live)))))

(defun glassmacs-sessions--prompt (live)
  (when noninteractive
    (user-error "Several R sessions are live; select one explicitly"))
  (let* ((choices (mapcar (lambda (s) (cons (glassmacs-sessions--describe s) s)) live))
         (choice (completing-read "Send to R session: " choices nil t)))
    (or (cdr (assoc choice choices)) (user-error "No R session selected"))))

(defun glassmacs-r-select-session (id)
  "Select R session ID as the target for the current buffer."
  (interactive
   (list (let ((live (glassmacs-sessions-refresh)))
           (unless live (user-error "No live R session"))
           (glassmacs-session-id (glassmacs-sessions--prompt live)))))
  (let ((session (glassmacs-sessions-find id)))
    (unless (and session (eq (glassmacs-session-state session) 'ready)
                 (glassmacs-sessions--process-live-p
                  (glassmacs-session-process session)))
      (user-error "R session %s is not live" id)))
  (setq glassmacs-r-target-session id)
  (glassmacs-r-target-indicator-mode 1)
  (message "Buffer targets R session %s" id))

(defun glassmacs-r-clear-session-target ()
  "Clear the current buffer's explicit R target."
  (interactive)
  (setq glassmacs-r-target-session nil)
  (glassmacs-r-target-indicator-mode -1)
  (message "Cleared this buffer's R session target"))

(defun glassmacs-r-inspect-session ()
  "Display the selected or unambiguously resolved R session terminal."
  (interactive)
  (let ((session (glassmacs-sessions-resolve)))
   (unless (buffer-live-p (glassmacs-session-buffer session))
     (user-error "The terminal for R session %s no longer exists"
                 (glassmacs-session-id session)))
   (pop-to-buffer (glassmacs-session-buffer session))))

(defun glassmacs-r-inspect-directories ()
  "Display source, buffer, project, and selected R session directories.
This command does not query R or contact a remote host."
  (interactive)
  (let* ((source (and buffer-file-name (file-name-directory buffer-file-name)))
        (buffer-dir default-directory)
        (project-dir
         (and (not (file-remote-p default-directory))
              (fboundp 'project-current)
              (let ((project (project-current nil)))
                (and project (project-root project)))))
        (session (condition-case nil
                    (glassmacs-sessions-resolve)
                  (user-error nil)))
        (session-dir (and session (glassmacs-session-directory session)))
        (buffer (get-buffer-create "*Glassmacs R Directories*")))
   (with-current-buffer buffer
     (let ((inhibit-read-only t))
       (erase-buffer)
       (insert (format "Document directory: %s\n"
                       (or source "(untitled)")))
       (insert (format "Buffer default-directory: %s\n" buffer-dir))
       (insert (format "Project root: %s\n"
                       (or project-dir
                           (if (file-remote-p default-directory)
                               "(remote; not queried)"
                             "(not in a project)"))))
       (insert (format "R session: %s\n"
                       (if session (glassmacs-session-id session) "(not selected)")))
       (insert (format "R process directory at registration: %s\n"
                       (or session-dir "(unknown)")))
       (insert "\nNo live R getwd() query was made. Use "
               "`M-x glassmacs-r-show-r-working-directory' to request it explicitly.\n")
       (special-mode)))
   (display-buffer buffer)))

(defun glassmacs-r-show-r-working-directory ()
  "Explicitly ask the selected R session to print its current getwd()."
  (interactive)
  (glassmacs-queue-submit
   "cat(\"R getwd(): \", getwd(), \"\\n\", sep = \"\")" nil
   (list :buffer (buffer-name) :operation 'working-directory)))

(defun glassmacs-r-start-session ()
  "Start an ESS R session and register it; report missing R or ESS."
  (interactive)
  (unless (locate-library "ess-site")
    (user-error "ESS is unavailable; install the ess package first"))
  (unless (executable-find (or (and (boundp 'glassmacs-r-executable) glassmacs-r-executable)
                               (and (boundp 'inferior-ess-r-program) inferior-ess-r-program)
                               "R"))
    (user-error "R executable not found; install R or set glassmacs-r-executable"))
  (call-interactively (intern "R"))
  (let ((proc (and (boundp 'ess-local-process-name) ess-local-process-name
                   (get-process ess-local-process-name))))
    (if (glassmacs-sessions--process-live-p proc)
        (glassmacs-session-id (glassmacs-sessions-register proc))
      (user-error "R started but no live ESS process was found"))))

(defun glassmacs-r-list-sessions ()
  "Display registered R sessions."
  (interactive)
  (glassmacs-sessions-refresh)
  (with-current-buffer (get-buffer-create "*Glassmacs R Sessions*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (dolist (s glassmacs-sessions--list)
        (insert (format "%-6s %-10s %-10s pending:%d %s\n"
                        (glassmacs-session-id s) (glassmacs-session-state s)
                        (if (glassmacs-sessions-ready-p s) "idle" "-")
                        (length (glassmacs-queue-pending s))
                        (glassmacs-sessions--describe s))))
      (special-mode))
    (display-buffer (current-buffer))))

;;; Queue

(defun glassmacs-queue--entries (session states)
  (cl-remove-if-not (lambda (e) (memq (glassmacs-entry-state e) states))
                    (glassmacs-session-entries session)))

(defun glassmacs-queue-pending (session)
  "Return SESSION's pending entries in FIFO order."
  (glassmacs-queue--entries session '(pending)))

(defun glassmacs-queue-running (session)
  "Return SESSION's running entry, or nil."
  (car (glassmacs-queue--entries session '(running))))

(defun glassmacs-queue-find (id)
  "Return the entry with identifier ID across all sessions, or nil."
  (cl-loop for s in glassmacs-sessions--list
           for e = (cl-find id (glassmacs-session-entries s)
                            :key #'glassmacs-entry-id :test #'equal)
           when e return e))

(defun glassmacs-queue-submit (source &optional session origin)
  "Queue SOURCE (a complete R expression or region text) for SESSION.
Return the new entry.  SOURCE is copied without text properties so later
buffer edits cannot change it.  Signals a `user-error' (queueing nothing)
when no live target exists or SOURCE is blank."
  (unless (and (stringp source) (string-match-p "[^ \t\n\r]" source))
    (user-error "Nothing to send to R"))
  (let ((session (glassmacs-sessions-resolve session)))
    (unless (eq (glassmacs-session-state session) 'ready)
      (user-error "R session %s has terminated; command not queued"
                  (glassmacs-session-id session)))
    (let ((entry (glassmacs-entry--make
                  :id (format "cmd-%d" (cl-incf glassmacs-sessions--entry-counter))
                  :session-id (glassmacs-session-id session)
                  :source (substring-no-properties source)
                  :origin origin :submitted-at (current-time))))
      (setf (glassmacs-session-entries session)
            (append (glassmacs-session-entries session) (list entry)))
      (glassmacs-sessions--record :submitted :entry (glassmacs-entry-id entry)
                                  :session (glassmacs-session-id session)
                                  :source (glassmacs-entry-source entry))
      (glassmacs-sessions--pump session)
      (glassmacs-sessions--ensure-timer)
      entry)))

(defun glassmacs-sessions--finish (entry state reason)
  (setf (glassmacs-entry-state entry) state
        (glassmacs-entry-reason entry) reason
        (glassmacs-entry-finished-at entry) (current-time))
  (glassmacs-sessions--record state :entry (glassmacs-entry-id entry)
                              :session (glassmacs-entry-session-id entry)
                              :reason reason))

(defun glassmacs-sessions--pump (session)
  "Update SESSION's queue: detect completion, then dispatch at most one entry."
  (let ((process (glassmacs-session-process session))
        (running (glassmacs-queue-running session)))
    (when (and running (glassmacs-sessions--process-live-p process))
      (cond
       ((not (glassmacs-sessions--process-busy-p process))
        (glassmacs-sessions--finish running 'completed "R returned to its prompt")
        (setq running nil))
       ((process-get process 'sec-prompt)
        (glassmacs-sessions--finish
         running 'uncertain "R is at a continuation prompt (incomplete expression?)")
        (setf (glassmacs-session-paused session) t))))
    (cond
     ((not (glassmacs-sessions--process-live-p process))
      (glassmacs-sessions--terminate session))
     ((and (not (glassmacs-queue-running session))
           (not (glassmacs-session-paused session))
           (not (glassmacs-sessions--process-busy-p process)))
      (when-let ((next (car (glassmacs-queue-pending session))))
        (setf (glassmacs-entry-state next) 'running
              (glassmacs-entry-started-at next) (current-time))
        (condition-case err
            (progn (glassmacs-sessions--send process (glassmacs-entry-source next))
                   (glassmacs-sessions--record
                    :dispatched :entry (glassmacs-entry-id next)
                    :session (glassmacs-session-id session)))
          (error
           ;; A failed send may or may not have reached R: stop the queue and
           ;; keep the snapshot rather than retrying or dropping it.
           (glassmacs-sessions--finish next 'failed (error-message-string err))
           (setf (glassmacs-session-paused session) t)
           (message "Glassmacs: sending %s to R failed: %s"
                    (glassmacs-entry-id next) (error-message-string err)))))))))

(defun glassmacs-sessions--tick ()
  "Timer function: advance every session's queue; stop timer when idle."
  (dolist (s glassmacs-sessions--list)
    (unless (eq (glassmacs-session-state s) 'terminated)
      (glassmacs-sessions--pump s)))
  (unless (cl-some (lambda (s)
                     (and (eq (glassmacs-session-state s) 'ready)
                          (or (glassmacs-queue-running s)
                              (and (not (glassmacs-session-paused s))
                                   (glassmacs-queue-pending s)))))
                   glassmacs-sessions--list)
    (glassmacs-sessions--cancel-timer)))

(defun glassmacs-sessions--ensure-timer ()
  (unless (timerp glassmacs-sessions--timer)
    (setq glassmacs-sessions--timer
          (run-with-timer glassmacs-sessions-poll-interval
                          glassmacs-sessions-poll-interval
                          #'glassmacs-sessions--tick))))

(defun glassmacs-sessions--cancel-timer ()
  (when (timerp glassmacs-sessions--timer)
    (cancel-timer glassmacs-sessions--timer))
  (setq glassmacs-sessions--timer nil))

(defun glassmacs-queue-pause (session)
  "Pause SESSION so no further pending commands are dispatched."
  (interactive (list (glassmacs-sessions-resolve)))
  (setf (glassmacs-session-paused session) t)
  (glassmacs-sessions--record :paused :session (glassmacs-session-id session)))

(defun glassmacs-queue-resume (session)
  "Resume dispatching pending commands for a live SESSION."
  (interactive (list (glassmacs-sessions-resolve)))
  (unless (eq (glassmacs-session-state session) 'ready)
    (user-error "R session %s has terminated; its commands are not replayed"
                (glassmacs-session-id session)))
  (setf (glassmacs-session-paused session) nil)
  (glassmacs-sessions--record :resumed :session (glassmacs-session-id session))
  (glassmacs-sessions--pump session)
  (glassmacs-sessions--ensure-timer))

;;; Confirmed removal (the only path that discards pending commands)

(defun glassmacs-queue--preview (source)
  (let ((s (string-trim source)))
    (if (> (length s) 300) (concat (substring s 0 300) "...") s)))

(defun glassmacs-queue--ask (entries action)
  "Ask whether to remove ENTRIES for ACTION.  Return non-nil only on consent.
The default answer is \"Keep command\"; this function is the single
confirmation mechanism and is deliberately not user-configurable."
  (unless (or noninteractive (null entries))
    (with-current-buffer (get-buffer-create "*Glassmacs Queue Removal*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%s\n\nRemoving pending R commands may change the results of\nlater commands: execution order, object dependencies,\nrandom-number state and other side effects.\n\n" action))
        (dolist (e entries)
          (insert (format "Session %s, queue position %d, %s:\n  %s\n\n"
                          (glassmacs-entry-session-id e)
                          (or (glassmacs-entry-original-position e) 0)
                          (glassmacs-entry-id e)
                          (replace-regexp-in-string
                           "\n" "\n  " (glassmacs-queue--preview
                                         (glassmacs-entry-source e))))))
        (special-mode))
      (display-buffer (current-buffer)))
    (let ((answer (completing-read
                   (format "Remove %d pending command(s)? " (length entries))
                   '("Keep command" "Remove command") nil t nil nil
                   "Keep command")))
      (equal answer "Remove command"))))

(defun glassmacs-queue--remove-entries (entries action)
  "Remove pending ENTRIES after explicit confirmation; return removed entries.
Every discarding operation must call this function.  Declined or
non-interactive requests leave the queue untouched.  Confirmed removals are
kept as `removed' records with their original position and source."
  (let ((entries (cl-remove-if-not
                  (lambda (e) (eq (glassmacs-entry-state e) 'pending))
                  entries)))
    (when entries
      (dolist (e entries)
        (setf (glassmacs-entry-original-position e)
              (1+ (cl-position
                   e (glassmacs-queue-pending
                      (glassmacs-sessions-find (glassmacs-entry-session-id e)))))))
      (if (not (glassmacs-queue--ask entries action))
          (progn (message "Glassmacs: kept %d pending command(s)" (length entries))
                 nil)
        (dolist (e entries)
          ;; Re-check: the command may have been dispatched while asking.
          (when (eq (glassmacs-entry-state e) 'pending)
            (setf (glassmacs-entry-state e) 'removed
                  (glassmacs-entry-removed-at e) (current-time)
                  (glassmacs-entry-reason e) action)
            (glassmacs-sessions--record
             :removed :entry (glassmacs-entry-id e)
             :session (glassmacs-entry-session-id e)
             :position (glassmacs-entry-original-position e)
             :source (glassmacs-entry-source e) :action action)))
        (cl-remove-if-not (lambda (e) (eq (glassmacs-entry-state e) 'removed))
                          entries)))))

(defun glassmacs-queue-remove (id)
  "Remove the pending command ID after confirmation (not an interrupt)."
  (interactive
   (list (completing-read
          "Pending command: "
          (cl-loop for s in glassmacs-sessions--list
                   append (mapcar #'glassmacs-entry-id (glassmacs-queue-pending s)))
          nil t)))
  (let ((entry (glassmacs-queue-find id)))
    (unless (and entry (eq (glassmacs-entry-state entry) 'pending))
      (user-error "%s is not a pending command" id))
    (glassmacs-queue--remove-entries (list entry) "Remove pending command")))

(defun glassmacs-queue-remove-entries (ids)
  "Remove the pending commands in IDS after one confirmation."
  (interactive (list (completing-read-multiple
                      "Pending commands: "
                      (cl-loop for s in glassmacs-sessions--list
                               append (mapcar #'glassmacs-entry-id
                                              (glassmacs-queue-pending s)))
                      nil t)))
  (glassmacs-queue--remove-entries
   (delq nil (mapcar #'glassmacs-queue-find ids)) "Remove selected pending commands"))

(defun glassmacs-queue-clear (session)
  "Remove all pending commands of SESSION after confirmation."
  (interactive (list (glassmacs-sessions-resolve)))
  (glassmacs-queue--remove-entries (glassmacs-queue-pending session)
                                   "Clear pending queue"))

;;; Interrupt (distinct from removal)

(defun glassmacs-queue-interrupt (session)
  "Interrupt SESSION's running command, keeping all pending commands.
The interrupted command is recorded as `uncertain' and the queue is paused so
nothing further runs until you resume it."
  (interactive (list (glassmacs-sessions-resolve)))
  (let ((running (glassmacs-queue-running session)))
    (unless running (user-error "No running command in %s" (glassmacs-session-id session)))
    (unless (or noninteractive
                (y-or-n-p (format "Interrupt running command %s? Pending commands are kept and the queue is paused. "
                                  (glassmacs-entry-id running))))
      (user-error "Interrupt cancelled"))
    (setf (glassmacs-session-paused session) t)
    (glassmacs-sessions--finish running 'uncertain "interrupted by user")
    (if (glassmacs-sessions--process-live-p (glassmacs-session-process session))
        (interrupt-process (glassmacs-session-process session))
      (glassmacs-sessions--terminate session))))

;;; Inspection and submission commands

(defun glassmacs-queue-show (session)
  "Display all of SESSION's queue records."
  (interactive (list (glassmacs-sessions-resolve)))
  (with-current-buffer (get-buffer-create "*Glassmacs R Queue*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (format "Session %s%s\n\n" (glassmacs-sessions--describe session)
                      (if (eq (glassmacs-session-state session) 'terminated)
                          " TERMINATED" "")))
      (dolist (e (glassmacs-session-entries session))
        (insert (format "%-8s %-10s %s\n" (glassmacs-entry-id e)
                        (glassmacs-entry-state e)
                        (car (split-string (glassmacs-entry-source e) "\n")))))
      (special-mode))
    (display-buffer (current-buffer))))

(defun glassmacs-r-submit-region (start end)
  "Queue the explicit region START..END for an R session as one command."
  (interactive "r")
  (glassmacs-queue-submit
   (buffer-substring-no-properties start end) nil
   (list :buffer (buffer-name) :start start :end end)))

(defun glassmacs-r-submit-buffer ()
  "Queue the whole buffer for an R session as one command."
  (interactive)
  (glassmacs-r-submit-region (point-min) (point-max)))

(defun glassmacs-r-submit-region-to-session (start end)
  "Queue region START..END to an explicitly chosen live R session."
  (interactive "r")
  (let* ((live (glassmacs-sessions-refresh))
         (session (or (and live (glassmacs-sessions--prompt live))
                      (user-error "No live R session"))))
    (glassmacs-queue-submit
     (buffer-substring-no-properties start end) session
     (list :buffer (buffer-name) :start start :end end :one-off t))))

(provide 'glassmacs-sessions)
;;; glassmacs-sessions.el ends here
