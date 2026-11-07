;;; glassmacs-presentation-model.el --- Read-only presentation roles -*- lexical-binding: t; -*-

;; This module deliberately has no startup hooks, window mutations, or advice.
;; It classifies buffers; it does not assign ownership of frames or processes.

(require 'cl-lib)

(defun glassmacs-presentation-buffer-role (buffer)
  "Return the presentation role of live BUFFER, or nil if it is dead.
Roles are `document', `r-source', `r-console', `r-help',
`preferences', `utility', and `internal'.  Classification is
read-only and does not infer that any existing view is suitable.
An indirect buffer inherits its base document's role unless it is
itself an R source chunk."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (let* ((name (buffer-name))
             (base (buffer-base-buffer))
             (base-file (and base (buffer-file-name base))))
        (cond
         ((derived-mode-p 'inferior-ess-r-mode) 'r-console)
         ((and (boundp 'ess-help-mode) ess-help-mode) 'r-help)
         ((or (derived-mode-p 'ess-help-mode)
              (string-match-p "\\*help\\[R\\]\\|\\*R Help\\|\\*help\\[R" name))
          'r-help)
         ((or (derived-mode-p 'ess-r-mode 'R-mode)
              (and (or buffer-file-name base-file)
                   (string-match-p "\\.[Rr]\\'" (or buffer-file-name base-file))))
          'r-source)
         ((or (derived-mode-p 'Custom-mode)
              (string-match-p "\\*Customize\\|\\*Glassmacs Preferences" name))
          'preferences)
         ((or buffer-file-name base-file) 'document)
         ((string-prefix-p " " name) 'internal)
         ((string-prefix-p "*" name) 'utility)
         (t 'document))))))

(defun glassmacs-presentation-policy-action (intent placement role)
  "Resolve a presentation action without changing any windows.
INTENT is open, focus, new-view, move, split, tab or replace.
PLACEMENT is the requested policy.  ROLE is informational and may
be nil; it never implies ownership of an existing view."
  (unless (memq intent '(open focus new-view move split tab replace))
    (user-error "Unsupported presentation intent: %s" intent))
  (unless (memq role '(nil document r-source r-console r-help preferences utility internal))
    (user-error "Unsupported presentation role: %s" role))
  (pcase intent
    ('move (or placement 'new-frame))
    ('split (if (memq placement '(split-right split-below))
                placement 'split-below))
    ('tab 'new-tab)
    ('replace 'replace)
    (_ (or placement 'reuse-current))))

(defun glassmacs-presentation-view-suitable-p (window buffer intent placement
                                                     &optional destination)
  "Whether WINDOW is an appropriate existing view for BUFFER.
Only open and focus may reuse an existing view.  Explicit new-view,
move, split, tab and replace intents never reuse it.  For a new-frame
policy, the view must be the frame's sole ordinary window; a
destination, when supplied, must be the view's own frame.
This is read-only: it never selects or mutates WINDOW."
  (and (window-live-p window)
       (buffer-live-p buffer)
       (eq (window-buffer window) buffer)
       (memq intent '(open focus))
       (or (null destination) (eq (window-frame window) destination))
       (pcase (glassmacs-presentation-policy-action
               intent placement (glassmacs-presentation-buffer-role buffer))
         ('new-frame
          (and (not (window-minibuffer-p window))
               (eq window (frame-root-window (window-frame window)))))
         ('new-tab
          ;; A view in a different tab may still be reused by focusing it.
          ;; Tab identity is resolved by the caller, not by buffer ownership.
          (not (window-minibuffer-p window)))
         (_ (not (window-minibuffer-p window))))))

(defun glassmacs-presentation-find-suitable-view (buffer intent placement
                                                        &optional destination)
  "Find a suitable visible view of BUFFER, not merely its first view.
Prefer a view in DESTINATION, then the selected frame, before searching
other frames.  Never change selection or create windows.  This only
examines windows in their currently selected tabs; callers must not
silently switch tabs to locate a buffer."
  (when (buffer-live-p buffer)
    (let* ((frames (if (and destination (frame-live-p destination))
                       (list destination)
                     (cons (selected-frame)
                           (delq (selected-frame) (frame-list))))))
      (cl-loop for frame in frames
               thereis
               (cl-find-if
                (lambda (window)
                  (glassmacs-presentation-view-suitable-p
                   window buffer intent placement destination))
                (window-list frame 'never)))))

(provide 'glassmacs-presentation-model)
;;; glassmacs-presentation-model.el ends here
