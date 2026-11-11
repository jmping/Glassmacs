;;; glassmacs-r-queue.el --- Inspect and control an R session's queue -*- lexical-binding: t; -*-

;; The queue inspector shows one R session: whether it is running, idle,
;; paused (and why) or waiting for the rest of an incomplete expression;
;; the running command; the pending commands in the order they will run,
;; marking those held since an interrupt; and recent results.  Its buttons
;; and keys call the same queue functions as the R menu, the Signals menu
;; and the toolbar, so every surface agrees about what happens to R.
;;
;; The inspector never changes the queue on its own.  It refreshes when
;; `glassmacs-queue-changed-functions' reports a recorded transition.

(require 'cl-lib)
(require 'subr-x)
(require 'glassmacs-sessions)

(defgroup glassmacs-r-queue nil
  "Inspecting and controlling R command queues."
  :group 'glassmacs-sessions)

(defcustom glassmacs-queue-inspector-recent-count 10
  "How many finished commands the queue inspector lists after the queue."
  :type 'natnum
  :group 'glassmacs-r-queue)

(defvar-local glassmacs-queue-inspector--session-id nil
  "Id of the R session shown in this queue inspector buffer.")

(defvar-local glassmacs-queue-inspector--refresh-timer nil
  "Pending coalesced refresh of this inspector, or nil.")

(defun glassmacs-queue-inspector--buffer-name (session)
  "Return the inspector buffer name for SESSION."
  (format "*R Queue: %s*" (glassmacs-session-id session)))

(defun glassmacs-queue-inspector--session ()
  "Return this inspector's session, or signal a `user-error'."
  (or (and glassmacs-queue-inspector--session-id
           (glassmacs-sessions-find glassmacs-queue-inspector--session-id))
      (user-error "This R session is no longer registered")))

