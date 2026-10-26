;;; glassmacs-frames.el --- Document and frame behavior -*- lexical-binding: t; -*-

(require 'cl-lib)

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

(defun glassmacs--ordinary-document-buffer-p (buffer)
  "Return non-nil when BUFFER is an ordinary document buffer."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (and (not (derived-mode-p 'special-mode 'dired-mode 'comint-mode))
              (not (get-buffer-process buffer))
              (or buffer-file-name
                  (not (string-match-p "\\`\\*" (buffer-name))))))))

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
       (or (fboundp mode)
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

(defun glassmacs-new-buffer-in-mode (mode)
  "Create a fresh untitled document using major MODE.
Interactive requests follow the current document-opening policy."
  (interactive (list (glassmacs--read-major-mode)))
  (unless (memq mode (mapcar #'cdr (glassmacs--available-major-modes)))
    (user-error "Unavailable major mode: %s" mode))
  (let ((buffer (generate-new-buffer "Untitled"))
        (interactive-call (called-interactively-p 'interactive)))
    (condition-case error-data
        (progn
          (with-current-buffer buffer
            (funcall mode))
          (let ((action (and interactive-call
                             (glassmacs--document-opening-action buffer))))
            (glassmacs--show-document-buffer buffer action))
          buffer)
      (error
       (when (buffer-live-p buffer) (kill-buffer buffer))
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
  (funcall mode))

(defun glassmacs--install-document-menu ()
  "Route macOS File menu open commands through Glassmacs' document policy."
  (when (and (eq system-type 'darwin) (display-graphic-p))
    (define-key global-map [menu-bar file glassmacs-new-in-mode]
      '(menu-item "New Buffer in Mode…" glassmacs-new-buffer-in-mode
                  :enable (menu-bar-non-minibuffer-window-p)))
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
