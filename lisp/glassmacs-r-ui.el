;;; glassmacs-r-ui.el --- R console history and contextual actions -*- lexical-binding: t; -*-

(require 'comint)
(require 'mouse)
(require 'cl-lib)
(require 'tool-bar)
(require 'glassmacs-sessions)
(require 'glassmacs-r-graphics)

(defgroup glassmacs-r-ui nil
  "R console and contextual user interface."
  :group 'glassmacs-r)

(defgroup glassmacs-r-controls nil
  "Visible controls for R source and console buffers."
  :group 'glassmacs-r-ui)

(defun glassmacs-r-open-preferences ()
  "Open R preferences without displacing the source document."
  (interactive)
  (require 'glassmacs-frames)
  (glassmacs-open-preferences-group 'glassmacs-r))

(defcustom glassmacs-r-show-toolbar t
  "Whether R buffers show contextual toolbar actions."
  :type 'boolean
  :group 'glassmacs-r-controls)

(defvar glassmacs-r-ui-source-menu
  (let ((menu (make-sparse-keymap "R")))
    (define-key menu [preferences]
      '(menu-item "R Preferences…" glassmacs-r-open-preferences))
    (define-key menu [help]
      '(menu-item "R Help…" glassmacs-r-ui-help))
    (define-key menu [console]
      '(menu-item "Show R Console" glassmacs-r-inspect-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [interrupt]
      '(menu-item "Interrupt R" glassmacs-r-interrupt
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [session]
      '(menu-item "Link Console…" glassmacs-r-select-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [start]
      '(menu-item "Start R and Target This Buffer" glassmacs-r-start-and-target-session))
    (define-key menu [start-unbound]
      '(menu-item "New R Console" glassmacs-r-new-console))
    (define-key menu [switch-console]
      '(menu-item "Switch R Console…" glassmacs-r-switch-console
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [hide-console]
      '(menu-item "Close R Console Window (Keep R Running)" glassmacs-r-hide-console
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [terminate-console]
      '(menu-item "Terminate R Session…" glassmacs-r-terminate-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [rename-console]
      '(menu-item "Rename R Console…" glassmacs-r-rename-console
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [show-target]
      '(menu-item "Show Current R Target" glassmacs-r-show-target-session))
    (define-key menu [clear-target]
      '(menu-item "Clear R Target" glassmacs-r-clear-session-target
                  :enable glassmacs-r-target-session))
    (define-key menu [list-sessions]
      '(menu-item "List R Sessions" glassmacs-r-list-sessions))
    (define-key menu [graphics-separator] menu-bar-separator)
    (define-key menu [graphics-list]
      '(menu-item "List Graphics Devices" glassmacs-r-graphics-list-devices
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-select]
      '(menu-item "Select Graphics Device…" glassmacs-r-graphics-select-device
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-close]
      '(menu-item "Close Current Graphics Device" glassmacs-r-graphics-close-device
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-open]
      '(menu-item "Open Graphics Device…" glassmacs-r-graphics-open-device
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-test]
      '(menu-item "Plot Cars (Graphics Test)" glassmacs-r-graphics-smoke-plot
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [shiny-separator] menu-bar-separator)
    (define-key menu [shiny-preview]
      '(menu-item "Open Shiny Preview" glassmacs-shiny-open-preview
                  :enable (bound-and-true-p glassmacs-shiny-url)))
    (define-key menu [shiny-reload]
      '(menu-item "Reload Shiny App" glassmacs-shiny-reload
                  :enable (bound-and-true-p glassmacs-shiny--last-start)))
    (define-key menu [shiny-stop]
      '(menu-item "Stop Shiny App" glassmacs-shiny-stop
                  :enable (bound-and-true-p glassmacs-shiny-process)))
    (define-key menu [shiny-run]
      '(menu-item "Run Shiny App" glassmacs-shiny-start
                  :visible (and (fboundp 'glassmacs-shiny-app-file-p)
                                (glassmacs-shiny-app-file-p))))
    (define-key menu [separator] menu-bar-separator)
    (define-key menu [buffer]
      '(menu-item "Run Buffer" glassmacs-r-send-buffer))
    (define-key menu [paragraph]
      '(menu-item "Run Paragraph" glassmacs-r-send-paragraph))
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
    (define-key menu [preferences]
      '(menu-item "R Preferences…" glassmacs-r-open-preferences))
    (define-key menu [sessions]
      '(menu-item "Choose R Session…" glassmacs-r-select-session
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [list-sessions]
      '(menu-item "List R Sessions" glassmacs-r-list-sessions))
    (define-key menu [start]
      '(menu-item "Start Another R Session" glassmacs-r-start-session))
    (define-key menu [history]
      '(menu-item "Previous Command" comint-previous-input))
    (define-key menu [graphics-separator] menu-bar-separator)
    (define-key menu [graphics-list]
      '(menu-item "List Graphics Devices" glassmacs-r-graphics-list-devices
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-select]
      '(menu-item "Select Graphics Device…" glassmacs-r-graphics-select-device
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-close]
      '(menu-item "Close Current Graphics Device" glassmacs-r-graphics-close-device
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-open]
      '(menu-item "Open Graphics Device…" glassmacs-r-graphics-open-device
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [graphics-test]
      '(menu-item "Plot Cars (Graphics Test)" glassmacs-r-graphics-smoke-plot
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    (define-key menu [interrupt]
      '(menu-item "Interrupt R" glassmacs-r-interrupt
                  :enable (glassmacs-r-ui--menu-has-session-p)))
    menu)
  "Console-specific R actions.")

(glassmacs-menu-install-dynamic-keys glassmacs-r-ui-source-menu)
(glassmacs-menu-install-dynamic-keys glassmacs-r-ui-console-menu)

(defun glassmacs-r-ui--install-help-display ()
  "Compatibility entry point for the unified ESS Help display rule."
  (glassmacs-r-install-help-display))

(defun glassmacs-r-ui-help ()
  "Prompt for R documentation using ESS, without replacing R source.
On graphical macOS, R help is routed to a separate native frame.
Closing that help frame must not close or discard the source document."
  (interactive)
  (if (fboundp 'ess-display-help-on-object)
      (progn
        (glassmacs-r-ui--install-help-display)
        (call-interactively #'ess-display-help-on-object))
    (user-error "R help requires ESS")))

;; Keep the Emacs built-in ICON names as a portable fallback when SVG
;; rendering is unavailable.  Glassmacs ships its own light/dark SVGs.
(defconst glassmacs-r-ui--toolbar-actions
  '((glassmacs-run-line "Run Line" glassmacs-r-send-line "right-arrow")
    (glassmacs-run-selection "Run Selection" glassmacs-r-send-region "copy")
    (glassmacs-run-paragraph "Run Paragraph" glassmacs-r-send-paragraph "next-page")
    (glassmacs-run-function "Run Function" glassmacs-r-send-function "jump-to")
    (glassmacs-run-buffer "Run Buffer" glassmacs-r-send-buffer "next-page")
    (glassmacs-new-console "New R Console" glassmacs-r-new-console "open")
    (glassmacs-link-console "Link Console…" glassmacs-r-select-session "open")
    (glassmacs-show-console "Show Console" glassmacs-r-inspect-session "open")
    (glassmacs-help "R Help" glassmacs-r-ui-help "help"))
  "R source toolbar entries: (KEY LABEL COMMAND ICON).
ICON is the base name of an image shipped with GNU Emacs.")

(defconst glassmacs-r-ui--console-toolbar-actions
  '((glassmacs-interrupt "Interrupt" glassmacs-r-interrupt "cancel")
    (glassmacs-history "History" glassmacs-r-ui-previous-input-or-line "undo")
    (glassmacs-session "Session" glassmacs-r-select-session "open"))
  "R console toolbar entries.")

(defcustom glassmacs-r-ui-toolbar-icon-margin 3
  "Padding in pixels around R toolbar images.
A small margin keeps the action icons legible and separated on Retina
displays without changing their commands or hit targets."
  :type '(integer 0 12)
  :group 'glassmacs)

(defconst glassmacs-r-ui--icon-directory
  (expand-file-name "../assets/r-toolbar/"
                    (file-name-directory (or load-file-name
                                             (locate-library "glassmacs-r-ui"))))
  "Location of the bundled, consistent 24-point R toolbar symbols.")

(defconst glassmacs-r-ui--icon-aliases
  '((right-arrow . "run") (copy . "selection")
    (next-page . "paragraph") (jump-to . "function")
    (open . "console") (help . "help")
    (cancel . "interrupt") (undo . "history"))
  "Fallback mappings from built-in Emacs image names to vector symbols.")

(defun glassmacs-r-ui--toolbar-image (name &optional action)
  "Return a bundled SVG for ACTION, falling back to Emacs image NAME.
If SVG support is missing, retain the existing built-in XPM artwork."
  (when (display-graphic-p)
    (let* ((symbol-name (or (cdr (assq (intern name)
                                     glassmacs-r-ui--icon-aliases))
                            name))
           (base (or action symbol-name))
           (dark (eq (frame-parameter nil 'background-mode) 'dark))
           (svg (expand-file-name
                 (concat base (if dark "-dark" "") ".svg")
                 glassmacs-r-ui--icon-directory))
           (fallback-svg (expand-file-name
                          (concat base ".svg")
                          glassmacs-r-ui--icon-directory))
           (chosen-svg (if (file-readable-p svg) svg fallback-svg))
           (vector-image (and (image-type-available-p 'svg)
                              (file-readable-p chosen-svg)
                              (find-image (list (list :type 'svg :file chosen-svg
                                                      :ascent 'center)))))
           (image (or vector-image
                      (find-image
                       (list (list :type 'xpm
                                   :file (concat name ".xpm")
                                   :ascent 'center))))))
      (when image
        ;; Image specifications begin with the marker symbol `image'; the
        ;; remaining tail is the property list accepted by plist-put.
        (setcdr image
                (plist-put (cdr image) :margin
                           (max 0 (min 12 glassmacs-r-ui-toolbar-icon-margin))))
        image))))

(defun glassmacs-r-ui--toolbar-map ()
  "Build a contextual toolbar using the same R commands as the menus."
  (let ((map (make-sparse-keymap))
        (actions (if (glassmacs-r-ui--source-buffer-p)
                     glassmacs-r-ui--toolbar-actions
                   glassmacs-r-ui--console-toolbar-actions)))
    (dolist (entry actions)
      (pcase-let ((`(,key ,label ,command ,icon) entry))
        ;; Group execution, session navigation and help in the source bar.
        ;; Console controls likewise separate interruption from navigation.
        (when (memq key '(glassmacs-new-console glassmacs-help
                          glassmacs-history))
          (define-key-after map
            (vector (intern (format "glassmacs-divider-%s" key)))
            '(menu-item "--" ignore)))
        (define-key-after map (vector key)
          `(menu-item ,label ,command
                      :image (glassmacs-r-ui--toolbar-image ,icon
                                                         ,(pcase key
                                                            ('glassmacs-run-buffer "buffer")
                                                            ('glassmacs-show-console "console")
                                                            ('glassmacs-new-console "console")
                                                            ('glassmacs-link-console "session")
                                                            ('glassmacs-session "session")
                                                            (_ nil)))
                      :help ,label
                      :enable ,(cond
                                ((eq command 'glassmacs-r-send-region)
                                 '(use-region-p))
                                ((memq command
                                       '(glassmacs-r-interrupt
                                         glassmacs-r-select-session))
                                 '(glassmacs-r-ui--menu-has-session-p))
                                (t t))))))
    map))

(defun glassmacs-r-ui--enable-toolbar ()
  "Install buffer-local R toolbar commands without altering ESS keymaps.
The command map is buffer-local, but `tool-bar-mode' is a global minor
mode: Emacs has no per-buffer tool-bar toggle, so showing the R toolbar
turns the tool bar on for every graphical frame.  Other buffers keep their
own (default) `tool-bar-map'."
  (require 'tool-bar)
  (setq-local tool-bar-map (glassmacs-r-ui--toolbar-map))
  (when (display-graphic-p)
    (tool-bar-mode 1)))

(defvar-local glassmacs-r-ui--local-map nil
  "Keymap private to this buffer that holds its Glassmacs R controls.")

(defun glassmacs-r-ui--local-map ()
  "Return a keymap private to the current buffer, installing it if needed.
`local-set-key' would modify the major mode's keymap, which every buffer
in that mode shares (for example `ess-r-mode-map').  Instead, install a
sparse keymap whose parent is the mode's map: ESS bindings stay
inherited and unchanged, and bindings added here affect only this buffer.
A major-mode change resets the variable, so a fresh map is built then."
  (unless (and (keymapp glassmacs-r-ui--local-map)
               (eq (current-local-map) glassmacs-r-ui--local-map))
    (let ((map (make-sparse-keymap)))
      (set-keymap-parent map (current-local-map))
      (use-local-map map)
      (setq glassmacs-r-ui--local-map map)))
  glassmacs-r-ui--local-map)

(defun glassmacs-r-ui--install-controls ()
  "Expose mode-local R menus and optional toolbar in the current buffer."
  (define-key (glassmacs-r-ui--local-map) [menu-bar glassmacs-r]
    (if (glassmacs-r-ui--source-buffer-p)
        glassmacs-r-ui-source-menu
      glassmacs-r-ui-console-menu))
  (if glassmacs-r-show-toolbar
      (glassmacs-r-ui--enable-toolbar)
    (kill-local-variable 'tool-bar-map)))

(defun glassmacs-r-ui-refresh-controls ()
  "Refresh R controls after adjusting the toolbar preference."
  (interactive)
  (unless (derived-mode-p 'ess-r-mode 'R-mode 'inferior-ess-r-mode)
    (user-error "R controls are only available in R source and console buffers"))
  (glassmacs-r-ui--install-controls))

(defun glassmacs-r-ui--configure-console ()
  "Use the comint history owned by this ESS R process buffer.
RET is deliberately left to the mode: ESS binds it to
`inferior-ess-send-input', which runs `ess-send-input-hook' and resets
ESS's prompt and completion-cache state before calling `comint-send-input'."
  (setq-local comint-input-ring-size 500)
  (setq-local comint-input-ignoredups t)
  (let ((map (glassmacs-r-ui--local-map)))
    (define-key map [up] #'glassmacs-r-ui-previous-input-or-line)
    (define-key map [down] #'glassmacs-r-ui-next-input-or-line))
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
    (define-key menu [move-console]
      '(menu-item "Move R Console to New Window" glassmacs-r-move-console-to-new-frame
                  :enable (derived-mode-p 'inferior-ess-r-mode)))
    (define-key menu [start-console]
      '(menu-item "Start R / Show Console" glassmacs-r-start-or-switch-console))
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

(glassmacs-menu-install-dynamic-keys glassmacs-r-ui-context-menu)

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
  "Enable Emacs' native context menu and add Glassmacs R actions locally.
`context-menu-mode' is a global minor mode, so this enables right-click
menus everywhere; only the R entries are added buffer-locally."
  (context-menu-mode 1)
  (add-hook 'context-menu-functions
            #'glassmacs-r-ui--populate-context-menu 20 t))

(defun glassmacs-r-ui--source-buffer-p ()
  "Return non-nil for an ESS R source buffer."
  (derived-mode-p 'ess-r-mode 'R-mode))

(defun glassmacs-r-ui--submit-region (start end operation)
  "Queue source region START..END for its explicitly linked R console."
  (let ((session (glassmacs-r-resolve-source-target)))
    (glassmacs-queue-submit
   (buffer-substring-no-properties start end) session
   (list :buffer (buffer-name) :start start :end end :operation operation))))

(defun glassmacs-r-ui--around-ess-eval-region (original start end &rest arguments)
  "Route R source region evaluation through explicit console selection."
  (if (glassmacs-r-ui--source-buffer-p)
      (glassmacs-r-ui--submit-region start end 'ess-region)
    (apply original start end arguments)))

(defun glassmacs-r-ui--around-ess-eval-line (original &rest arguments)
  "Route R source line evaluation through explicit console selection."
  (if (glassmacs-r-ui--source-buffer-p)
      (glassmacs-r-ui--submit-region
       (line-beginning-position) (line-end-position) 'ess-line)
    (apply original arguments)))

(defun glassmacs-r-ui--around-ess-eval-function (original &rest arguments)
  "Route R source function evaluation through explicit console selection."
  (if (glassmacs-r-ui--source-buffer-p)
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
  "Route R source buffer evaluation through explicit console selection."
  (if (glassmacs-r-ui--source-buffer-p)
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
    (define-key inferior-ess-r-mode-map [down] #'glassmacs-r-ui-next-input-or-line)))

;; Help buffers can be displayed asynchronously after the ESS request.
;; Install at startup as well as at the explicit R Help entrypoint.
(add-hook 'window-setup-hook #'glassmacs-r-ui--install-help-display)

(provide 'glassmacs-r-ui)
;;; glassmacs-r-ui.el ends here
