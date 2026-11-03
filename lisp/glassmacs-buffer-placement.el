;;; glassmacs-buffer-placement.el --- Explicit buffer view relocation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)
(require 'tab-bar)


(defgroup glassmacs-buffer-placement nil
  "Explicit placement of Glassmacs buffer views."
  :group 'glassmacs-frames)

(defun glassmacs-buffer-placement--frame-label (frame)
  "Return a document-aware label for FRAME.
Use the visible buffer's directory, never the invoking document's
directory, and identify registered R consoles by session and directory."
  (let* ((window (frame-selected-window frame))
         (buffer (and (window-live-p window) (window-buffer window)))
         (session (and (buffer-live-p buffer)
                       (fboundp 'glassmacs-sessions-find)
                       (get-buffer-process buffer)
                       (glassmacs-sessions-find (get-buffer-process buffer))))
         (directory (and (buffer-live-p buffer)
                         (buffer-local-value 'default-directory buffer))))
    (format "%s — %s%s"
            (or (frame-parameter frame 'name) "Window")
            (if session
                (glassmacs-sessions--describe session)
              (if (buffer-live-p buffer) (buffer-name buffer) "Empty"))
            (if (and directory (not session))
                (format " — %s" (abbreviate-file-name directory))
              ""))))

(defun glassmacs-buffer-placement--choose-frame ()
  "Select an existing live frame by its displayed document."
  (let* ((frames (cl-remove-if-not #'frame-visible-p (frame-list)))
         (choices (cl-loop for frame in frames
                           for index from 1
                           collect (cons (format "%d: %s" index
                                                 (glassmacs-buffer-placement--frame-label frame))
                                         frame))))
    (cdr (assoc (completing-read "Destination window: " choices nil t)
                choices))))

(defun glassmacs-buffer-placement--display (buffer placement &optional frame)
  "Display BUFFER using PLACEMENT, optionally in FRAME.
Return the destination Emacs window; never kill BUFFER."
  (pcase placement
    ('new-frame
     (let ((new (make-frame)))
       (with-selected-frame new
         (switch-to-buffer buffer)
         (selected-window))))
    ('new-tab
     (with-selected-frame (or frame (selected-frame))
       (require 'tab-bar)
       (tab-bar-mode 1)
       (tab-bar-new-tab)
       (switch-to-buffer buffer)
       (selected-window)))
    ((or 'split-right 'split-below)
     (with-selected-frame (or frame (selected-frame))
       (let ((window (split-window (frame-selected-window (or frame (selected-frame))) nil
                                   (if (eq placement 'split-right) 'right 'below))))
         (set-window-buffer window buffer)
         window)))
    ('replace
     (with-selected-frame (or frame (selected-frame))
       (let ((window (frame-selected-window (or frame (selected-frame)))))
         (set-window-buffer window buffer)
         window)))
    (_ (user-error "Unsupported buffer placement: %s" placement))))

(defun glassmacs-buffer-placement--source-view-live-p (window buffer)
  "Whether WINDOW still displays BUFFER."
  (and (window-live-p window) (eq (window-buffer window) buffer)))

(defun glassmacs-buffer-placement--remove-source-view (source destination buffer
                                                        source-frame source-tab)
  "Remove the original view of BUFFER after DESTINATION is established.
SOURCE-FRAME and SOURCE-TAB identify the original tab even if creating
the destination changed the selected tab in that frame."
  (when (and (not (eq source destination))
             (frame-live-p source-frame))
    (with-selected-frame source-frame
      (when (and source-tab (bound-and-true-p tab-bar-mode))
        (tab-bar-select-tab source-tab))
      (when (glassmacs-buffer-placement--source-view-live-p source buffer)
        (cond
         ((> (length (window-list source-frame 'never)) 1)
          (delete-window source))
         (t
          (with-selected-window source
            (switch-to-buffer (other-buffer buffer t)))))))))

(defvar glassmacs-buffer-placement--clicked-window nil
  "Deprecated compatibility variable; no longer used to target commands.")

(defun glassmacs-buffer-placement--source-window ()
  "Use the clicked window for context-menu commands when possible."
  (let ((event last-input-event))
    (if (and (consp event) (mouse-event-p event))
        (let ((window (posn-window (event-start event))))
          (if (window-live-p window) window (selected-window)))
      (selected-window))))

(defvar glassmacs-buffer-placement--last-move nil
  "Most recent move:
(BUFFER SOURCE-FRAME SOURCE-WINDOW SOURCE-TAB SOURCE-REPLACEMENT
 DESTINATION DESTINATION-FRAME DESTINATION-TAB).
The undo operation never overwrites an unrelated destination buffer.")

(defun glassmacs-undo-last-buffer-move ()
  "Restore the last moved buffer without overwriting unrelated documents.
If the original window is gone, create a new split in its frame.
An unavailable original frame leaves the move record intact."
  (interactive)
  (pcase glassmacs-buffer-placement--last-move
    (`(,buffer ,frame ,original ,tab ,source-replacement
               ,moved-to ,destination-frame ,destination-tab)
     (unless (and (buffer-live-p buffer) (frame-live-p frame))
       (user-error "Original buffer or frame is unavailable"))
     (let ((destination nil))
       (with-selected-frame frame
         (when (and tab (bound-and-true-p tab-bar-mode))
           (tab-bar-select-tab tab))
         (setq destination
               (if (and (window-live-p original)
                        (eq (window-frame original) frame)
                        (or (eq (window-buffer original) buffer)
                            (and source-replacement
                                 (eq (window-buffer original)
                                     source-replacement))))
                   original
                 (condition-case nil
                     (split-window (frame-selected-window frame) nil 'right)
                   (error nil))))
         (unless destination
           (user-error "Cannot restore view without replacing another document"))
         (set-window-buffer destination buffer))
       (when (frame-live-p destination-frame)
         (with-selected-frame destination-frame
           (when (and destination-tab (bound-and-true-p tab-bar-mode))
             (tab-bar-select-tab destination-tab))
           (when (and (window-live-p moved-to)
                      (not (eq moved-to destination))
                      (eq (window-buffer moved-to) buffer))
             (if (> (length (window-list destination-frame 'never)) 1)
                 (delete-window moved-to)
               (with-selected-window moved-to
                 (switch-to-buffer (other-buffer buffer t)))))))
       (setq glassmacs-buffer-placement--last-move nil)
       (when (and tab (bound-and-true-p tab-bar-mode))
         (with-selected-frame frame
           (tab-bar-select-tab tab)))
       (select-frame-set-input-focus frame)
       (select-window destination)))
    (_ (user-error "No buffer move to undo"))))

(defun glassmacs-move-buffer-to (placement &optional frame source)
  "Move the current buffer view to PLACEMENT without killing its buffer.
For existing-window placements, FRAME is selected interactively.
Use `glassmacs-show-buffer-in' to retain the original view."
  (interactive
   (let* ((placement (intern (completing-read
                              "Move buffer to: "
                              '("new-frame" "new-tab" "split-right"
                                "split-below" "replace")
                              nil t)))
          (frame (unless (eq placement 'new-frame)
                   (glassmacs-buffer-placement--choose-frame))))
     (list placement frame)))
  (when (and (not (eq placement 'new-frame))
             (not (frame-live-p frame)))
    (user-error "Destination window is no longer available"))
  (let* ((source (or source (glassmacs-buffer-placement--source-window)))
         (buffer (window-buffer source))
         (point (window-point source))
         (start (window-start source))
         (source-frame (window-frame source))
         (source-tab
          (progn
            (when (and (eq placement 'new-tab)
                       (eq source-frame (or frame (selected-frame))))
              (with-selected-frame source-frame
                (unless (bound-and-true-p tab-bar-mode)
                  (tab-bar-mode 1))))
            (when (bound-and-true-p tab-bar-mode)
              (with-selected-frame source-frame
                (1+ (tab-bar--current-tab-index))))))
         (destination (glassmacs-buffer-placement--display buffer placement frame))
         (destination-frame (window-frame destination))
         (destination-tab (when (bound-and-true-p tab-bar-mode)
                            (with-selected-frame destination-frame
                              (1+ (tab-bar--current-tab-index)))))
         source-replacement)
    (unless (and (window-live-p destination)
                 (eq (window-buffer destination) buffer))
      (error "Destination could not display buffer; original view retained"))
    (set-window-point destination point)
    (set-window-start destination start t)
    (glassmacs-buffer-placement--remove-source-view
     source destination buffer source-frame source-tab)
    (when (frame-live-p source-frame)
      (with-selected-frame source-frame
        (when (and source-tab (bound-and-true-p tab-bar-mode))
          (tab-bar-select-tab source-tab))
        (when (window-live-p source)
          (setq source-replacement (window-buffer source)))))
    (when (and destination-tab (frame-live-p destination-frame))
      (with-selected-frame destination-frame
        (tab-bar-select-tab destination-tab)))
    (setq glassmacs-buffer-placement--last-move
          (list buffer source-frame source source-tab source-replacement
                destination destination-frame destination-tab))
    (select-frame-set-input-focus (window-frame destination))
    (select-window destination)
    destination))

(defun glassmacs-show-buffer-in (placement &optional frame source)
  "Show the current buffer at PLACEMENT while retaining its original view."
  (interactive
   (let* ((placement (intern (completing-read
                              "Show buffer in: "
                              '("new-frame" "new-tab" "split-right"
                                "split-below" "replace")
                              nil t)))
          (frame (unless (eq placement 'new-frame)
                   (glassmacs-buffer-placement--choose-frame))))
     (list placement frame)))
  (when (and (not (eq placement 'new-frame))
             (not (frame-live-p frame)))
    (user-error "Destination window is no longer available"))
  (glassmacs-buffer-placement--display
   (window-buffer (or source (glassmacs-buffer-placement--source-window)))
   placement frame))

(defun glassmacs-buffer-placement--context-menu (menu click)
  "Add buffer placement actions to context MENU for CLICK's window.
Bind the source window in the menu command itself, so later menu-bar
commands cannot accidentally inherit an earlier right-click target."
  (let* ((window (and click (ignore-errors (posn-window click))))
         (source (if (window-live-p window) window (selected-window))))
    (define-key-after menu [glassmacs-move-buffer]
      `(menu-item "Move Buffer To…"
                  ,(lambda ()
                     (interactive)
                     (call-interactively
                      (lambda (placement frame)
                        (interactive
                         (let* ((placement (intern
                                            (completing-read
                                             "Move buffer to: "
                                             '("new-frame" "new-tab" "split-right"
                                               "split-below" "replace") nil t)))
                                (frame (unless (eq placement 'new-frame)
                                         (glassmacs-buffer-placement--choose-frame))))
                           (list placement frame)))
                        (glassmacs-move-buffer-to placement frame source))))))
    (define-key-after menu [glassmacs-show-buffer]
      `(menu-item "Show Buffer In…"
                  ,(lambda ()
                     (interactive)
                     (let* ((placement (intern
                                        (completing-read
                                         "Show buffer in: "
                                         '("new-frame" "new-tab" "split-right"
                                           "split-below" "replace") nil t)))
                            (frame (unless (eq placement 'new-frame)
                                     (glassmacs-buffer-placement--choose-frame))))
                       (glassmacs-show-buffer-in placement frame source))))
      'glassmacs-move-buffer))
  menu)

(defun glassmacs-buffer-placement-install ()
  "Install menu entries for manual buffer placement."
  (define-key global-map [menu-bar window glassmacs-move-buffer]
    '(menu-item "Move Buffer To…" glassmacs-move-buffer-to))
  (define-key global-map [menu-bar window glassmacs-undo-move]
    '(menu-item "Undo Last Buffer Move" glassmacs-undo-last-buffer-move))
  (define-key global-map [menu-bar window glassmacs-show-buffer]
    '(menu-item "Show Buffer In…" glassmacs-show-buffer-in))
  (with-eval-after-load 'context-menu
    (add-hook 'context-menu-functions
              #'glassmacs-buffer-placement--context-menu)))

(glassmacs-buffer-placement-install)

(provide 'glassmacs-buffer-placement)
;;; glassmacs-buffer-placement.el ends here
