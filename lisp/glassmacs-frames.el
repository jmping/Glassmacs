;;; glassmacs-frames.el --- Document and frame behavior -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)

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

(defun glassmacs-open-document-preferences ()
  "Open the dedicated document and window opening preferences."
  (interactive)
  (customize-group 'glassmacs-frames))

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

(defun glassmacs--show-document-buffer (buffer action)
  "Display BUFFER according to ACTION.
With no visible frame, BUFFER is shown in the retained frame instead of
creating an additional one."
  (let ((visible-window (get-buffer-window buffer t)))
    (cond
     ((and (fboundp 'glassmacs--ensure-visible-frame)
           (glassmacs--ensure-visible-frame))
      (switch-to-buffer buffer))
     (visible-window
      (select-frame-set-input-focus (window-frame visible-window))
      (select-window visible-window))
     ((eq action 'new-frame)
      (let ((frame (make-frame)))
        (with-selected-frame frame
          (switch-to-buffer buffer))
        (select-frame-set-input-focus frame)))
     ((eq action 'new-tab)
      (require 'tab-bar)
      (tab-bar-mode 1)
      (tab-bar-new-tab)
      (switch-to-buffer buffer))
     (t
      (switch-to-buffer buffer)))))

(defun glassmacs-open-file (filename &optional wildcards)
  "Open FILENAME interactively using Glassmacs' document policy."
  (interactive (find-file-read-args "Find file: "
                                    confirm-nonexistent-file-or-buffer))
  (glassmacs--open-file-with-policy
   filename wildcards (called-interactively-p 'interactive)))

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

(defun glassmacs--buffer-shown-elsewhere-p (buffer windows)
  "Return non-nil when BUFFER is visible in a window not in WINDOWS."
  (cl-some (lambda (window) (not (memq window windows)))
           (get-buffer-window-list buffer nil t)))

(defun glassmacs--resolve-unsaved-changes (buffer)
  "Ask how to handle unsaved changes in BUFFER before closing it.
Return non-nil when closing may proceed: the buffer was unmodified,
was saved, or its changes were explicitly discarded.  Return nil when
the user cancels or the save does not complete."
  (if (not (buffer-modified-p buffer))
      t
    (pcase (car (read-multiple-choice
                 (format "Save changes to %s before closing? " (buffer-name buffer))
                 '((?s "save" "Save the document, then close it")
                   (?d "don't save" "Discard the unsaved changes and close")
                   (?c "cancel" "Keep the document open"))))
      (?s (with-current-buffer buffer (save-buffer))
          (not (buffer-modified-p buffer)))
      (?d (with-current-buffer buffer (set-buffer-modified-p nil))
          t)
      (_ nil))))

(defun glassmacs--close-documents-in-windows (windows)
  "Close the documents shown only in WINDOWS, asking about unsaved changes.
Only ordinary documents are closed (see
`glassmacs--ordinary-document-buffer-p'): consoles, Help, Dired and
other special buffers stay alive, so closing a window never stops an R
session.  A document also visible in another window stays open.  Return
nil, closing nothing further, as soon as the user cancels."
  (catch 'canceled
    (dolist (buffer (delete-dups (mapcar #'window-buffer windows)) t)
      (when (and (glassmacs--ordinary-document-buffer-p buffer)
                 (not (glassmacs--buffer-shown-elsewhere-p buffer windows)))
        (unless (and (glassmacs--resolve-unsaved-changes buffer)
                     (kill-buffer buffer))
          (throw 'canceled nil))))))

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

(defun glassmacs-close-document ()
  "Close the selected window and its document, as Command-W does on a Mac.
If the window shows an ordinary document that no other window shows,
ask whether to save unsaved changes (Save, Don't Save, Cancel) and
then close the document.  Special buffers such as R consoles and Help
are never killed; only their window closes.  Then close the window, its
tab, or its frame."
  (interactive)
  (when (active-minibuffer-window)
    (abort-recursive-edit))
  (let ((window (selected-window)))
    (if (glassmacs--close-documents-in-windows (list window))
        (glassmacs--close-view window)
      (message "Close canceled"))))

(defun glassmacs-close-frame-documents (frame)
  "Close the documents shown only in FRAME before the frame closes.
Used for the window close button.  Return nil when the user cancels,
in which case the frame must stay open."
  (or (not (framep frame))
      (not (frame-live-p frame))
      (glassmacs--close-documents-in-windows (window-list frame 'never))))

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
    map)
  "Selectable major modes for File → New Buffer in Mode.")

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
    (define-key global-map [menu-bar file new-file]
      '(menu-item "Visit New File..." glassmacs-open-file
                  :enable (menu-bar-non-minibuffer-window-p)))))

(with-eval-after-load 'menu-bar
  (glassmacs--install-document-menu))

(provide 'glassmacs-frames)
;;; glassmacs-frames.el ends here
