;;; glassmacs-r.el --- R and ESS integration -*- lexical-binding: t; -*-

(defgroup glassmacs-r nil
  "R and ESS integration for Glassmacs."
  :group 'glassmacs)

(defcustom glassmacs-r-executable nil
  "Optional path or command name for the R executable.
When nil, ESS uses its normal PATH-based discovery."
  :type '(choice (const :tag "Discover on PATH" nil) file)
  :group 'glassmacs-r)

(defvar inferior-ess-r-program)

(defun glassmacs-r--configure-ess ()
  "Configure ESS without replacing its keymaps."
  (when glassmacs-r-executable
    (setq inferior-ess-r-program glassmacs-r-executable)))

(defun glassmacs-r-mode ()
  "Use ESS's R mode when available, otherwise fall back to text mode."
  (interactive)
  (cond
   ((fboundp 'ess-r-mode) (ess-r-mode))
   ((fboundp 'R-mode) (R-mode))
   (t (fundamental-mode))))

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

(defun glassmacs-r-send-region (start end)
  "Send the region from START to END to the current ESS process."
  (interactive "r")
  (unless (fboundp 'ess-eval-region)
    (user-error "ESS region evaluation is unavailable"))
  (funcall (intern "ess-eval-region") start end))

(defun glassmacs-r-send-line ()
  "Send the current line to the current ESS process."
  (interactive)
  (unless (fboundp 'ess-eval-line)
    (user-error "ESS line evaluation is unavailable"))
  (funcall (intern "ess-eval-line")))

(defun glassmacs-r-send-function ()
  "Send the current R function to the current ESS process."
  (interactive)
  (unless (fboundp 'ess-eval-function)
    (user-error "ESS function evaluation is unavailable"))
  (funcall (intern "ess-eval-function")))

(defun glassmacs-r-send-buffer ()
  "Send the current buffer to the current ESS process."
  (interactive)
  (unless (fboundp 'ess-eval-buffer)
    (user-error "ESS buffer evaluation is unavailable"))
  (funcall (intern "ess-eval-buffer")))

(provide 'glassmacs-r)
;;; glassmacs-r.el ends here
