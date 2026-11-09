;;; glassmacs-frames.el --- Document and frame behavior -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)
(require 'glassmacs-presentation-model)

(defgroup glassmacs-frames nil
  "Document opening behavior for Glassmacs."
  :group 'glassmacs)

(defcustom glassmacs-document-opening-policy
  (if (eq system-type 'darwin) 'new-frame 'reuse-current)
  "How interactive document opens are displayed in graphical Emacs.
Save changes with `glassmacs-set-document-opening-policy' or Customize."
  :type '(choice (const :tag "New frame" new-frame)
                 (const :tag "New tab" new-tab)
                 (const :tag "Reuse current frame or tab" reuse-current))
  :group 'glassmacs-frames)

(defun glassmacs-set-document-opening-policy (policy)
  "Set and persist the document opening POLICY.
POLICY must be `new-frame', `new-tab', or `reuse-current'."
  (interactive
   (list
    (intern
     (completing-read
      "Open documents in: "
      '("new-frame" "new-tab" "reuse-current")
      nil t nil nil
      (symbol-name glassmacs-document-opening-policy)))))
  (unless (memq policy '(new-frame new-tab reuse-current))
    (user-error "Unknown document opening policy: %s" policy))
  (let ((user-init-file (or user-init-file custom-file)))
    (customize-save-variable 'glassmacs-document-opening-policy policy))
  (message "Glassmacs document opening policy: %s" policy))

(defcustom glassmacs-preferences-opening-policy
  (if (eq system-type 'darwin) 'new-frame 'reuse-current)
  "Where Glassmacs displays Customize/Preferences buffers.
On macOS, preserve the source document by opening a new frame."
  :type '(choice (const :tag "Separate native window" new-frame)
                 (const :tag "Reuse current window" reuse-current))
  :group 'glassmacs-frames)

(defun glassmacs--preferences-buffer-p (buffer _action)
  "Recognize Emacs Customize buffers without affecting ordinary documents."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (derived-mode-p 'custom-mode))))

(defun glassmacs--display-preferences (buffer _alist)
  "Show BUFFER without replacing a document on graphical macOS."
  (let* ((placement (if (and (display-graphic-p)
                             (eq glassmacs-preferences-opening-policy 'new-frame))
                        'new-frame 'reuse-current))
         (existing (glassmacs-presentation-find-suitable-view
                    buffer 'open placement)))
    (cond
     (existing
      existing)
     ((and (display-graphic-p)
           (eq glassmacs-preferences-opening-policy 'new-frame))
      (display-buffer-pop-up-frame buffer nil))
     (t (display-buffer-same-window buffer nil)))))

(add-to-list 'display-buffer-alist
             '(glassmacs--preferences-buffer-p
               glassmacs--display-preferences))

(defun glassmacs-open-preferences-group (group)
  "Open Customize GROUP in its own frame on graphical macOS.
Customize can switch buffers directly, bypassing display-buffer rules;
selecting a dedicated frame first protects the source document."
  (let* ((separate (and (display-graphic-p)
                        (eq glassmacs-preferences-opening-policy 'new-frame)))
         (existing (and separate
                        (cl-find-if
                         (lambda (frame)
                           (let ((window (frame-selected-window frame)))
                             (and (window-live-p window)
                                  (with-current-buffer (window-buffer window)
                                    (derived-mode-p 'custom-mode)))))
                         (frame-list))))
         (target (or existing (and separate (make-frame)))))
    (if target
        (progn
          (select-frame-set-input-focus target)
          (with-selected-frame target (customize-group group)))
      (customize-group group))))

(defun glassmacs-open-document-preferences ()
  "Open the dedicated document and window opening preferences."
  (interactive)
  (glassmacs-open-preferences-group 'glassmacs-frames))

(defun glassmacs--ordinary-document-buffer-p (buffer)
  "Return non-nil when BUFFER is an ordinary document buffer."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (and (not (derived-mode-p 'special-mode 'dired-mode 'comint-mode))
              (not (get-buffer-process buffer))
              (or buffer-file-name
                  (not (string-match-p "\\`\\*" (buffer-name)))
                  (equal (buffer-name) "*scratch*"))))))

(defun glassmacs--document-opening-action (buffer)
  "Return the configured opening action for ordinary BUFFER, if applicable."
  (when (and (display-graphic-p)
             (glassmacs--ordinary-document-buffer-p buffer))
    glassmacs-document-opening-policy))

