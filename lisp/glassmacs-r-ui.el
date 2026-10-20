;;; glassmacs-r-ui.el --- R console history and contextual actions -*- lexical-binding: t; -*-

(require 'comint)
(require 'glassmacs-sessions)

(defgroup glassmacs-r-ui nil
  "R console and contextual user interface."
  :group 'glassmacs-r)

(defun glassmacs-r-ui--configure-console ()
  "Use the comint history owned by this ESS R process buffer."
  (setq-local comint-input-ring-size 500)
  (setq-local comint-input-ignoredups t)
  (local-set-key [up] #'glassmacs-r-ui-previous-input-or-line)
  (local-set-key [down] #'glassmacs-r-ui-next-input-or-line)
  (local-set-key (kbd "RET") #'comint-send-input))

(defun glassmacs-r-ui--input-start ()
  "Return the beginning of the current comint input, or nil."
  (when (and (boundp 'comint-prompt-regexp)
             (stringp comint-prompt-regexp))
    (save-excursion
      (goto-char (point-max))
      (when (re-search-backward comint-prompt-regexp nil t)
        (match-end 0)))))

(defun glassmacs-r-ui-previous-input-or-line ()
  "Recall earlier R input at the first input line; otherwise move up."
  (interactive)
  (let ((start (glassmacs-r-ui--input-start)))
    (if (and start
             (>= (point) start)
             (= (line-number-at-pos) (line-number-at-pos start)))
        (comint-previous-input 1)
      (line-move -1))))

(defun glassmacs-r-ui-next-input-or-line ()
  "Recall later R input at the last input line; otherwise move down."
  (interactive)
  (let ((start (glassmacs-r-ui--input-start)))
    (if (and start
             (>= (point) start)
             (= (line-number-at-pos) (line-number-at-pos (point-max))))
        (comint-next-input 1)
      (line-move 1))))

(defun glassmacs-r-ui--menu-has-session-p ()
  "Return whether a session is already known without refreshing anything."
  (or (and glassmacs-r-target-session
           (let ((session (glassmacs-sessions-find glassmacs-r-target-session)))
             (and session (glassmacs-sessions--process-live-p
                           (glassmacs-session-process session)))))
      (cl-some (lambda (session)
                 (and (eq (glassmacs-session-state session) 'ready)
                      (glassmacs-sessions--process-live-p
                       (glassmacs-session-process session))))
               glassmacs-sessions--list)))

(defvar glassmacs-r-ui-context-menu
  (let ((menu (make-sparse-keymap "Glassmacs R")))
    (define-key menu [select-target]
      '(menu-item "Choose R Session…" glassmacs-r-select-session
                  :enable (or glassmacs-r-target-session
                              (glassmacs-r-ui--menu-has-session-p))))
    (define-key menu [clear-target]
      '(menu-item "Clear R Session Target" glassmacs-r-clear-session-target
                  :enable glassmacs-r-target-session))
    (define-key menu [inspect-terminal]
      '(menu-item "Show Associated R Console" glassmacs-r-inspect-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [run-selection]
      '(menu-item "Run Selection" glassmacs-r-submit-region
                  :enable (and mark-active (glassmacs-r-ui--menu-has-session-p))))
    (define-key menu [run-selection-once]
      '(menu-item "Run Selection in Another Session…" glassmacs-r-submit-region-to-session
                  :enable (and mark-active (glassmacs-r-ui--menu-has-session-p))))
    (define-key menu [queue]
      '(menu-item "Inspect R Queue" glassmacs-queue-show
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [directories]
      '(menu-item "Show File and Working Directories" glassmacs-r-inspect-directories
                  :enable t))
    (define-key menu [r-directory]
      '(menu-item "Ask R for getwd()" glassmacs-r-show-r-working-directory
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    menu)
  "Context menu shared by R source buffers and ESS R consoles.")

(defun glassmacs-r-context-menu (event)
  "Show the R context menu at mouse EVENT.
Menu enablement only inspects Emacs buffer and process state."
  (interactive "e")
  (mouse-set-point event)
  (popup-menu glassmacs-r-ui-context-menu))

(defun glassmacs-r-ui--bind-context-menu ()
  "Bind the Glassmacs R context menu in the current R mode."
  (local-set-key [mouse-3] #'glassmacs-r-context-menu))

(add-hook 'inferior-ess-r-mode-hook #'glassmacs-r-ui--configure-console)
(add-hook 'ess-r-mode-hook #'glassmacs-r-ui--bind-context-menu)
(add-hook 'R-mode-hook #'glassmacs-r-ui--bind-context-menu)

(with-eval-after-load 'ess-r-mode
  (when (boundp 'ess-r-mode-map)
    (define-key ess-r-mode-map [mouse-3] #'glassmacs-r-context-menu))
  (when (boundp 'R-mode-map)
    (define-key R-mode-map [mouse-3] #'glassmacs-r-context-menu)))

(with-eval-after-load 'ess-inf
  (when (boundp 'inferior-ess-r-mode-map)
    (define-key inferior-ess-r-mode-map [mouse-3] #'glassmacs-r-context-menu)
    (define-key inferior-ess-r-mode-map [up] #'glassmacs-r-ui-previous-input-or-line)
    (define-key inferior-ess-r-mode-map [down] #'glassmacs-r-ui-next-input-or-line)
    (define-key inferior-ess-r-mode-map (kbd "RET") #'comint-send-input)))

(provide 'glassmacs-r-ui)
;;; glassmacs-r-ui.el ends here
