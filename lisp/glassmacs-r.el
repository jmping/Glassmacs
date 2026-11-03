;;; glassmacs-r.el --- R and ESS integration -*- lexical-binding: t; -*-

(require 'glassmacs-packages)

(defgroup glassmacs-r nil
  "R and ESS integration for Glassmacs."
  :group 'glassmacs)

(defcustom glassmacs-r-executable nil
  "Optional path or command name for the R executable.
When nil, ESS uses its normal PATH-based discovery."
  :type '(choice (const :tag "Discover on PATH" nil) file)
  :group 'glassmacs-r)

(defvar inferior-ess-r-program)
(defvar ess-local-process-name)

(defun glassmacs-r--configure-ess ()
  "Configure ESS without replacing its keymaps."
  (when glassmacs-r-executable
    (setq inferior-ess-r-program glassmacs-r-executable)))

(defun glassmacs-r-mode ()
  "Use ESS's R mode when available, otherwise fall back to `fundamental-mode'.
Without ESS, offer once per session to install the optional packages."
  (interactive)
  (cond
   ((fboundp 'ess-r-mode) (ess-r-mode))
   ((fboundp 'R-mode) (R-mode))
   (t (fundamental-mode)
      (glassmacs-packages-offer-installation "R editing (ESS)"))))

(when (locate-library "ess-r-mode")
  (autoload 'ess-r-mode "ess-r-mode" "Major mode for editing R source." t)
  (autoload 'R-mode "ess-r-mode" "Major mode for editing R source." t)
  (autoload 'R "ess-site" "Start an interactive R session." t))

(add-to-list 'auto-mode-alist '("\\.[Rr]\\'" . glassmacs-r-mode))

(with-eval-after-load 'ess-r-mode
  (glassmacs-r--configure-ess))

(defun glassmacs-r-start ()
  "Start an interactive R session with ESS."
  (interactive)
  (unless (locate-library "ess-site")
    (user-error "ESS is unavailable; install the ess package first"))
  (call-interactively (intern "R")))

(defun glassmacs-r--with-target (operation)
  "Invoke OPERATION with the source buffer's explicit ESS session target.
When no target is selected, preserve ESS's normal process selection.
An invalid explicit target is an error, never a reason to send to another R."
  (if (and (boundp 'glassmacs-r-target-session)
           glassmacs-r-target-session)
      (progn
        (unless (fboundp 'glassmacs-sessions-resolve)
          (user-error "Glassmacs R session management is unavailable"))
        (let* ((session (glassmacs-sessions-resolve))
               (ess-local-process-name (glassmacs-session-name session)))
          (funcall operation)))
    (funcall operation)))

(defcustom glassmacs-r-queue-editor-submissions t
  "When non-nil, submit editor commands through the per-session FIFO queue.
This keeps editing responsive while R is busy.  The ESS console retains its
native interactive input; commands typed directly there are not queued."
  :type 'boolean
  :group 'glassmacs-r)

(defun glassmacs-r--send-source (source operation fallback)
  "Send SOURCE with OPERATION metadata, using FALLBACK only when opted out."
  (if glassmacs-r-queue-editor-submissions
      (progn
        (unless (fboundp 'glassmacs-queue-submit)
          (user-error "Glassmacs R execution queue is unavailable"))
        (glassmacs-queue-submit
         source nil (list :buffer (buffer-name) :operation operation)))
    (glassmacs-r--with-target fallback)))

(defun glassmacs-r-send-region (start end)
  "Queue the region START..END for the selected R session."
  (interactive "r")
  (glassmacs-r--send-source
   (buffer-substring-no-properties start end) 'region
   (lambda () (ess-eval-region start end))))

(defun glassmacs-r-send-line ()
  "Queue the current line without blocking while R is executing."
  (interactive)
  (let* ((start (line-beginning-position))
         (end (line-end-position))
         (source (buffer-substring-no-properties start end)))
    (prog1 (glassmacs-r--send-source
            source 'line (lambda () (ess-eval-line)))
      (when (derived-mode-p 'ess-r-mode 'R-mode)
        (forward-line 1)))))

(defun glassmacs-r-send-paragraph ()
  "Queue the R paragraph at point without moving the source cursor."
  (interactive)
  (save-excursion
    (let ((start (progn (backward-paragraph)
                        (skip-chars-forward " \t\n")
                        (point)))
          (end (progn (forward-paragraph) (point))))
      (when (<= end start)
        (user-error "No R paragraph at point"))
      (glassmacs-r--send-source
       (buffer-substring-no-properties start end) 'paragraph
       (lambda () (ess-eval-region start end))))))

(defun glassmacs-r--function-source ()
  "Copy the current R function using ESS's defun navigation.
Signal a user error when the current buffer has no navigable definition."
  (save-excursion
    (condition-case nil
        (let ((end (progn (end-of-defun) (point)))
              (start (progn (beginning-of-defun) (point))))
          (when (<= end start)
            (user-error "No R function at point"))
          (buffer-substring-no-properties start end))
      (error (user-error "No R function at point")))))

(defun glassmacs-r-send-function ()
  "Queue the R function at point, preserving ESS's native opt-out path."
  (interactive)
  (if glassmacs-r-queue-editor-submissions
      (glassmacs-r--send-source
       (glassmacs-r--function-source) 'function
       (lambda () (ess-eval-function)))
    (glassmacs-r--with-target (lambda () (ess-eval-function)))))

(defun glassmacs-r-send-buffer ()
  "Queue the current R source buffer for the selected session."
  (interactive)
  (glassmacs-r--send-source
   (buffer-substring-no-properties (point-min) (point-max)) 'buffer
   (lambda () (ess-eval-buffer))))

(provide 'glassmacs-r)
;;; glassmacs-r.el ends here
