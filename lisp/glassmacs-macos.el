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
          (make-frame-invisible frame)
          (setq glassmacs--hidden-final-frame frame)
          nil)
      (funcall original frame force))))

(defun glassmacs-new-window ()
  "Create a new graphical Emacs frame."
  (interactive)
  (make-frame-command))

(defun glassmacs-reopen ()
  "Reopen Glassmacs, restoring its retained frame or creating a new one."
  (interactive)
  (unless (and (eq system-type 'darwin)
               (glassmacs--show-hidden-final-frame))
    (glassmacs-new-window)))

(defun glassmacs--install-reopen-event-handler ()
  "Route Cocoa's native new-frame event to `glassmacs-reopen'."
  (when (eq system-type 'darwin)
    (define-key global-map [ns-new-frame] #'glassmacs-reopen)))

(defun glassmacs--load-native-reopen-bridge ()
  "Load the bundled Cocoa application-reopen callback when available."
  (when (and (eq system-type 'darwin) (display-graphic-p))
    (let ((module
           (expand-file-name
            "macos/libglassmacs-lifecycle.dylib" glassmacs-root)))
      (if (file-readable-p module)
          (progn
            (unless (fboundp 'module-load)
              (error "Glassmacs Cocoa reopen bridge requires Emacs modules"))
            (module-load module))
        (display-warning
         'glassmacs
         (format "Cocoa Dock reopen bridge is not built: %s" module)
         :warning)))))

(defun glassmacs--install-macos-frame-lifecycle ()
  "Install the macOS final-frame and application-reopen behavior."
  (when (eq system-type 'darwin)
    (advice-add 'delete-frame :around #'glassmacs--delete-frame-preserving-app)
    (with-eval-after-load 'ns-win
      (glassmacs--install-reopen-event-handler))
    (when (featurep 'ns-win)
      (glassmacs--install-reopen-event-handler))
    (glassmacs--load-native-reopen-bridge)
    (with-eval-after-load 'menu-bar
      (define-key menu-bar-file-menu [glassmacs-new-window]
        '(menu-item "New Window" glassmacs-new-window)))))

(glassmacs--install-macos-frame-lifecycle)

(provide 'glassmacs-macos)
;;; glassmacs-macos.el ends here
