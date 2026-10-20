;;; glassmacs-frames.el --- Document and frame behavior -*- lexical-binding: t; -*-

(defgroup glassmacs-frames nil
  "Document opening behavior for Glassmacs."
  :group 'glassmacs)

(defcustom glassmacs-document-opening-policy
  (if (eq system-type 'darwin) 'new-frame 'reuse-current)
  "How interactive document opens are displayed in graphical Emacs."
  :type '(choice (const :tag "New frame" new-frame)
                 (const :tag "New tab" new-tab)
                 (const :tag "Reuse current frame or tab" reuse-current))
  :group 'glassmacs-frames)

(defun glassmacs--ordinary-document-buffer-p (buffer)
  "Return non-nil when BUFFER is an ordinary document buffer."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (and (not (derived-mode-p 'special-mode 'dired-mode))
              (or buffer-file-name
                  (not (string-match-p "\\`\\*" (buffer-name))))))))

(defun glassmacs--document-opening-action (buffer)
  "Return the configured opening action for ordinary BUFFER, if applicable."
  (when (and (display-graphic-p)
             (glassmacs--ordinary-document-buffer-p buffer))
    glassmacs-document-opening-policy))

(defun glassmacs--show-document-buffer (buffer action)
  "Display BUFFER according to ACTION."
  (let ((visible-window (get-buffer-window buffer t)))
    (cond
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

(defun glassmacs--find-file-with-policy (original filename &optional wildcards)
  "Open FILENAME with ORIGINAL, applying the document policy interactively."
  (if (or (not (called-interactively-p 'interactive))
          wildcards
          (not (display-graphic-p)))
      (funcall original filename wildcards)
    (let ((buffer (find-file-noselect filename)))
      (if (glassmacs--document-opening-action buffer)
          (progn
            (glassmacs--show-document-buffer
             buffer (glassmacs--document-opening-action buffer))
            buffer)
        (switch-to-buffer buffer)))))

(defun glassmacs-new-document ()
  "Create an untitled document using the configured opening policy."
  (interactive)
  (let* ((buffer (generate-new-buffer "Untitled"))
         (action (glassmacs--document-opening-action buffer)))
    (if action
        (glassmacs--show-document-buffer buffer action)
      (switch-to-buffer buffer))
    buffer))

(when (fboundp 'find-file)
  (advice-add 'find-file :around #'glassmacs--find-file-with-policy))

(provide 'glassmacs-frames)
;;; glassmacs-frames.el ends here
