;;; glassmacs-workspace.el --- Reopen windows and files at startup -*- lexical-binding: t; -*-

;; Mac applications reopen the windows that were open when they quit, and
;; Aquamacs did the same (revive.el with macOS application resume).  This
;; module offers it with GNU Emacs's desktop.el, as an opt-in preference.
;;
;; What is restored: windows (frames) and the files they showed, with
;; their positions.  What is not: remote (TRAMP) files, so startup never
;; opens a network connection; R consoles, shells and other process
;; buffers, so no R session or remote command is started or replayed; and
;; unsaved changes, which are the recovery module's job
;; (glassmacs-recovery.el).  The workspace file lives in the Glassmacs
;; home, never in ~/.emacs.d.  It is read at most once per session, and
;; restored windows reuse the startup window instead of adding to it, so
;; restoring cannot duplicate windows or buffers (Aquamacs issue #81).

(require 'desktop)

(defgroup glassmacs-workspace nil
  "Reopening windows and files from the previous session."
  :group 'glassmacs)

(defun glassmacs-workspace--set (symbol value)
  "Set SYMBOL to VALUE and start or stop saving the workspace."
  (set-default symbol value)
  (when (fboundp 'glassmacs-workspace-apply)
    (glassmacs-workspace-apply)))

(defcustom glassmacs-restore-workspace nil
  "Whether Glassmacs reopens the previous session's windows and files.
When non-nil, the open windows and local files are saved when Glassmacs
quits (and periodically while it runs) and reopened at the next start.
Remote files, R consoles and other processes are never reopened."
  :type 'boolean
  :set #'glassmacs-workspace--set
  :group 'glassmacs-workspace)

(defvar glassmacs-home)

(defconst glassmacs-workspace-file-name "workspace.desktop"
  "Name of the workspace file in the Glassmacs home.")

(defvar glassmacs-workspace--restored nil
  "Non-nil once the workspace has been read in this session.")

(defun glassmacs-workspace--configure ()
  "Point desktop.el at the Glassmacs home and set safe restore options."
  (setq desktop-dirname (file-name-as-directory glassmacs-home)
        desktop-path (list desktop-dirname)
        desktop-base-file-name glassmacs-workspace-file-name
        desktop-base-lock-name (concat glassmacs-workspace-file-name ".lock")
        ;; Save without asking; Glassmacs asks once, through the preference.
        desktop-save t
        ;; A lock left by a crashed session is ignored, a live one is not.
        desktop-load-locked-desktop 'check-pid
        desktop-restore-frames t
        desktop-restore-reuses-frames t)
  ;; The final window may be hidden rather than closed when Glassmacs quits
  ;; (glassmacs-macos.el); never save visibility, so it reopens visible.
  (unless (assq 'visibility frameset-filter-alist)
    (setq frameset-filter-alist
          (cons '(visibility . :never) frameset-filter-alist))))

(defun glassmacs-workspace-apply ()
  "Start or stop saving the workspace according to the preference."
  (if glassmacs-restore-workspace
      (progn
        (glassmacs-workspace--configure)
        (desktop-save-mode 1))
    (when (bound-and-true-p desktop-save-mode)
      (desktop-save-mode -1))))

(defun glassmacs-workspace-restore-at-startup ()
  "Reopen the previous session's windows and files, once per session.
Does nothing unless `glassmacs-restore-workspace' is set, and never in
batch sessions."
  (when (and glassmacs-restore-workspace
             (not noninteractive)
             (not glassmacs-workspace--restored))
    (setq glassmacs-workspace--restored t)
    (glassmacs-workspace-apply)
    (desktop-read desktop-dirname)))

(defun glassmacs-toggle-restore-workspace ()
  "Toggle and persist reopening windows and files at startup."
  (interactive)
  (customize-save-variable 'glassmacs-restore-workspace
                           (not glassmacs-restore-workspace))
  (message "Reopen windows and files at startup: %s"
           (if glassmacs-restore-workspace "on" "off")))

(provide 'glassmacs-workspace)
;;; glassmacs-workspace.el ends here
