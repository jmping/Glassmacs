;;; glassmacs-acceptance-driver.el --- Remote control for GUI acceptance tests -*- lexical-binding: t; -*-

;; Loaded only by scripts/macos-gui-acceptance, through the app's own
;; launcher (`open -a Glassmacs.app --args -l THIS-FILE --eval ...'), so
;; the packaged application is tested as users run it.  It is never part
;; of Glassmacs itself and is not in the app bundle.
;;
;; `glassmacs-acceptance-start' listens on 127.0.0.1 only, on a port the
;; system chooses, and writes the port to a file only the test can read.
;; Each request is one line of JSON: {"token": ..., "id": ..., "form": ...}.
;; A request without the token from the configuration file is refused.
;; The form is read and evaluated in the running Emacs, inside the process
;; filter, so requests are answered even while Emacs waits in a prompt.
;; The reply is one line of JSON: {"id": ..., "ok": true|false,
;; "value": ..., "repr": ...}, where "value" is the result converted to
;; JSON (see `glassmacs-acceptance--json') and "repr" its printed form.
;;
;; Keyboard input for a prompt is given with `glassmacs-acceptance-type',
;; which queues events exactly as Cocoa delivers them (Command chords are
;; integer events such as ?\s-w).  This exercises Emacs's own key handling
;; in the GUI process; it does not go through macOS's text input system,
;; which the harness tests separately with System Events when allowed.

(require 'cl-lib)
(require 'json)
(require 'subr-x)

(defvar glassmacs-acceptance--token nil
  "Token every request must carry.")

(defvar glassmacs-acceptance--server nil
  "The listening network process.")

(defvar glassmacs-acceptance--log-file nil
  "File the driver appends a line to for each request, for CI artifacts.")

(defun glassmacs-acceptance--log (format-string &rest args)
  "Append a line made from FORMAT-STRING and ARGS to the request log."
  (when glassmacs-acceptance--log-file
    (let ((inhibit-message t)
          (message-log-max nil))
      (write-region (concat (format-time-string "%FT%T.%3N ")
                            (apply #'format format-string args) "\n")
                    nil glassmacs-acceptance--log-file 'append 'silent))))

(defun glassmacs-acceptance--plist-p (value)
  "Return non-nil when VALUE is a non-empty plist with keyword keys."
  (and (consp value)
       (proper-list-p value)
       (cl-evenp (length value))
       (cl-loop for (key _) on value by #'cddr always (keywordp key))))

(defun glassmacs-acceptance--json (value)
  "Convert VALUE to something `json-serialize' accepts.
nil and t become false and true, keyword plists become objects, other
lists and vectors become arrays, symbols their names, buffers, frames,
windows and processes their names or printed forms."
  (cond
   ((eq value t) t)
   ((null value) :false)
   ((or (stringp value) (numberp value)) value)
   ((keywordp value) (substring (symbol-name value) 1))
   ((symbolp value) (symbol-name value))
   ((bufferp value) (or (buffer-name value) "#<killed buffer>"))
   ((glassmacs-acceptance--plist-p value)
    (let ((table (make-hash-table :test #'equal)))
      (cl-loop for (key item) on value by #'cddr
               do (puthash (substring (symbol-name key) 1)
                           (glassmacs-acceptance--json item) table))
      table))
   ((proper-list-p value) (vconcat (mapcar #'glassmacs-acceptance--json value)))
   ((vectorp value) (vconcat (mapcar #'glassmacs-acceptance--json value)))
   ((consp value) (vector (glassmacs-acceptance--json (car value))
                          (glassmacs-acceptance--json (cdr value))))
   (t (prin1-to-string value))))

(defun glassmacs-acceptance--reply (process id ok value)
  "Send PROCESS the reply to request ID: OK and VALUE."
  (let ((reply (list :id id :ok (if ok t :false)
                     :value (glassmacs-acceptance--json value)
                     :repr (let ((print-length 50) (print-level 6))
                             (prin1-to-string value)))))
    (process-send-string
     process (concat (json-serialize reply) "\n"))))

(defun glassmacs-acceptance--handle (process line)
  "Evaluate the request in LINE and reply to PROCESS."
  (let* ((request (condition-case nil
                      (json-parse-string line :object-type 'plist)
                    (error nil)))
         (id (plist-get request :id)))
    (cond
     ((not request)
      (glassmacs-acceptance--reply process nil nil "Malformed request"))
     ((not (equal (plist-get request :token) glassmacs-acceptance--token))
      (glassmacs-acceptance--log "refused request %s: bad token" id)
      (glassmacs-acceptance--reply process id nil "Bad token"))
     (t
      (let ((form (plist-get request :form)))
        (glassmacs-acceptance--log "eval %s: %s" id form)
        (condition-case err
            (let ((value (eval (car (read-from-string form)) t)))
              (glassmacs-acceptance--reply process id t value))
          ((debug error quit)
           (glassmacs-acceptance--log "error %s: %S" id err)
           (glassmacs-acceptance--reply
            process id nil (error-message-string err)))))))))

(defun glassmacs-acceptance--filter (process output)
  "Collect OUTPUT from PROCESS and handle each complete request line."
  (let ((pending (concat (or (process-get process 'pending) "") output)))
    (while (string-match "\n" pending)
      (let ((line (substring pending 0 (match-beginning 0))))
        (setq pending (substring pending (match-end 0)))
        (unless (string-blank-p line)
          (glassmacs-acceptance--handle process line))))
    (process-put process 'pending pending)))

(defun glassmacs-acceptance-start (config-file)
  "Start the acceptance-test server described by CONFIG-FILE.
CONFIG-FILE is JSON with \"token\", \"port_file\" and optionally
\"log_file\".  The chosen port is written to the port file."
  (let* ((config (with-temp-buffer
                   (insert-file-contents config-file)
                   (json-parse-buffer :object-type 'plist)))
         (port-file (plist-get config :port_file)))
    (setq glassmacs-acceptance--token (plist-get config :token)
          glassmacs-acceptance--log-file (plist-get config :log_file))
    (setq glassmacs-acceptance--server
          (make-network-process
           :name "glassmacs-acceptance" :server t :noquery t
           :host "127.0.0.1" :service t :family 'ipv4
           :coding 'utf-8 :filter #'glassmacs-acceptance--filter))
    (let ((port (process-contact glassmacs-acceptance--server :service))
          (temporary (concat port-file ".tmp")))
      ;; Written then renamed, so the harness never reads half a file.
      (with-temp-file temporary (insert (number-to-string port)))
      (rename-file temporary port-file t)
      (glassmacs-acceptance--log "listening on 127.0.0.1:%d (pid %d)"
                                 port (emacs-pid))
      port)))

;;; Helpers the harness calls.

(defun glassmacs-acceptance-type (keys)
  "Queue KEYS, a string for `kbd' or a vector of events, as keyboard input.
Return immediately; the events are read by the command loop or by a
prompt that is waiting for input."
  (setq unread-command-events
        (append unread-command-events
                (listify-key-sequence (if (stringp keys) (kbd keys) keys))))
  t)

(defun glassmacs-acceptance-type-text (text)
  "Queue TEXT as typed characters, one key event per character."
  (setq unread-command-events (append unread-command-events (string-to-list text)))
  t)

(defun glassmacs-acceptance-prompt ()
  "Return the question Emacs is waiting on, or nil.
That is the minibuffer prompt (`y-or-n-p', `read-string') or, for
questions asked in the echo area (`read-multiple-choice',
`map-y-or-n-p'), the echo area message."
  (or (and (active-minibuffer-window)
           (with-current-buffer (window-buffer (active-minibuffer-window))
             (minibuffer-prompt)))
      (current-message)))

(defun glassmacs-acceptance-prompt-matches-p (regexp)
  "Return non-nil when the question Emacs waits on matches REGEXP."
  (let ((prompt (glassmacs-acceptance-prompt)))
    (and prompt (string-match-p regexp prompt) t)))

(defun glassmacs-acceptance-run-later (function)
  "Run FUNCTION from the command loop shortly, not inside this request.
Use it for commands that prompt, so the request can return first."
  (run-at-time 0 nil function)
  t)

(defun glassmacs-acceptance-frames ()
  "Describe the live graphical frames."
  (mapcar (lambda (frame)
            (list :name (frame-parameter frame 'name)
                  :visible (eq (frame-visible-p frame) t)
                  :selected (eq frame (selected-frame))
                  :fullscreen (frame-parameter frame 'fullscreen)
                  :buffers (mapcar (lambda (window) (buffer-name (window-buffer window)))
                                   (window-list frame 'never))))
          (cl-remove-if-not #'display-graphic-p (frame-list))))

(defun glassmacs-acceptance-visible-frames ()
  "Return the number of visible top-level graphical frames."
  (cl-count-if (lambda (frame)
                 (and (display-graphic-p frame)
                      (eq (frame-visible-p frame) t)
                      (not (frame-parent frame))))
               (frame-list)))

(defun glassmacs-acceptance-file-buffers (file)
  "Return the names of buffers visiting FILE (normally zero or one)."
  (let ((true (file-truename file)))
    (cl-loop for buffer in (buffer-list)
             for visited = (buffer-file-name buffer)
             when (and visited (equal (file-truename visited) true))
             collect (buffer-name buffer))))

(defun glassmacs-acceptance-file-shown-p (file)
  "Return non-nil when FILE is shown in a visible, selected frame's window."
  (let ((frame (selected-frame)))
    (and (eq (frame-visible-p frame) t)
         (cl-some (lambda (window)
                    (let ((visited (buffer-file-name (window-buffer window))))
                      (and visited (equal (file-truename visited)
                                          (file-truename file)))))
                  (window-list frame 'never)))))

(defun glassmacs-acceptance-close-selected-window-like-cocoa ()
  "Close the selected frame as its window close button does.
Cocoa delivers the close button as a delete-frame event, handled by
`handle-delete-frame'; queue the same event."
  (glassmacs-acceptance-type (vector (list 'delete-frame (list (selected-frame))))))

(defun glassmacs-acceptance-buffer-text (buffer-or-name)
  "Return the text of BUFFER-OR-NAME, or nil when it does not exist."
  (when-let* ((buffer (get-buffer buffer-or-name)))
    (with-current-buffer buffer
      (save-restriction
        (widen)
        (buffer-substring-no-properties (point-min) (point-max))))))

(defun glassmacs-acceptance-diagnostics ()
  "Return state useful when a scenario fails, for the CI artifacts."
  (list :pid (emacs-pid)
        :window-system window-system
        :frames (glassmacs-acceptance-frames)
        :buffers (mapcar #'buffer-name (buffer-list))
        :current-message (current-message)
        :messages (glassmacs-acceptance-buffer-text "*Messages*")
        :warnings (glassmacs-acceptance-buffer-text "*Warnings*")))

(provide 'glassmacs-acceptance-driver)
;;; glassmacs-acceptance-driver.el ends here