(defun glassmacs--focus-buffer-in-existing-tab (buffer &optional destination)
  "Focus BUFFER in an existing tab without replacing any window contents.
This is an explicit navigation operation, not a presentation-policy
lookup.  Restore each frame's selected tab when BUFFER is absent."
  (require 'tab-bar)
  (let ((frames (if destination (list destination)
                  (cons (selected-frame)
                        (delq (selected-frame) (frame-list))))))
    (catch 'found
      (dolist (frame frames)
        (when (and (frame-live-p frame) (frame-visible-p frame)
                   (bound-and-true-p tab-bar-mode))
          (with-selected-frame frame
            (let ((original (1+ (tab-bar--current-tab-index)))
                  (count (length (funcall tab-bar-tabs-function frame)))
                  (matched nil))
              (unwind-protect
                  (dotimes (index count)
                    (tab-bar-select-tab (1+ index))
                    (let ((window (get-buffer-window buffer frame)))
                      (when (and (window-live-p window)
                                 (eq (window-buffer window) buffer))
                        (setq matched window)
                        (throw 'found
                               (progn
                                 (select-frame-set-input-focus frame)
                                 (select-window window)
                                 window)))))
                (unless matched
                  (tab-bar-select-tab original)))))))
      nil)))

(defun glassmacs--read-open-document ()
  "Prompt for an open ordinary document and return its buffer.
Choices are labeled with the abbreviated file name so same-named
documents in different directories remain distinguishable."
  (let* ((buffers (cl-remove-if-not
                   #'glassmacs--ordinary-document-buffer-p (buffer-list)))
         (choices (mapcar
                   (lambda (buffer)
                     (cons (if-let* ((file (buffer-file-name buffer)))
                               (format "%s — %s" (buffer-name buffer)
                                       (abbreviate-file-name file))
                             (buffer-name buffer))
                           buffer))
                   buffers)))
    (unless choices
      (user-error "No open documents"))
    (or (cdr (assoc (completing-read "Show open document: " choices nil t)
                    choices))
        (user-error "No document selected"))))

(defun glassmacs-focus-open-document (&optional buffer)
  "Navigate to an open document BUFFER, including a view in an inactive tab.
This is an explicit user command: unlike automatic presentation, it may
select a different tab or frame.  If no view exists, create one using
the configured document opening policy.  With no BUFFER, prompt; the
mode-line document click relies on that."
  (interactive (list (glassmacs--read-open-document)))
  (unless buffer
    (setq buffer (glassmacs--read-open-document)))
  (unless (and (buffer-live-p buffer)
               (glassmacs--ordinary-document-buffer-p buffer))
    (user-error "Document is no longer open"))
  (glassmacs-present-buffer buffer 'focus))

(defun glassmacs-present-buffer (buffer &optional intent placement destination)
  "Present BUFFER according to INTENT and PLACEMENT, returning its window.
INTENT is one of open, focus, new-view, move, split, tab, or replace.
An open or focus operation reuses only a suitable visible view of BUFFER.
PLACEMENT defaults to the document opening policy; DESTINATION is an
explicit frame for intentional consolidation.  This API does not advise Emacs primitives."
  (unless (buffer-live-p buffer)
    (user-error "Cannot present a dead buffer"))
  (let* ((intent (or intent 'open))
         (placement (or placement
                        (and (eq intent 'open)
                             (glassmacs--document-opening-action buffer))
                        'reuse-current))
         (existing (glassmacs-presentation-find-suitable-view
                    buffer intent placement destination)))
    (cond
     (existing
      (select-frame-set-input-focus (window-frame existing))
      (select-window existing)
      existing)
     ((eq intent 'focus)
      (or (glassmacs--focus-buffer-in-existing-tab buffer destination)
          (glassmacs-present-buffer buffer 'new-view placement destination)))
     ((and (memq intent '(open focus))
           (fboundp 'glassmacs--ensure-visible-frame)
           (glassmacs--ensure-visible-frame))
      (switch-to-buffer buffer)
      (selected-window))
     ((or (eq intent 'move) (eq intent 'split)
          (eq intent 'tab) (eq intent 'replace))
      (unless (fboundp 'glassmacs-buffer-placement--display)
        (require 'glassmacs-buffer-placement))
      (glassmacs-buffer-placement--display
       buffer (pcase intent
                ('split (if (memq placement '(split-right split-below))
                            placement 'split-below))
                ('tab 'new-tab)
                ('replace 'replace)
                (_ placement))
       destination))
     ((and (eq intent 'new-view) (eq placement 'reuse-current))
      ;; A new view must not silently replace the existing one.
      ;; In a terminal, a split is the closest supported presentation.
      (let ((window (split-window (selected-window) nil 'below)))
        (set-window-buffer window buffer)
        (select-window window)
        window))
     ((eq placement 'new-frame)
      (let ((frame (make-frame)))
        (with-selected-frame frame
          (switch-to-buffer buffer))
        (select-frame-set-input-focus frame)
        (frame-selected-window frame)))
     ((eq placement 'new-tab)
      (require 'tab-bar)
      (tab-bar-mode 1)
      (tab-bar-new-tab)
      (switch-to-buffer buffer)
      (selected-window))
     (t
      (switch-to-buffer buffer)
      (selected-window)))))

(defun glassmacs--show-document-buffer (buffer action)
  "Compatibility wrapper for presenting document BUFFER using ACTION."
  (glassmacs-present-buffer buffer 'open action))

(defun glassmacs-open-file (filename &optional wildcards)
  "Open FILENAME interactively using Glassmacs' document policy."
  (interactive (find-file-read-args "Find file: "
                                    confirm-nonexistent-file-or-buffer))
  (glassmacs--open-file-with-policy
   filename wildcards (called-interactively-p 'interactive)))

(defun glassmacs-find-file (filename &optional wildcards)
  "Visit FILENAME using the native document-opening policy.
This is the interactive counterpart of Emacs `find-file'; Lisp callers
of `find-file' retain upstream semantics."
  (interactive (find-file-read-args "Find file: "
                                    confirm-nonexistent-file-or-buffer))
  (glassmacs--open-file-with-policy filename wildcards t))

(defun glassmacs--install-file-keybindings ()
  "Route ordinary interactive file visits through the document policy.
Do not advise `find-file' globally: packages depend on its semantics."
  (when (eq system-type 'darwin)
    (define-key global-map [remap find-file] #'glassmacs-find-file)
    (global-set-key (kbd "C-x C-f") #'glassmacs-find-file)))

(defun glassmacs--open-file-with-policy (filename &optional wildcards apply-policy)
  "Open FILENAME with Glassmacs document policy when APPLY-POLICY is non-nil."
  (if (or (not apply-policy) wildcards (not (display-graphic-p)))
      (find-file filename wildcards)
    (let* ((buffer (find-file-noselect filename))
           (action (glassmacs--document-opening-action buffer)))
      (if action
          (glassmacs--show-document-buffer buffer action)
        (switch-to-buffer buffer))
      buffer)))

(defvar ns-input-file)
(defvar command-line-default-directory)
(declare-function ns-hide-emacs "nsfns.m" (on))

(defun glassmacs--ns-find-file (original &rest arguments)
  "Route Cocoa's ORIGINAL file-open event through Glassmacs' policy."
  (if (and (boundp 'ns-input-file) ns-input-file)
      (let ((filename
             (file-truename
              (expand-file-name (pop ns-input-file)
                                command-line-default-directory))))
        (when (fboundp 'ns-hide-emacs)
          (ns-hide-emacs 'activate))
        (glassmacs--open-file-with-policy filename nil t))
    (apply original arguments)))

(defun glassmacs--install-ns-file-open-policy ()
  "Route Cocoa file-open events through Glassmacs' document policy."
  (when (and (eq system-type 'darwin)
             (fboundp 'ns-find-file)
             (not (advice-member-p #'glassmacs--ns-find-file 'ns-find-file)))
    (advice-add 'ns-find-file :around #'glassmacs--ns-find-file)))

(when (eq system-type 'darwin)
  (with-eval-after-load 'ns-win
    (glassmacs--install-ns-file-open-policy)))

;;; Closing documents (Command-W and the window close button)

;; Mac applications close a document when its last window closes, asking
;; first whether to save unsaved changes.  Aquamacs did this in
;; `close-window' (one-buffer-one-frame.el).  Plain `delete-frame' instead
;; hides the window and leaves the edited buffer alive and invisible until
;; Quit, which is easy to lose track of with one window per document.

(defun glassmacs--buffer-in-inactive-tab-p (buffer frame)
  "Whether an inactive tab in FRAME has a view of BUFFER.
Selection is restored even when tab-switch hooks raise an error."
  (when (and (frame-live-p frame)
             (glassmacs--frame-has-hidden-tabs-p frame))
    (with-selected-frame frame
      (let ((original (1+ (tab-bar--current-tab-index)))
            (count (length (funcall tab-bar-tabs-function frame)))
            found)
        (unwind-protect
            (dotimes (index count)
              (unless (= (1+ index) original)
                (tab-bar-select-tab (1+ index))
                (when (get-buffer-window buffer frame)
                  (setq found t))))
          (tab-bar-select-tab original))
        found))))

(defun glassmacs--buffer-shown-elsewhere-p (buffer windows)
  "Return non-nil when BUFFER has a view outside WINDOWS.
Include inactive tab views, which ordinary window enumeration omits.
This avoids killing a document or prompting to hide a live R session
while another tab still owns a view of that buffer."
  (or (cl-some (lambda (window) (not (memq window windows)))
               (get-buffer-window-list buffer nil t))
      (cl-some
       (lambda (frame)
         (and (frame-live-p frame)
              (glassmacs--frame-has-hidden-tabs-p frame)
              (memq buffer (glassmacs--frame-tab-buffers frame))
              ;; If BUFFER occupies a view in this frame that is not one of
              ;; the closing windows, keep the buffer alive.  A selected-tab
              ;; view outside WINDOWS is handled by the first clause.
              (or (not (memq buffer
                             (mapcar #'window-buffer
                                     (cl-remove-if-not
                                      (lambda (window)
                                        (eq (window-frame window) frame))
                                      windows))))
                  (glassmacs--buffer-in-inactive-tab-p buffer frame))))
       (frame-list))))

(defcustom glassmacs-confirm-console-window-close t
  "Ask before hiding the last visible window of a live R console.
Hiding the window leaves the R process, pending work, command history,
and console buffer intact.  Explicit session termination is a separate
command and requires its own confirmation."
  :type 'boolean
  :group 'glassmacs-frames)

(defun glassmacs--live-r-console-p (buffer)
  "Return non-nil when BUFFER belongs to a live ESS R process."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (and (derived-mode-p 'inferior-ess-r-mode 'inferior-ess-mode)
              (let ((process (get-buffer-process buffer)))
                (and (processp process) (process-live-p process)))))))

(defun glassmacs--confirm-console-windows-close (windows)
  "Confirm hiding live R consoles whose last visible view is in WINDOWS.
This never terminates R.  An explicit Cancel aborts the frame/window
close; closing one of several console views needs no confirmation."
  (catch 'cancel
    (dolist (buffer (delete-dups (mapcar #'window-buffer windows)) t)
      (when (and glassmacs-confirm-console-window-close
                 (glassmacs--live-r-console-p buffer)
                 (not (glassmacs--buffer-shown-elsewhere-p buffer windows)))
        (unless (eq
                 (condition-case nil
                     (car (read-multiple-choice
                           (format "Hide R console %s? The R session keeps running. "
                                   (buffer-name buffer))
                           '((?h "hide" "Hide this window; keep R running")
                             (?c "cancel" "Keep this R console window open"))))
                   ;; A dismissed dialog, keyboard quit, or UI error must
                   ;; never close the only visible view of a live R process.
                   ((quit error) ?c))
                 ?h)
          (throw 'cancel nil))))))

(defun glassmacs--close-documents-in-windows (windows)
  "Close documents exclusive to WINDOWS, with all decisions made first.
A canceled decision leaves every buffer alive and retains modified flags.
Save operations may already have completed before a later cancellation."
  (let* ((buffers (cl-remove-if-not
                   (lambda (buffer)
                     (and (glassmacs--ordinary-document-buffer-p buffer)
                          (not (glassmacs--buffer-shown-elsewhere-p buffer windows))))
                   (delete-dups (mapcar #'window-buffer windows))))
         (discard nil))
    (if (catch 'canceled
          (dolist (buffer buffers)
            (when (buffer-modified-p buffer)
              (pcase (condition-case nil
                         (car (read-multiple-choice
                               (format "Save changes to %s before closing? "
                                       (buffer-name buffer))
                               '((?s "save" "Save the document, then close")
                                 (?d "don't save" "Discard unsaved changes")
                                 (?c "cancel" "Keep the document open"))))
                       (quit ?c)
                       (error ?c))
                (?s (unless (condition-case nil
                                (with-current-buffer buffer
                                  (save-buffer)
                                  (not (buffer-modified-p)))
                              (quit nil)
                              (error nil))
                      (throw 'canceled t)))
                (?d (push buffer discard))
                (_ (throw 'canceled t)))))
          nil)
        nil
      ;; Preserve the modified flag if a kill hook vetoes the operation.
      ;; Clear it only immediately before an explicitly discarded kill.
      (catch 'veto
        (dolist (buffer buffers t)
          (when (buffer-live-p buffer)
            (let ((discard-p (memq buffer discard))
                  (killed nil))
              (unwind-protect
                  (progn
                    (when discard-p
                      (with-current-buffer buffer (set-buffer-modified-p nil)))
                    (setq killed (kill-buffer buffer)))
                ;; A veto, error, or quit must never silently discard edits.
                (when (and discard-p (buffer-live-p buffer))
                  (with-current-buffer buffer (set-buffer-modified-p t))))
              (unless killed
                (throw 'veto nil)))))))))


(defun glassmacs--close-view (window)
  "Close WINDOW: the window itself, its tab, or its frame.
A frame's last window closes the tab when the frame has several tabs,
otherwise the frame.  Closing the final frame keeps Glassmacs running
(see `glassmacs--delete-frame-preserving-app')."
  (let ((frame (window-frame window)))
    (cond
     ((cdr (window-list frame 'never))
      (delete-window window))
     ((and (bound-and-true-p tab-bar-mode)
           (> (length (funcall tab-bar-tabs-function frame)) 1))
      (with-selected-frame frame
        (tab-bar-close-tab)))
     (t
      (delete-frame frame)))))

(defun glassmacs--review-close-windows (windows)
  "Review the affected WINDOWS before removing their views.
Cancel or a kill-buffer veto leaves the window layout intact."
  (and (glassmacs--confirm-console-windows-close windows)
       (glassmacs--close-documents-in-windows windows)))

(defun glassmacs--close-reviewed (scope &optional target)
  "Close SCOPE after its document and console review.
SCOPE is `view', `tab', or `frame'.  TARGET is a window for `view'
or a frame for the other scopes.  Return non-nil only on success.
The native frame-close handler uses `frame' to review, but leaves the
actual Cocoa frame deletion to its caller."
  (pcase scope
    ('view
     (let ((window (or target (selected-window))))
       (when (and (window-live-p window)
                  (glassmacs--review-close-windows (list window)))
         (glassmacs--close-view window)
         t)))
    ('tab
     (let ((frame (or target (selected-frame))))
       (with-selected-frame frame
         (if (not (glassmacs--frame-has-hidden-tabs-p frame))
             (glassmacs--close-reviewed 'view (selected-window))
           (when (glassmacs--review-close-windows (window-list frame 'never))
             (tab-bar-close-tab)
             t)))))
    ('frame
     (let ((frame (or target (selected-frame))))
       (or (not (frame-live-p frame))
           (if (glassmacs--frame-has-hidden-tabs-p frame)
               (glassmacs--review-frame-tab-buffers
                frame (glassmacs--frame-tab-buffers frame))
             (glassmacs--review-close-windows (window-list frame 'never))))))
    (_ (user-error "Unknown close scope: %s" scope))))

(defun glassmacs-close-current-tab ()
  "Review and close the selected tab without terminating R processes."
  (interactive)
  (unless (glassmacs--close-reviewed 'tab)
    (message "Close canceled")))

(defun glassmacs-close-document ()
  "Review and close the selected view, tab, or frame as Command-W does."
  (interactive)
  (when (active-minibuffer-window)
    (abort-recursive-edit))
  (unless (glassmacs--close-reviewed 'view)
    (message "Close canceled")))

(defun glassmacs--frame-has-hidden-tabs-p (frame)
  "Whether FRAME has tabs beyond its currently selected tab.
Closing the native frame while other tabs exist must not bypass their
individual document-save and R-console checks."
  (and (frame-live-p frame)
       (bound-and-true-p tab-bar-mode)
       (> (length (funcall tab-bar-tabs-function frame)) 1)))

(defun glassmacs--frame-tab-buffers (frame)
  "Collect unique buffers shown in every tab of FRAME.
Restore the original tab even if a tab-selection hook signals an error."
  (with-selected-frame frame
    (if (not (glassmacs--frame-has-hidden-tabs-p frame))
        (delete-dups (mapcar #'window-buffer (window-list frame 'never)))
      (let ((original (1+ (tab-bar--current-tab-index)))
            (count (length (funcall tab-bar-tabs-function frame)))
            buffers)
        (unwind-protect
            (dotimes (index count)
              (tab-bar-select-tab (1+ index))
              (dolist (window (window-list frame 'never))
                (cl-pushnew (window-buffer window) buffers)))
          (tab-bar-select-tab original))
        (nreverse buffers)))))

(defun glassmacs--buffer-visible-in-other-frame-p (buffer frame)
  "Whether BUFFER has a view in any other frame, including inactive tabs."
  (cl-some (lambda (other)
             (and (frame-live-p other)
                  (not (eq other frame))
                  (or (get-buffer-window buffer other)
                      (glassmacs--buffer-in-inactive-tab-p buffer other))))
           (frame-list)))

(defun glassmacs--review-frame-tab-buffers (frame buffers)
  "Review BUFFERS from all tabs before closing FRAME.
All cancelable decisions precede document kills.  Saving a document
may write to disk before a later cancellation; no R process is killed."
  (let ((documents (cl-remove-if-not
                    (lambda (buffer)
                      (and (glassmacs--ordinary-document-buffer-p buffer)
                           (not (glassmacs--buffer-visible-in-other-frame-p
                                 buffer frame))))
                    buffers))
        (consoles (cl-remove-if-not
                   (lambda (buffer)
                     (and (glassmacs--live-r-console-p buffer)
                          (not (glassmacs--buffer-visible-in-other-frame-p
                                buffer frame))))
                   buffers))
        discard)
    (if (catch 'cancel
            (dolist (buffer (if glassmacs-confirm-console-window-close
                                consoles nil))
              (unless (eq (condition-case nil
                              (car (read-multiple-choice
                                    (format "Hide R console %s? R keeps running. "
                                            (buffer-name buffer))
                                    '((?h "hide" "Keep R running")
                                      (?c "cancel" "Keep window open"))))
                            ((quit error) ?c))
                          ?h)
                (throw 'cancel t)))
            (dolist (buffer documents)
              (when (buffer-modified-p buffer)
                (pcase (condition-case nil
                           (car (read-multiple-choice
                                 (format "Save changes to %s before closing? "
                                         (buffer-name buffer))
                                 '((?s "save" "Save changes")
                                   (?d "don't save" "Discard changes")
                                   (?c "cancel" "Keep window open"))))
                         ((quit error) ?c))
                  (?s (unless (condition-case nil
                                  (with-current-buffer buffer
                                    (save-buffer)
                                    (not (buffer-modified-p)))
                                ((quit error) nil))
                        (throw 'cancel t)))
                  (?d (push buffer discard))
                  (_ (throw 'cancel t)))))
            nil)
        nil
      (catch 'veto
      (dolist (buffer documents t)
        (when (buffer-live-p buffer)
          (let ((discard-p (memq buffer discard))
                killed)
            (unwind-protect
                (progn
                  (when discard-p
                    (with-current-buffer buffer (set-buffer-modified-p nil)))
                  (setq killed (kill-buffer buffer)))
              (when (and discard-p (buffer-live-p buffer))
                (with-current-buffer buffer (set-buffer-modified-p t))))
            (unless killed (throw 'veto nil)))))))))

(defun glassmacs-close-frame-documents (frame)
  "Review every affected tab before the native close handler removes FRAME."
  (glassmacs--close-reviewed 'frame frame))

(defun glassmacs-save-document-as (filename)
  "Save the current document as FILENAME using Emacs' native file safeguards.
An existing destination requires the usual Emacs overwrite confirmation.
An untitled buffer receives a file name only through the successful save."
  (interactive
   (list (read-file-name "Save document as: " nil nil nil
                         (and buffer-file-name
                              (file-name-nondirectory buffer-file-name)))))
  (unless (and (stringp filename) (not (string-empty-p filename)))
    (user-error "A destination file is required"))
  (write-file filename))

(defun glassmacs--document-buffer-needs-saving-p (buffer)
  "Return non-nil when BUFFER contains modified user document contents."
  (and (glassmacs--ordinary-document-buffer-p buffer)
       (buffer-modified-p buffer)))

(defun glassmacs--modified-document-buffers ()
  "Return modified ordinary document buffers, excluding transient buffers."
  (cl-remove-if-not #'glassmacs--document-buffer-needs-saving-p
                    (buffer-list)))

(defvar-local glassmacs--review-targets nil
  "Buffers presented in this unsaved-document review.")

(defvar glassmacs-unsaved-review-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'glassmacs-review-visit-document)
    (define-key map (kbd "o") #'glassmacs-review-visit-document)
    (define-key map (kbd "g") #'glassmacs-review-unsaved-documents)
    map)
  "Keymap for Glassmacs' unsaved-document review.")

(define-derived-mode glassmacs-unsaved-review-mode special-mode "Unsaved Review"
  "Review modified documents. Press RET to open the document at point."
  (use-local-map glassmacs-unsaved-review-mode-map))

(defun glassmacs-review-visit-document ()
  "Open the unsaved document at point in its own visible window."
  (interactive)
  (let ((buffer (get-text-property (point) 'glassmacs-review-buffer)))
    (unless (buffer-live-p buffer)
      (user-error "No live document at point"))
    (glassmacs--show-document-buffer buffer 'new-frame)))

(defun glassmacs--show-review-buffer (buffer)
  "Present unsaved-document review BUFFER without replacing a document."
  (if (display-graphic-p)
      (glassmacs--show-document-buffer buffer 'new-frame)
    (pop-to-buffer buffer)))

(defun glassmacs-review-unsaved-documents ()
  "List modified documents; RET opens the document at point."
  (interactive)
  (let ((buffers (glassmacs--modified-document-buffers)))
    (if (null buffers)
        (message "No modified documents")
      (with-current-buffer (get-buffer-create "*Glassmacs Unsaved Documents*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (glassmacs-unsaved-review-mode)
          (insert (format "%d modified document(s). Select a line and press RET to open.\n\n"
                          (length buffers)))
          (dolist (buffer buffers)
            (let ((begin (point)))
              (insert (format "%s%s\n"
                              (buffer-name buffer)
                              (with-current-buffer buffer
                                (if buffer-file-name
                                    (format " — %s" buffer-file-name)
                                  " — untitled"))))
              (put-text-property begin (point) 'glassmacs-review-buffer buffer)))
          (goto-char (point-min))
          (forward-line 2))
        (glassmacs--show-review-buffer (current-buffer))))))

(defun glassmacs-new-document ()
  "Create an untitled document using the configured opening policy."
  (interactive)
  (let* ((buffer (generate-new-buffer "Untitled"))
         (action (and (called-interactively-p 'interactive)
                      (glassmacs--document-opening-action buffer))))
    (if action
        (glassmacs--show-document-buffer buffer action)
      (switch-to-buffer buffer))
    buffer))

(defconst glassmacs-common-major-modes
  '(("R (ESS)" . glassmacs-r-mode)
    ("Emacs Lisp" . emacs-lisp-mode)
    ("Python" . python-mode)
    ("LaTeX" . LaTeX-mode)
    ("Markdown" . markdown-mode)
    ("Org" . org-mode)
    ("Text" . text-mode)
    ("Fundamental" . fundamental-mode))
  "Common modes offered when creating or changing Glassmacs buffers.")

(defun glassmacs--available-major-modes ()
  "Return available (DISPLAY . COMMAND) modes without loading packages."
  (cl-remove-if-not
   (lambda (entry)
     (let ((mode (cdr entry)))
       (or (and (fboundp mode) (not (eq mode 'glassmacs-r-mode)))
           (and (eq mode 'glassmacs-r-mode) (locate-library "ess-r-mode"))
           (and (eq mode 'markdown-mode) (locate-library "markdown-mode"))
           (and (eq mode 'org-mode) (locate-library "org"))
           (and (eq mode 'LaTeX-mode) (locate-library "tex-mode")))))
   glassmacs-common-major-modes))

(defun glassmacs--read-major-mode ()
  "Read a supported major mode using completion."
  (let* ((choices (glassmacs--available-major-modes))
         (selection (completing-read "Major mode: " choices nil t)))
    (or (cdr (assoc selection choices))
        (user-error "No major mode selected"))))

(defun glassmacs-new-buffer-in-mode (mode &optional from-menu)
  "Create an untitled buffer using major MODE and the document-opening policy.
FROM-MENU applies the graphical document-opening policy for menu selection."
  (interactive (list (glassmacs--read-major-mode)))
  (unless (memq mode (mapcar #'cdr (glassmacs--available-major-modes)))
    (user-error "Unavailable major mode: %s" mode))
  (let ((buffer (generate-new-buffer "Untitled"))
        (interactive-call (or from-menu (called-interactively-p 'interactive))))
    (condition-case error-data
        (progn
          (with-current-buffer buffer
            (funcall mode)
            (when (and (eq mode 'glassmacs-r-mode)
                       (not (derived-mode-p 'ess-r-mode 'R-mode)))
              (user-error "ESS R mode is unavailable; install ESS first")))
          (let ((action (and interactive-call
                             (glassmacs--document-opening-action buffer))))
            (if action
                (glassmacs--show-document-buffer buffer action)
              (switch-to-buffer buffer)))
          buffer)
      (error
       (when (buffer-live-p buffer)
         (kill-buffer buffer))
       (signal (car error-data) (cdr error-data))))))

(defun glassmacs-change-buffer-mode (mode)
  "Change the current buffer to major MODE after confirmation."
  (interactive (list (glassmacs--read-major-mode)))
  (unless (memq mode (mapcar #'cdr (glassmacs--available-major-modes)))
    (user-error "Unavailable major mode: %s" mode))
  (unless (or (eq major-mode mode)
              (not (called-interactively-p 'interactive))
              (yes-or-no-p (format "Change buffer mode to %s? " mode)))
    (user-error "Mode change canceled"))
  (funcall mode)
  (when (and (eq mode 'glassmacs-r-mode)
             (not (derived-mode-p 'ess-r-mode 'R-mode)))
    (user-error "ESS R mode is unavailable; install ESS first")))

(defvar glassmacs-new-buffer-mode-menu
  (let ((map (make-sparse-keymap "New Buffer in Mode")))
    (dolist (entry (reverse glassmacs-common-major-modes))
      (let* ((label (car entry))
             (mode (cdr entry))
             (command (lambda ()
                        (interactive)
                        (glassmacs-new-buffer-in-mode mode t))))
        (define-key map (vector mode)
          `(menu-item ,label ,command
                      :enable (assoc ,label (glassmacs--available-major-modes))))))
    (define-key map [other]
      '(menu-item "Other Mode…" glassmacs-new-buffer-in-mode))
    map)
  "Selectable major modes for File → New Buffer in Mode.")

(glassmacs-menu-install-dynamic-keys glassmacs-new-buffer-mode-menu)

(defcustom glassmacs-mode-line-buffer-navigation 'documents
  "How clicking the mode-line buffer name navigates.
The `documents' setting focuses an existing document frame rather than
cycling unrelated buffers into the current document window.  Choose
`emacs' to retain the upstream mode-line mouse actions."
  :type '(choice (const :tag "Focus open documents" documents)
                 (const :tag "Standard Emacs buffer cycling" emacs))
  :group 'glassmacs-frames)

(defun glassmacs--window-navigation-choices ()
  "Return visible, live application windows with stable descriptive labels.
Do not include hidden minibuffer windows or manufacture buffer views."
  (let (choices)
    (dolist (frame (frame-list))
      (when (and (frame-live-p frame)
                 (frame-visible-p frame))
        (dolist (window (window-list frame 'never))
          (let ((buffer (window-buffer window)))
            (when (and (window-live-p window)
                       (buffer-live-p buffer)
                       (not (string-prefix-p " " (buffer-name buffer))))
              (let* ((kind (cond
                            ((buffer-file-name buffer) "Document")
                            ((with-current-buffer buffer
                               (derived-mode-p 'inferior-ess-r-mode)) "R Console")
                            ((with-current-buffer buffer
                               (derived-mode-p 'help-mode 'ess-help-mode)) "Help")
                            ((string-match-p "\\*Customize" (buffer-name buffer))
                             "Preferences")
                            (t "Other")))
                     (label (format "%s — %s [frame %s, window %s]"
                                    kind (buffer-name buffer)
                                    (frame-parameter frame 'name)
                                    (or (window-parameter window 'window-id)
                                        (cl-position window
                                                     (window-list frame 'never))))))
                (push (cons label window) choices)))))))
    (nreverse choices)))

(defun glassmacs-focus-open-window ()
  "Focus an existing application window without changing its buffer.
Unlike document opening, this never creates a frame or replaces a view."
  (interactive)
  (let* ((choices (glassmacs--window-navigation-choices))
         (choice (completing-read "Focus window: " choices nil t))
         (window (cdr (assoc choice choices))))
    (unless (window-live-p window)
      (user-error "Selected window is no longer available"))
    (select-frame-set-input-focus (window-frame window))
    (select-window window)
    window))

(defun glassmacs--install-reviewed-tab-close-menu ()
  "Expose reviewed tab closing without advising upstream tab-bar APIs.
The explicit Glassmacs menu command preserves the native frame-close
guard and does not intercept package-internal tab operations."
  (when (eq system-type 'darwin)
    (define-key global-map [menu-bar window glassmacs-close-tab]
      '(menu-item "Close Current Tab Safely" glassmacs-close-current-tab
                  :enable (menu-bar-non-minibuffer-window-p)))))

(defun glassmacs--install-window-navigation-menu ()
  "Expose non-destructive native window navigation."
  (when (eq system-type 'darwin)
    (define-key global-map [menu-bar window glassmacs-focus-window]
      '(menu-item "Focus Open Window…" glassmacs-focus-open-window))))

(with-eval-after-load 'menu-bar
  (glassmacs--install-window-navigation-menu)
  (glassmacs--install-reviewed-tab-close-menu))

(defvar glassmacs--mode-line-original-mouse-1 nil)
(defvar glassmacs--mode-line-original-mouse-3 nil)

(defun glassmacs--mode-line-document-click (event)
  "Focus an open document after clicking the mode-line name at EVENT."
  (interactive "e")
  (if (eq glassmacs-mode-line-buffer-navigation 'emacs)
      (let ((original (if (eq (event-basic-type event) 'mouse-3)
                          glassmacs--mode-line-original-mouse-3
                        glassmacs--mode-line-original-mouse-1)))
        (when (commandp original)
          (call-interactively original)))
    (let ((window (posn-window (event-start event))))
      (when (window-live-p window)
        (select-window window)))
    (glassmacs-focus-open-document)))

(defun glassmacs--install-mode-line-document-navigation ()
  "Install document-centric mode-line navigation without disabling Emacs opt-in."
  (when (and (eq system-type 'darwin)
             (boundp 'mode-line-buffer-identification-keymap)
             (keymapp mode-line-buffer-identification-keymap))
    (setq glassmacs--mode-line-original-mouse-1
          (lookup-key mode-line-buffer-identification-keymap
                      [mode-line mouse-1])
          glassmacs--mode-line-original-mouse-3
          (lookup-key mode-line-buffer-identification-keymap
                      [mode-line mouse-3]))
    (define-key mode-line-buffer-identification-keymap [mode-line mouse-1]
      #'glassmacs--mode-line-document-click)
    (define-key mode-line-buffer-identification-keymap [mode-line mouse-3]
      #'glassmacs--mode-line-document-click)))

(defun glassmacs--install-document-menu ()
  "Route macOS File menu open commands through Glassmacs' document policy."
  (when (and (eq system-type 'darwin) (display-graphic-p))
    (define-key global-map [menu-bar file glassmacs-close-document]
      '(menu-item "Close Document" glassmacs-close-document
                  :enable (menu-bar-non-minibuffer-window-p)))
    (define-key global-map [menu-bar file glassmacs-review-unsaved]
      '(menu-item "Review Unsaved Documents…" glassmacs-review-unsaved-documents))
    (define-key global-map [menu-bar file glassmacs-new-in-mode]
      (cons "New Buffer in Mode" glassmacs-new-buffer-mode-menu))
    (define-key global-map [menu-bar file glassmacs-change-mode]
      '(menu-item "Change Buffer Mode…" glassmacs-change-buffer-mode
                  :enable (menu-bar-non-minibuffer-window-p)))
    (define-key global-map [menu-bar file new-document]
      '(menu-item "New Document" glassmacs-new-document
                  :enable (menu-bar-non-minibuffer-window-p)))
    (define-key global-map [menu-bar file open-file]
      '(menu-item "Open File..." glassmacs-open-file
                  :enable (menu-bar-non-minibuffer-window-p)))
    ;; "Visit New File" duplicated "Open File" exactly.  Keep one route
    ;; through the document presentation policy; remove the obsolete entry.
    (define-key global-map [menu-bar file new-file] nil))

  (when (keymapp (lookup-key global-map [menu-bar file]))
    (glassmacs-menu-install-dynamic-keys
     (lookup-key global-map [menu-bar file])
     '(glassmacs-close-document glassmacs-review-unsaved glassmacs-new-in-mode
       glassmacs-change-mode new-document open-file))))

(with-eval-after-load 'menu-bar
  (glassmacs--install-document-menu))

(glassmacs--install-file-keybindings)
(glassmacs--install-mode-line-document-navigation)

(require 'glassmacs-buffer-placement)

(provide 'glassmacs-frames)
;;; glassmacs-frames.el ends here
