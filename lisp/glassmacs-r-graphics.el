;;; glassmacs-r-graphics.el --- Conservative native R graphics controls -*- lexical-binding: t; -*-

;; Keep graphics in the R process and its native macOS Quartz device.
;; Glassmacs does not replace ESS's evaluation/filter machinery, install
;; XQuartz, force a device at startup, or switch editor windows automatically.

(require 'cl-lib)
(require 'subr-x)
(require 'glassmacs-sessions)

(defgroup glassmacs-r-graphics nil
  "Native R graphics controls for Glassmacs."
  :group 'glassmacs-r)

(defcustom glassmacs-r-graphics-device 'auto
  "Preferred device for explicit Glassmacs graphics commands.
`auto' uses R's normal device behavior (recommended).
`quartz' explicitly requests the native macOS Quartz device.
`x11' is an explicit fallback, and requires a working X11 display.
No choice changes R's global default device on application startup."
  :type '(choice (const :tag "Let R decide (recommended)" auto)
                 (const :tag "Native macOS Quartz" quartz)
                 (const :tag "Explicit X11/XQuartz fallback" x11))
  :group 'glassmacs-r-graphics)

(defun glassmacs-r-graphics--local-session (&optional session)
  "Resolve a live, local R SESSION without changing the selected target.
Never silently redirect commands from a terminated session or a remote
buffer to a different R process."
  (when (file-remote-p default-directory)
    (user-error "Native graphics controls require a local source buffer"))
  (let* ((target (glassmacs-sessions-resolve session))
         (process (glassmacs-session-process target)))
    (unless (and (memq target (glassmacs-sessions-live))
                 (glassmacs-sessions--process-live-p process)
                 (buffer-live-p (process-buffer process)))
      (user-error "Selected R session is no longer live"))
    (with-current-buffer (process-buffer process)
      (when (file-remote-p default-directory)
        (user-error "Native graphics controls do not support remote R sessions")))
    target))

(defun glassmacs-r-graphics--device-command (device)
  "Return an R expression to open DEVICE with an explicit capability check."
  (pcase device
    ('quartz
     (unless (eq system-type 'darwin)
       (user-error "Quartz graphics are available only on macOS"))
     "if (!capabilities('aqua')) stop('This R build has no native Quartz graphics capability') else grDevices::quartz()")
    ('x11
     "if (!capabilities('X11')) stop('X11 graphics are unavailable; configure XQuartz explicitly') else grDevices::X11()")
    ('auto
     "if (grDevices::dev.cur() == 1L) grDevices::dev.new()")
    (_ (user-error "Unknown R graphics device: %s" device))))

(defun glassmacs-r-graphics--enqueue (expression operation &optional session)
  "Submit R EXPRESSION for OPERATION to a verified local SESSION.
Use the existing queue so source code and the original process identity
remain bound to the selected session at submission time."
  (let ((target (glassmacs-r-graphics--local-session session)))
    (glassmacs-queue-submit
     expression target
     (list :buffer (buffer-name)
           :operation operation
           :graphics-device glassmacs-r-graphics-device))))

(defun glassmacs-r-graphics-open-device (&optional device session)
  "Open an R graphics DEVICE in the selected local SESSION.
DEVICE defaults to `glassmacs-r-graphics-device'.  Interactively, use
a prefix argument to choose a device, including explicit X11 fallback.
Nothing is run until this command is invoked."
  (interactive
   (list (when current-prefix-arg
           (intern (completing-read "R graphics device: "
                                    '("auto" "quartz" "x11") nil t)))))
  (glassmacs-r-graphics--enqueue
   (glassmacs-r-graphics--device-command
    (or device glassmacs-r-graphics-device))
   'graphics-open session))

(defun glassmacs-r-graphics-close-device (&optional session)
  "Close the active R graphics device of the selected local SESSION.
When the session has no open device, report that fact without error.
Closing a device must not interrupt R or change the editor focus."
  (interactive)
  (glassmacs-r-graphics--enqueue
   "if (grDevices::dev.cur() > 1L) grDevices::dev.off() else message('No open R graphics device')"
   'graphics-close session))

(defun glassmacs-r-graphics-list-devices (&optional session)
  "List graphics devices in the selected local R SESSION.
The output appears in the existing ESS console; no new editor frame is
created and no R graphics device is opened."
  (interactive)
  (glassmacs-r-graphics--enqueue
   "print(grDevices::dev.list())"
   'graphics-list session))

(defun glassmacs-r-graphics-select-device (number &optional session)
  "Select the existing graphics device NUMBER in the local R SESSION.
R validates the device number; this does not create a new device."
  (interactive "nR graphics device number: ")
  (unless (and (integerp number) (> number 1))
    (user-error "Graphics device number must be greater than 1"))
  (glassmacs-r-graphics--enqueue
   (format "grDevices::dev.set(%d)" number)
   'graphics-select session))

(defun glassmacs-r-graphics-smoke-plot (&optional session)
  "Send a small base R plot to the selected local SESSION.
R uses its existing device/default device.  This is an opt-in GUI smoke
test; it does not assert that macOS has displayed a graphics window."
  (interactive)
  (glassmacs-r-graphics--enqueue "plot(cars)" 'graphics-plot session))

(provide 'glassmacs-r-graphics)
;;; glassmacs-r-graphics.el ends here
