;;; glassmacs-macos.el --- macOS application integration -*- lexical-binding: t; -*-

(require 'cl-lib)

(defvar glassmacs--hidden-final-frame nil
  "The final macOS graphical frame hidden to keep Glassmacs running.")

(defun glassmacs--show-hidden-final-frame ()
  "Show the retained final frame, returning non-nil when it is live."
  (let ((frame glassmacs--hidden-final-frame))
    (cond
     ((not (frame-live-p frame))
      (setq glassmacs--hidden-final-frame nil)
      nil)
     (t
      (setq glassmacs--hidden-final-frame nil)
      (unless (eq (frame-visible-p frame) t)
        (make-frame-visible frame))
      (select-frame-set-input-focus frame)
      t))))

(defun glassmacs--macos-graphical-frames ()
  "Return live graphical frames in the current macOS Emacs process."
  (cl-remove-if-not
   (lambda (frame)
     (and (frame-live-p frame) (display-graphic-p frame)))
   (frame-list)))

;; Frames hidden by the final-window close stay selected, so a command run
;; with no visible frame would draw into an invisible window.
(defun glassmacs--no-visible-graphical-frame-p ()
  "Return non-nil on macOS when no graphical frame is visible."
  (and (eq system-type 'darwin)
       (display-graphic-p)
       (not (cl-some (lambda (frame)
                       (and (frame-visible-p frame)
                            (not (frame-parent frame))))
                     (glassmacs--macos-graphical-frames)))))

(defun glassmacs--ensure-visible-frame ()
  "Reveal the retained frame when no graphical frame is visible.
Return non-nil when a frame was revealed."
  (and (glassmacs--no-visible-graphical-frame-p)
       (glassmacs--show-hidden-final-frame)))

(defvar glassmacs--commands-that-stay-windowless
  '(save-buffers-kill-emacs kill-emacs ns-do-hide-emacs ns-do-hide-others
    ignore delete-frame handle-delete-frame glassmacs-reopen
    glassmacs-new-window)
  "Commands that must not reveal the retained frame afterwards.")

(defvar glassmacs--command-started-windowless nil
  "Non-nil when the current command began with no visible frame.")

(defun glassmacs--note-windowless-command-start ()
  "Record whether the command about to run starts with no visible frame."
  (setq glassmacs--command-started-windowless
        (glassmacs--no-visible-graphical-frame-p)))

(defun glassmacs--reveal-frame-after-windowless-command ()
  "Show the retained frame after a menu or key command ran with none visible.
Commands such as buffer selection otherwise display into an invisible frame."
  (when (and glassmacs--command-started-windowless
             (not (memq this-command glassmacs--commands-that-stay-windowless)))
    (setq glassmacs--command-started-windowless nil)
    (glassmacs--ensure-visible-frame)))

(defun glassmacs--delete-frame-preserving-app (original &optional frame force)
  "Keep the final macOS graphical frame alive when closing its window.
ORIGINAL is the original `delete-frame' function.  FRAME and FORCE are
the arguments passed to it."
  (let* ((frame (or frame (selected-frame)))
         (frames (glassmacs--macos-graphical-frames)))
    (if (and (eq system-type 'darwin)
             (memq frame frames)
             (= (length frames) 1))
        (progn
          (make-frame-invisible frame t)
          (setq glassmacs--hidden-final-frame frame)
          nil)
      (funcall original frame force))))

;; Cocoa window-close events reach `handle-delete-frame', which calls
;; `save-buffers-kill-emacs' when no other frame is visible, bypassing
;; `delete-frame'.  Explicit Quit does not use this path.
(defun glassmacs--handle-delete-frame-preserving-app (original event)
  "Hide the final visible macOS frame instead of killing Emacs.
ORIGINAL is `handle-delete-frame'; EVENT is the delete-frame event."
  (let ((frame (posn-window (event-start event))))
    (if (and (eq system-type 'darwin)
             (frame-live-p frame)
             (display-graphic-p frame)
             (not (frame-parent frame))
             (not (cl-some
                   (lambda (other)
                     (and (not (eq other frame))
                          (frame-visible-p other)
                          (not (frame-parent other))
                          (not (frame-parameter other 'delete-before))))
                   (frame-list))))
        (progn
          (make-frame-invisible frame t)
          (setq glassmacs--hidden-final-frame frame)
          nil)
      (funcall original event))))

(defun glassmacs-new-window ()
  "Show the retained hidden frame, or create a new graphical frame.
The new frame displays an existing buffer; use `glassmacs-new-document'
for a distinct untitled buffer."
  (interactive)
  (unless (and (eq system-type 'darwin)
               (glassmacs--show-hidden-final-frame))
    (make-frame-command)))

(defun glassmacs-open-preferences ()
  "Open the Glassmacs Customize group."
  (interactive)
  (customize-group 'glassmacs))

(defun glassmacs--install-native-preferences-command ()
  "Route Cocoa's native Preferences item to Glassmacs settings."
  (when (eq system-type 'darwin)
    (define-key global-map [ns-show-prefs] #'glassmacs-open-preferences)))

(defun glassmacs-reveal-in-finder ()
  "Reveal the current local file in Finder."
  (interactive)
  (unless (and buffer-file-name (not (file-remote-p buffer-file-name)))
    (user-error "Visit a local file before revealing it in Finder"))
  (unless (file-exists-p buffer-file-name)
    (user-error "Save this file before revealing it in Finder"))
  (unless (and (eq system-type 'darwin) (executable-find "open"))
    (user-error "Finder integration is available only on macOS"))
  (unless (equal 0 (call-process "open" nil nil nil "-R" (expand-file-name buffer-file-name)))
    (user-error "Finder could not reveal this file")))

(defun glassmacs-select-opening-new-frame ()
  "Open documents in new frames." (interactive)
  (glassmacs-set-document-opening-policy 'new-frame))
(defun glassmacs-select-opening-new-tab ()
  "Open documents in new tabs." (interactive)
  (glassmacs-set-document-opening-policy 'new-tab))
(defun glassmacs-select-opening-reuse-current ()
  "Reuse the current window for document opens." (interactive)
  (glassmacs-set-document-opening-policy 'reuse-current))

(require 'recentf)

(defun glassmacs-open-recent-file (filename)
  "Open a recent FILENAME using the configured document policy."
  (interactive (list (completing-read "Open recent file: " recentf-list nil t)))
  (unless (member filename recentf-list)
    (user-error "Not a recent file: %s" filename))
  (unless (file-exists-p filename)
    (user-error "Recent file no longer exists: %s" filename))
  (glassmacs--open-file-with-policy filename nil t))

(defun glassmacs-clear-recent-files ()
  "Clear recent file history after explicit confirmation."
  (interactive)
  (when (yes-or-no-p "Clear recent file history? ")
    (setq recentf-list nil)
    (recentf-save-list)
    (message "Recent file history cleared")))

(defun glassmacs-recent-files-preferences ()
  "Customize recent-file history, exclusions, and limits."
  (interactive)
  (customize-group 'recentf))

(defun glassmacs-print-document ()
  "Print the current document using the available Emacs print command.
On the Cocoa port this is `ns-print-buffer' (defined in ns-win.el), which
asks for confirmation and then calls `print-buffer'; elsewhere it calls
`print-buffer' directly.  Both use the `lpr' spooler backend: GNU Emacs
does not provide a native macOS print dialog."
  (interactive)
  (when (derived-mode-p 'special-mode 'comint-mode)
    (user-error "Select a document buffer before printing"))
  (cond
   ((fboundp 'ns-print-buffer) (call-interactively #'ns-print-buffer))
   ((fboundp 'print-buffer) (call-interactively #'print-buffer))
   (t (user-error "No printing backend is available"))))

(defun glassmacs--install-macos-menus ()
  "Install Glassmacs menu items while preserving upstream menus."
  (when (and (eq system-type 'darwin) (display-graphic-p))
    (let ((glassmacs-menu (make-sparse-keymap "Glassmacs"))
          (keyboard-menu (make-sparse-keymap "Keyboard Profile"))
          (opening-menu (make-sparse-keymap "Document Opening"))
          (file-menu (lookup-key global-map [menu-bar file]))
          (window-menu (lookup-key global-map [menu-bar window])))
      (define-key glassmacs-menu [document-opening] opening-menu)
      (define-key opening-menu [new-frame]
        '(menu-item "New Frame" glassmacs-select-opening-new-frame
                    :button (:radio (eq glassmacs-document-opening-policy 'new-frame))))
      (define-key opening-menu [new-tab]
        '(menu-item "New Tab" glassmacs-select-opening-new-tab
                    :button (:radio (eq glassmacs-document-opening-policy 'new-tab))))
      (define-key opening-menu [reuse-current]
        '(menu-item "Reuse Current Window" glassmacs-select-opening-reuse-current
                    :button (:radio (eq glassmacs-document-opening-policy 'reuse-current))))
      (define-key glassmacs-menu [document-preferences]
        '(menu-item "Document Preferences…" glassmacs-open-document-preferences))
      (define-key glassmacs-menu [review-unsaved]
        '(menu-item "Review Unsaved Documents…" glassmacs-review-unsaved-documents))
      (define-key glassmacs-menu [keyboard-profile] keyboard-menu)
      (define-key keyboard-menu [hybrid]
        '(menu-item "Hybrid macOS / Emacs"
                    glassmacs-select-hybrid-keyboard-profile
                    :button (:radio
                             (eq glassmacs-keyboard-profile
                                 'glassmacs-hybrid))))
      (define-key keyboard-menu [traditional]
        '(menu-item "Traditional Emacs"
                    glassmacs-select-traditional-keyboard-profile
                    :button (:radio
                             (eq glassmacs-keyboard-profile
                                 'traditional-emacs))))
      (define-key global-map [menu-bar glassmacs] glassmacs-menu)
      (when (keymapp file-menu)
        (define-key file-menu [glassmacs-reveal-in-finder]
          '(menu-item "Reveal in Finder" glassmacs-reveal-in-finder
                      :enable (and buffer-file-name
                                   (not (file-remote-p buffer-file-name)))))
        (define-key file-menu [glassmacs-print-document]
          '(menu-item "Print Document…" glassmacs-print-document))
        (define-key file-menu [glassmacs-open-recent]
          '(menu-item "Open Recent…" glassmacs-open-recent-file))
        (define-key file-menu [glassmacs-clear-recent]
          '(menu-item "Clear Recent Files…" glassmacs-clear-recent-files))
        (define-key file-menu [glassmacs-recent-preferences]
          '(menu-item "Recent Files Preferences…" glassmacs-recent-files-preferences))
        (define-key file-menu [glassmacs-new-window]
          '(menu-item "New Window" glassmacs-new-window
                      :enable (display-graphic-p))))
      (unless (keymapp window-menu)
        (setq window-menu (make-sparse-keymap "Window"))
        (define-key global-map [menu-bar window] window-menu))
      (define-key-after window-menu [glassmacs-new-window]
        '(menu-item "New Window" glassmacs-new-window
                    :enable (display-graphic-p))))))

(defun glassmacs--install-macos-menus-for-frame (&optional frame)
  "Install macOS menu entries when FRAME is graphical."
  (when (and (eq system-type 'darwin)
             (display-graphic-p (or frame (selected-frame))))
    (glassmacs--install-macos-menus)))

(defun glassmacs-reopen ()
  "Reopen Glassmacs, restoring its retained frame or creating a new one."
  (interactive)
  (glassmacs-new-window))

(defun glassmacs--install-reopen-event-handler ()
  "Route Cocoa's native new-frame event to `glassmacs-reopen'."
  (when (eq system-type 'darwin)
    (define-key global-map [ns-new-frame] #'glassmacs-reopen)))

(defun glassmacs--load-native-reopen-bridge ()
  "Load the bundled Cocoa application-reopen callback when available.
This runs while `glassmacs' is being required, so a failure here must not
signal: an error would abort the rest of startup (later modules, the
user's `custom-file' and the keyboard profile).  Every failure, including
an Emacs built without module support or a module whose initialization
returns non-zero, is reported with `display-warning' instead, and
Glassmacs continues without Dock-reopen and windowless-menu support.
Return non-nil only when the module was loaded."
  (when (and (eq system-type 'darwin) (display-graphic-p))
    (let ((module
           (expand-file-name
            "macos/libglassmacs-lifecycle.dylib" glassmacs-root)))
      (cond
       ((not (file-readable-p module))
        (display-warning
         'glassmacs
         (format "Cocoa Dock reopen bridge is not built: %s" module)
         :warning)
        nil)
       ((not (fboundp 'module-load))
        (display-warning
         'glassmacs
         "Cocoa Dock reopen bridge requires an Emacs built with module support"
         :warning)
        nil)
       (t
        (condition-case error-data
            (progn (module-load module) t)
          (error
           (display-warning
            'glassmacs
            (format "Cocoa Dock reopen bridge failed to load (%s): %s"
                    module (error-message-string error-data))
            :warning)
           nil)))))))

(defun glassmacs--install-macos-frame-lifecycle ()
  "Install the macOS final-frame and application-reopen behavior."
  (when (eq system-type 'darwin)
    (advice-add 'delete-frame :around #'glassmacs--delete-frame-preserving-app)
    (advice-add 'handle-delete-frame :around
                #'glassmacs--handle-delete-frame-preserving-app)
    (add-hook 'pre-command-hook #'glassmacs--note-windowless-command-start)
    (add-hook 'post-command-hook
              #'glassmacs--reveal-frame-after-windowless-command)
    (with-eval-after-load 'ns-win
      (glassmacs--install-reopen-event-handler)
      (glassmacs--install-native-preferences-command))
    (when (featurep 'ns-win)
      (glassmacs--install-reopen-event-handler)
      (glassmacs--install-native-preferences-command))
    (glassmacs--load-native-reopen-bridge)
    (add-hook 'after-make-frame-functions
              #'glassmacs--install-macos-menus-for-frame)
    (with-eval-after-load 'menu-bar
      (glassmacs--install-macos-menus))))

(recentf-mode 1)
(glassmacs--install-macos-frame-lifecycle)

(provide 'glassmacs-macos)
;;; glassmacs-macos.el ends here
