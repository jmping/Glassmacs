;;; glassmacs-r-ui.el --- R console history and contextual actions -*- lexical-binding: t; -*-

(require 'comint)
(require 'mouse)
(require 'glassmacs-sessions)

(defgroup glassmacs-r-ui nil
  "R console and contextual user interface."
  :group 'glassmacs-r)

(defgroup glassmacs-r-controls nil
  "Visible controls for R source and console buffers."
  :group 'glassmacs-r-ui)

(defcustom glassmacs-r-show-toolbar t
  "Whether R buffers show contextual toolbar actions."
  :type 'boolean
  :group 'glassmacs-r-controls)

(defvar glassmacs-r-ui-source-menu
  (let ((menu (make-sparse-keymap "R")))
    (define-key menu [help]
      '(menu-item "R Help…" glassmacs-r-ui-help))
    (define-key menu [console]
      '(menu-item "Show R Console" glassmacs-r-inspect-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [interrupt]
      '(menu-item "Interrupt R" glassmacs-r-interrupt
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [session]
      '(menu-item "Choose R Session…" glassmacs-r-select-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [start]
      '(menu-item "Start R" glassmacs-r-start-session))
    (define-key menu [separator] menu-bar-separator)
    (define-key menu [buffer]
      '(menu-item "Run Buffer" glassmacs-r-send-buffer))
    (define-key menu [function]
      '(menu-item "Run Function" glassmacs-r-send-function))
    (define-key menu [selection]
      '(menu-item "Run Selection" glassmacs-r-send-region
                  :enable (use-region-p)))
    (define-key menu [line]
      '(menu-item "Run Line" glassmacs-r-send-line))
    menu)
  "Source-buffer R menu using existing ESS/Glassmacs commands.")

(defvar glassmacs-r-ui-console-menu
  (let ((menu (make-sparse-keymap "R Console")))
    (define-key menu [sessions]
      '(menu-item "Choose R Session…" glassmacs-r-select-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [history]
      '(menu-item "Previous Command" comint-previous-input))
    (define-key menu [interrupt]
      '(menu-item "Interrupt R" glassmacs-r-interrupt
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    menu)
  "Console-specific R actions.")

(defun glassmacs-r-ui-help ()
  "Prompt for R documentation using ESS, if available."
  (interactive)
  (if (fboundp 'ess-display-help-on-object)
      (call-interactively #'ess-display-help-on-object)
    (user-error "R help requires ESS")))

(defun glassmacs-r-ui--install-controls ()
  "Expose R menus and contextual top toolbar in this buffer."
  (local-set-key [menu-bar glassmacs-r]
                 (if (glassmacs-r-ui--source-buffer-p)
                     glassmacs-r-ui-source-menu
                   glassmacs-r-ui-console-menu))
  (when glassmacs-r-show-toolbar
    (glassmacs-r-ui--enable-toolbar)))

(defun glassmacs-r-ui--enable-toolbar ()
  "Install buffer-local toolbar commands, reusing Emacs toolbar imagery."
  (require 'tool-bar)
  (let ((map (make-sparse-keymap)))
    (dolist (entry (if (glassmacs-r-ui--source-buffer-p)
                       '((glassmacs-line "Run Line" glassmacs-r-send-line)
                         (glassmacs-selection "Run Selection" glassmacs-r-send-region)
                         (glassmacs-function "Run Function" glassmacs-r-send-function)
                         (glassmacs-buffer "Run Buffer" glassmacs-r-send-buffer)
                         (glassmacs-console "R Console" glassmacs-r-inspect-session)
                         (glassmacs-help "R Help" glassmacs-r-ui-help))
                     '((glassmacs-interrupt "Interrupt" glassmacs-r-interrupt)
                       (glassmacs-history "History" comint-previous-input)
                       (glassmacs-session "Session" glassmacs-r-select-session))))
      (let ((key (nth 0 entry))
            (label (nth 1 entry))
            (command (nth 2 entry)))
        (define-key map (vector key)
          `(menu-item ,label ,command
                      :image (find-image '((:type xpm :file "new.xpm")))
                      :help ,label))))
    (setq-local tool-bar-map map)
    (tool-bar-mode 1)))

(defun glassmacs-r-ui--configure-console ()
  "Use the comint history owned by this ESS R process buffer."
  (setq-local comint-input-ring-size 500)
  (setq-local comint-input-ignoredups t)
  (local-set-key [up] #'glassmacs-r-ui-previous-input-or-line)
  (local-set-key [down] #'glassmacs-r-ui-next-input-or-line)
  (local-set-key (kbd "RET") #'comint-send-input)
  (glassmacs-r-ui--enable-context-menu)
  (glassmacs-r-ui--install-controls))

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
  "Return whether an R process is live without refreshing the registry."
  (or (and glassmacs-r-target-session
           (let ((session (glassmacs-sessions-find glassmacs-r-target-session)))
             (and session (glassmacs-sessions--process-live-p
                           (glassmacs-session-process session)))))
      (cl-some (lambda (session)
                 (and (eq (glassmacs-session-state session) 'ready)
                      (glassmacs-sessions--process-live-p
                       (glassmacs-session-process session))))
               glassmacs-sessions--list)
      (and (boundp 'ess-process-name-list)
           (cl-some
            (lambda (entry)
              (let* ((name (if (consp entry) (car entry) entry))
                     (process (and (stringp name) (get-process name))))
                (and (glassmacs-sessions--process-live-p process)
                     (glassmacs-sessions--r-process-p process))))
            ess-process-name-list))))

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
    (define-key menu [stop-output]
      '(menu-item "Stop Displaying R Output"
                  glassmacs-r-stop-displaying-output
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [interrupt]
      '(menu-item "Interrupt R Computation" glassmacs-r-interrupt
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [terminate]
      '(menu-item "Terminate R Session" glassmacs-r-terminate-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [directories]
      '(menu-item "Show File and Working Directories" glassmacs-r-inspect-directories
                  :enable t))
    (define-key menu [r-directory]
      '(menu-item "Ask R for getwd()" glassmacs-r-show-r-working-directory
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    menu)
  "Context menu shared by R source buffers and ESS R consoles.")

(defun glassmacs-r-ui--populate-context-menu (menu _click)
  "Add Glassmacs R actions to MENU in an R source or console buffer."
  (when (derived-mode-p 'ess-r-mode 'R-mode 'inferior-ess-r-mode)
    (define-key-after menu [glassmacs-r-separator] menu-bar-separator)
    (map-keymap
     (lambda (key binding)
       (when (consp binding)
         (define-key-after
           menu (vector (intern (format "glassmacs-%s" key)))
           (copy-sequence binding))))
     glassmacs-r-ui-context-menu))
  menu)

(defun glassmacs-r-ui--enable-context-menu ()
  "Enable Emacs' native context menu and add Glassmacs R actions locally."
  (context-menu-mode 1)
  (add-hook 'context-menu-functions
            #'glassmacs-r-ui--populate-context-menu 20 t))

(defun glassmacs-r-ui--source-buffer-p ()
  "Return non-nil for an ESS R source buffer."
  (derived-mode-p 'ess-r-mode 'R-mode))

(defun glassmacs-r-ui--submit-region (start end operation)
  "Queue source region START..END for the buffer's explicit target."
  (glassmacs-queue-submit
   (buffer-substring-no-properties start end) nil
   (list :buffer (buffer-name) :start start :end end :operation operation)))

(defun glassmacs-r-ui--around-ess-eval-region (original start end &rest arguments)
  "Route ESS region evaluation through the queue when this buffer has a target."
  (if (and (glassmacs-r-ui--source-buffer-p) glassmacs-r-target-session)
      (glassmacs-r-ui--submit-region start end 'ess-region)
    (apply original start end arguments)))

(defun glassmacs-r-ui--around-ess-eval-line (original &rest arguments)
  "Route ESS line evaluation through the queue when this buffer has a target."
  (if (and (glassmacs-r-ui--source-buffer-p) glassmacs-r-target-session)
      (glassmacs-r-ui--submit-region
       (line-beginning-position) (line-end-position) 'ess-line)
    (apply original arguments)))

(defun glassmacs-r-ui--around-ess-eval-function (original &rest arguments)
  "Route ESS function evaluation through the queue when this buffer has a target."
  (if (and (glassmacs-r-ui--source-buffer-p) glassmacs-r-target-session)
      (save-excursion
        (let ((origin (point)))
          (condition-case nil
              (progn
                (beginning-of-defun)
                (let ((start (point)))
                  (end-of-defun)
                  (let ((end (point)))
                    (unless (<= start origin end)
                      (user-error "No R function at point"))
                    (glassmacs-r-ui--submit-region start end 'ess-function))))
            (error (user-error "No R function found at point")))))
    (apply original arguments)))

(defun glassmacs-r-ui--around-ess-eval-buffer (original &rest arguments)
  "Route ESS buffer evaluation through the queue when this buffer has a target."
  (if (and (glassmacs-r-ui--source-buffer-p) glassmacs-r-target-session)
      (glassmacs-r-ui--submit-region (point-min) (point-max) 'ess-buffer)
    (apply original arguments)))

(defun glassmacs-r-ui--install-ess-routing ()
  "Route common ESS R evaluation entry points through the safe queue."
  (dolist (entry '((ess-eval-region . glassmacs-r-ui--around-ess-eval-region)
                   (ess-eval-line . glassmacs-r-ui--around-ess-eval-line)
                   (ess-eval-function . glassmacs-r-ui--around-ess-eval-function)
                   (ess-eval-buffer . glassmacs-r-ui--around-ess-eval-buffer)))
    (when (and (fboundp (car entry))
               (not (advice-member-p (cdr entry) (car entry))))
      (advice-add (car entry) :around (cdr entry)))))

(add-hook 'inferior-ess-r-mode-hook #'glassmacs-r-ui--configure-console)
(add-hook 'ess-r-mode-hook #'glassmacs-r-ui--enable-context-menu)
(add-hook 'R-mode-hook #'glassmacs-r-ui--enable-context-menu)
(add-hook 'ess-r-mode-hook #'glassmacs-r-ui--install-controls)
(add-hook 'R-mode-hook #'glassmacs-r-ui--install-controls)

(with-eval-after-load 'ess-r-mode
  (glassmacs-r-ui--install-ess-routing))

(with-eval-after-load 'ess-inf
  (glassmacs-r-ui--install-ess-routing)
  (when (boundp 'inferior-ess-r-mode-map)
    (define-key inferior-ess-r-mode-map [up] #'glassmacs-r-ui-previous-input-or-line)
    (define-key inferior-ess-r-mode-map [down] #'glassmacs-r-ui-next-input-or-line)
    (define-key inferior-ess-r-mode-map (kbd "RET") #'comint-send-input)))

(provide 'glassmacs-r-ui)
;;; glassmacs-r-ui.el ends here
