;;; glassmacs-macos.el --- macOS application integration -*- lexical-binding: t; -*-

(require 'cl-lib)

(defvar glassmacs--hidden-final-frame nil
  "The final macOS graphical frame hidden to keep Glassmacs running.")

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

(defun glassmacs--restore-hidden-frame (&rest _)
  "Show and focus the retained frame when Glassmacs receives focus."
  (when (and (eq system-type 'darwin) glassmacs--hidden-final-frame)
    (let ((frame glassmacs--hidden-final-frame))
      (cond
       ((not (frame-live-p frame))
        (setq glassmacs--hidden-final-frame nil))
       ((eq (frame-visible-p frame) t)
        (setq glassmacs--hidden-final-frame nil))
       (t
        (setq glassmacs--hidden-final-frame nil)
        (make-frame-visible frame)
        (select-frame-set-input-focus frame))))))

(defun glassmacs-new-window ()
  "Create a new graphical Emacs frame."
  (interactive)
  (make-frame-command))

(defun glassmacs--install-macos-frame-lifecycle ()
  "Install the macOS final-frame and application-reopen behavior."
  (when (eq system-type 'darwin)
    (advice-add 'delete-frame :around #'glassmacs--delete-frame-preserving-app)
    (add-function :after after-focus-change-function
                  #'glassmacs--restore-hidden-frame)
    (with-eval-after-load 'menu-bar
      (define-key menu-bar-file-menu [glassmacs-new-window]
        '(menu-item "New Window" glassmacs-new-window)))))

(glassmacs--install-macos-frame-lifecycle)

(provide 'glassmacs-macos)
;;; glassmacs-macos.el ends here