(defun glassmacs-queue-inspector--entry-at-point ()
  "Return the queue entry on the current line, or nil."
  (when-let* ((id (get-text-property (line-beginning-position)
                                     'glassmacs-queue-entry)))
    (glassmacs-queue-find id)))

(defun glassmacs-queue-inspector--pending-at-point ()
  "Return the pending entry on the current line or signal a `user-error'."
  (let ((entry (glassmacs-queue-inspector--entry-at-point)))
    (unless (and entry (eq (glassmacs-entry-state entry) 'pending))
      (user-error "Move to a pending command first"))
    entry))

(defun glassmacs-queue-inspector--first-line (source)
  "Return the first non-blank line of SOURCE, noting further lines."
  (let* ((lines (split-string (string-trim source) "\n"))
         (more (length (cdr lines))))
    (concat (car lines)
            (if (> more 0) (format "  … (+%d line%s)" more (if (= more 1) "" "s")) ""))))

(defun glassmacs-queue-inspector--state-label (entry)
  "Return ENTRY's displayed state."
  (if (and (eq (glassmacs-entry-state entry) 'pending)
           (glassmacs-entry-held entry))
      "held"
    (symbol-name (glassmacs-entry-state entry))))

(defun glassmacs-queue-inspector--insert-entry (entry position)
  "Insert a line for ENTRY labeled with POSITION (a string)."
  (let ((start (point))
        (finished (memq (glassmacs-entry-state entry)
                        glassmacs-queue--finished-states)))
    (insert (format "  %3s  %-9s %-10s %s\n"
                    position
                    (glassmacs-entry-id entry)
                    (glassmacs-queue-inspector--state-label entry)
                    (glassmacs-queue-inspector--first-line
                     (glassmacs-entry-source entry))))
    (put-text-property start (point) 'glassmacs-queue-entry
                       (glassmacs-entry-id entry))
    (when finished
      (add-face-text-property start (point) 'shadow))
    (when (equal (glassmacs-entry-state entry) 'running)
      (add-face-text-property start (point) 'bold))))

(defconst glassmacs-queue-inspector--actions
  '(("Resume" glassmacs-queue-inspector-resume
     "Run waiting and held commands")
    ("Pause" glassmacs-queue-inspector-pause
     "Stop dispatching; a running command continues")
    ("Clear & Resume…" glassmacs-queue-inspector-clear-and-resume
     "Remove every pending command (after confirmation), then resume")
    ("Interrupt" glassmacs-queue-inspector-interrupt
     "Interrupt the running command; queued commands are held")
    ("Show Console" glassmacs-queue-inspector-show-console
     "Show this session's R console")
    ("Refresh" glassmacs-queue-inspector-refresh "Redisplay this queue"))
  "Inspector buttons: (LABEL COMMAND HELP).")

(defun glassmacs-queue-inspector--render (session)
  "Redraw the current buffer for SESSION, keeping point on its entry."
  (let* ((inhibit-read-only t)
         (entry-id (get-text-property (line-beginning-position)
                                      'glassmacs-queue-entry))
         (line (line-number-at-pos))
         (running (glassmacs-queue-running session))
         (pending (glassmacs-queue-pending session))
         (finished (last (cl-remove-if-not
                          (lambda (e) (memq (glassmacs-entry-state e)
                                            glassmacs-queue--finished-states))
                          (glassmacs-session-entries session))
                         glassmacs-queue-inspector-recent-count)))
    (erase-buffer)
    (insert (propertize (format "R Queue — %s" (glassmacs-sessions--describe session))
                        'face 'bold)
            "\n\n"
            (glassmacs-sessions-status-text session)
            "\n\n  ")
    (pcase-dolist (`(,label ,command ,help) glassmacs-queue-inspector--actions)
      (insert-text-button (format "[%s]" label)
                          'action (lambda (_button) (call-interactively command))
                          'help-echo help
                          'follow-link t)
      (insert " "))
    (insert "\n\n" (propertize (format "  %3s  %-9s %-10s %s\n"
                                       "#" "Command" "State" "Source")
                               'face 'underline))
    (when running
      (glassmacs-queue-inspector--insert-entry running "▶"))
    (if pending
        (cl-loop for entry in pending
                 for index from 1
                 do (glassmacs-queue-inspector--insert-entry
                     entry (number-to-string index)))
      (unless running
        (insert (propertize "       (no commands waiting)\n" 'face 'shadow))))
    (when finished
      (insert "\n" (propertize "  Recent\n" 'face 'underline))
      (dolist (entry (reverse finished))
        (glassmacs-queue-inspector--insert-entry entry "")))
    (insert "\n"
            (propertize
             (substitute-command-keys
              (concat "\\<glassmacs-queue-inspector-mode-map>"
                      "\\[glassmacs-queue-inspector-view] view  "
                      "\\[glassmacs-queue-inspector-move-up]/"
                      "\\[glassmacs-queue-inspector-move-down] reorder  "
                      "\\[glassmacs-queue-inspector-remove] remove  "
                      "\\[glassmacs-queue-inspector-resume] resume  "
                      "\\[glassmacs-queue-inspector-pause] pause  "
                      "\\[glassmacs-queue-inspector-clear-and-resume] clear & resume  "
                      "\\[glassmacs-queue-inspector-interrupt] interrupt  "
                      "\\[glassmacs-queue-inspector-refresh] refresh  "
                      "\\[quit-window] close"))
             'face 'shadow)
            "\n")
    (goto-char (point-min))
    (if-let* ((pos (and entry-id
                        (text-property-any (point-min) (point-max)
                                           'glassmacs-queue-entry entry-id))))
        (goto-char pos)
      (forward-line (1- line)))))

(defun glassmacs-queue-inspector-refresh ()
  "Redisplay the queue shown in this inspector."
  (interactive)
  (glassmacs-queue-inspector--render (glassmacs-queue-inspector--session)))

(defun glassmacs-queue-inspector--schedule-refresh (session-id)
  "Refresh inspectors of SESSION-ID once the current change completes.
Coalescing keeps a burst of recorded transitions to one redraw, and
never redraws in the middle of a queue operation."
  (dolist (buffer (buffer-list))
    (when (equal (buffer-local-value 'glassmacs-queue-inspector--session-id buffer)
                 session-id)
      (with-current-buffer buffer
        (unless (timerp glassmacs-queue-inspector--refresh-timer)
          (setq glassmacs-queue-inspector--refresh-timer
                (run-with-timer
                 0 nil
                 (lambda ()
                   (when (buffer-live-p buffer)
                     (with-current-buffer buffer
                       (setq glassmacs-queue-inspector--refresh-timer nil)
                       (when-let* ((session (glassmacs-sessions-find session-id)))
                         (let ((windows (get-buffer-window-list buffer nil t)))
                           (glassmacs-queue-inspector--render session)
                           ;; Keep each window's point where render left it.
                           (dolist (window windows)
                             (set-window-point window (point)))))))))))))))

(add-hook 'glassmacs-queue-changed-functions
          #'glassmacs-queue-inspector--schedule-refresh)

(defun glassmacs-queue-inspector-view ()
  "Show the complete source of the command on this line."
  (interactive)
  (let ((entry (or (glassmacs-queue-inspector--entry-at-point)
                   (user-error "Move to a command first"))))
    (with-current-buffer (get-buffer-create
                          (format "*R Command %s*" (glassmacs-entry-id entry)))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (glassmacs-entry-source entry))
        (goto-char (point-min)))
      (special-mode)
      (setq header-line-format
            (format " %s — %s%s" (glassmacs-entry-id entry)
                    (glassmacs-queue-inspector--state-label entry)
                    (if-let* ((reason (glassmacs-entry-reason entry)))
                        (format " (%s)" reason) "")))
      (pop-to-buffer (current-buffer)))))

(defun glassmacs-queue-inspector-remove ()
  "Remove the pending command on this line after confirmation."
  (interactive)
  (glassmacs-queue--remove-entries (list (glassmacs-queue-inspector--pending-at-point))
                                   "Remove pending command"))

(defun glassmacs-queue-inspector--move (offset)
  "Move the pending command on this line OFFSET places."
  (let ((entry (glassmacs-queue-inspector--pending-at-point)))
    (glassmacs-queue-move entry offset)
    (glassmacs-queue-inspector-refresh)
    (when-let* ((pos (text-property-any (point-min) (point-max)
                                        'glassmacs-queue-entry
                                        (glassmacs-entry-id entry))))
      (goto-char pos))))

(defun glassmacs-queue-inspector-move-up ()
  "Run the pending command on this line one place sooner."
  (interactive)
  (glassmacs-queue-inspector--move -1))

(defun glassmacs-queue-inspector-move-down ()
  "Run the pending command on this line one place later."
  (interactive)
  (glassmacs-queue-inspector--move 1))

(defun glassmacs-queue-inspector-resume ()
  "Resume this session's queue, including held commands."
  (interactive)
  (glassmacs-queue-resume (glassmacs-queue-inspector--session)))

(defun glassmacs-queue-inspector-pause ()
  "Pause this session's queue."
  (interactive)
  (glassmacs-queue-pause (glassmacs-queue-inspector--session)))

(defun glassmacs-queue-inspector-clear-and-resume ()
  "Remove this session's pending commands after confirmation, then resume."
  (interactive)
  (glassmacs-queue-clear-and-resume (glassmacs-queue-inspector--session)))

(defun glassmacs-queue-inspector-interrupt ()
  "Interrupt this session's running command."
  (interactive)
  (glassmacs-r-interrupt (glassmacs-queue-inspector--session)))

(defun glassmacs-queue-inspector-show-console ()
  "Show this session's R console."
  (interactive)
  (let ((buffer (glassmacs-session-buffer (glassmacs-queue-inspector--session))))
    (unless (buffer-live-p buffer)
      (user-error "This R session has no console buffer"))
    (glassmacs-r-display-console buffer)))

(defvar glassmacs-queue-inspector-mode-map
  (let ((map (make-sparse-keymap))
        (menu (make-sparse-keymap "Queue")))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "RET") #'glassmacs-queue-inspector-view)
    (define-key map "v" #'glassmacs-queue-inspector-view)
    (define-key map "d" #'glassmacs-queue-inspector-remove)
    (define-key map "k" #'glassmacs-queue-inspector-remove)
    (define-key map (kbd "M-<up>") #'glassmacs-queue-inspector-move-up)
    (define-key map (kbd "M-<down>") #'glassmacs-queue-inspector-move-down)
    (define-key map "u" #'glassmacs-queue-inspector-move-up)
    (define-key map "j" #'glassmacs-queue-inspector-move-down)
    (define-key map "r" #'glassmacs-queue-inspector-resume)
    (define-key map "p" #'glassmacs-queue-inspector-pause)
    (define-key map "x" #'glassmacs-queue-inspector-clear-and-resume)
    (define-key map "i" #'glassmacs-queue-inspector-interrupt)
    (define-key map "c" #'glassmacs-queue-inspector-show-console)
    (define-key map "g" #'glassmacs-queue-inspector-refresh)
    (define-key map "n" #'next-line)
    ;; The menu lists the same commands for mouse users.
    (define-key menu [refresh] '(menu-item "Refresh" glassmacs-queue-inspector-refresh))
    (define-key menu [console] '(menu-item "Show R Console" glassmacs-queue-inspector-show-console))
    (define-key menu [sep2] menu-bar-separator)
    (define-key menu [interrupt] '(menu-item "Interrupt R" glassmacs-queue-inspector-interrupt))
    (define-key menu [clear] '(menu-item "Clear Queue and Resume…" glassmacs-queue-inspector-clear-and-resume))
    (define-key menu [pause] '(menu-item "Pause Queue" glassmacs-queue-inspector-pause))
    (define-key menu [resume] '(menu-item "Resume Queue" glassmacs-queue-inspector-resume))
    (define-key menu [sep1] menu-bar-separator)
    (define-key menu [remove] '(menu-item "Remove Command…" glassmacs-queue-inspector-remove))
    (define-key menu [down] '(menu-item "Run Later" glassmacs-queue-inspector-move-down))
    (define-key menu [up] '(menu-item "Run Sooner" glassmacs-queue-inspector-move-up))
    (define-key menu [view] '(menu-item "View Command" glassmacs-queue-inspector-view))
    (define-key map [menu-bar glassmacs-queue] (cons "Queue" menu))
    map)
  "Keymap for `glassmacs-queue-inspector-mode'.")

(define-derived-mode glassmacs-queue-inspector-mode special-mode "R-Queue"
  "Inspect one R session's command queue.
The buttons, keys and Queue menu pause, resume, clear, reorder and
remove queued commands through the same functions as the R menu."
  (setq truncate-lines t
        buffer-undo-list t))

(defun glassmacs-r-show-queue (&optional session)
  "Show SESSION's queue inspector; by default the current R session.
From an R source buffer this is its linked console's session."
  (interactive)
  (let* ((session (cond
                   (session (glassmacs-sessions-resolve session))
                   (glassmacs-queue-inspector--session-id
                    (glassmacs-queue-inspector--session))
                   (t (glassmacs-sessions-resolve))))
         (buffer (get-buffer-create (glassmacs-queue-inspector--buffer-name session))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'glassmacs-queue-inspector-mode)
        (glassmacs-queue-inspector-mode))
      (setq glassmacs-queue-inspector--session-id (glassmacs-session-id session))
      (glassmacs-queue-inspector--render session))
    (pop-to-buffer buffer '((display-buffer-reuse-window
                             display-buffer-below-selected)
                            (window-height . fit-window-to-buffer)
                            (reusable-frames . visible)))
    buffer))

(defalias 'glassmacs-queue-show #'glassmacs-r-show-queue
  "Display SESSION's queue; see `glassmacs-r-show-queue'.")

(provide 'glassmacs-r-queue)
;;; glassmacs-r-queue.el ends here
