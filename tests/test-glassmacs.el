;;; test-glassmacs.el --- Glassmacs ERT tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'comint)
(defvar custom-file)
;; Declared by Cocoa Emacs only; make let-bindings dynamic on other builds.
(defvar ns-input-file)
(add-to-list 'load-path
             (expand-file-name "../lisp"
                               (file-name-directory (or load-file-name buffer-file-name))))
(require 'glassmacs)


(ert-deftest glassmacs-new-buffer-in-mode-creates-distinct-mode-buffer ()
  (let (buffer)
    (unwind-protect
        (progn
          (setq buffer (glassmacs-new-buffer-in-mode 'emacs-lisp-mode))
          (should (buffer-live-p buffer))
          (with-current-buffer buffer
            (should (eq major-mode 'emacs-lisp-mode))
            (should-not buffer-file-name)))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest glassmacs-new-buffer-in-mode-rejects-unknown-mode ()
  (should-error (glassmacs-new-buffer-in-mode 'glassmacs-not-real-mode)
                :type 'user-error))

(ert-deftest glassmacs-mode-chooser-excludes-missing-optional-modes ()
  (cl-letf (((symbol-function 'locate-library)
             (lambda (name &rest _)
               (unless (equal name "markdown-mode") "available"))))
    (unless (fboundp 'markdown-mode)
      (should-not (assoc "Markdown" (glassmacs--available-major-modes))))))

(ert-deftest glassmacs-r-source-and-console-menus-have-distinct-actions ()
  (should (eq (lookup-key glassmacs-r-ui-source-menu [line])
              'glassmacs-r-send-line))
  (should (eq (lookup-key glassmacs-r-ui-source-menu [buffer])
              'glassmacs-r-send-buffer))
  (should (eq (lookup-key glassmacs-r-ui-console-menu [interrupt])
              'glassmacs-r-interrupt)))

(ert-deftest glassmacs-r-toolbar-has-relevant-command-bindings ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'glassmacs-r-ui--source-buffer-p)
               (lambda () t)))
      (glassmacs-r-ui--enable-toolbar))
    (should (eq (lookup-key tool-bar-map [glassmacs-line])
                'glassmacs-r-send-line))
    (should (eq (lookup-key tool-bar-map [glassmacs-buffer])
                'glassmacs-r-send-buffer))
    (should (local-variable-p 'tool-bar-map))))

(ert-deftest glassmacs-r-mode-map-installed-for-r-buffer ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'glassmacs-r-ui--source-buffer-p)
               (lambda () t)))
      (glassmacs-r-ui--install-controls))
    (should (eq (lookup-key (current-local-map) [menu-bar glassmacs-r])
                glassmacs-r-ui-source-menu))))

(ert-deftest glassmacs-r-mode-map-installed-for-console-buffer ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'glassmacs-r-ui--source-buffer-p)
               (lambda () nil)))
      (glassmacs-r-ui--install-controls))
    (should (eq (lookup-key (current-local-map) [menu-bar glassmacs-r])
                glassmacs-r-ui-console-menu))))

(ert-deftest glassmacs-new-mode-preserves-ordinary-new-document-policy ()
  (let ((glassmacs-document-opening-policy 'new-frame)
        displayed buffer)
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t))
              ((symbol-function 'glassmacs--show-document-buffer)
               (lambda (chosen policy)
                 (setq displayed (list chosen policy)))))
      (unwind-protect
          (progn
            (setq buffer (call-interactively
                          (lambda ()
                            (interactive)
                            (glassmacs-new-buffer-in-mode 'emacs-lisp-mode))))
            ;; Delegating through an interactive lambda calls the inner
            ;; function noninteractively; it must not create a new frame.
            (should-not displayed))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest glassmacs-configuration-loads ()
  (dolist (feature '(glassmacs glassmacs-core glassmacs-keys glassmacs-r
                     glassmacs-sessions glassmacs-r-ui glassmacs-remote
                     glassmacs-documents glassmacs-frames glassmacs-macos
                     glassmacs-diagnostics glassmacs-shiny
                     glassmacs-appearance))
    (should (featurep feature))))

(defmacro glassmacs-test-with-close-event (frames visible &rest body)
  "Run BODY with mocked FRAMES, of which VISIBLE are visible."
  (declare (indent 2))
  `(let ((system-type 'darwin)
         (glassmacs--hidden-final-frame nil)
         hidden)
     (cl-letf (((symbol-function 'frame-list) (lambda () ,frames))
               ((symbol-function 'frame-live-p)
                (lambda (candidate) (memq candidate ,frames)))
               ((symbol-function 'frame-visible-p)
                (lambda (candidate) (memq candidate ,visible)))
               ((symbol-function 'frame-parent) (lambda (_candidate) nil))
               ((symbol-function 'frame-parameter) (lambda (&rest _) nil))
               ((symbol-function 'display-graphic-p) (lambda (&optional _) t))
               ((symbol-function 'event-start) (lambda (event) event))
               ((symbol-function 'posn-window) (lambda (event) event))
               ((symbol-function 'make-frame-invisible)
                (lambda (candidate &rest _) (setq hidden candidate))))
       ,@body)))

(ert-deftest glassmacs-macos-cocoa-close-of-final-frame-does-not-quit ()
  (glassmacs-test-with-close-event '(a) '(a)
    (let (original-called)
      (should-not (glassmacs--handle-delete-frame-preserving-app
                   (lambda (_event) (setq original-called t)) 'a))
      (should-not original-called)
      (should (eq hidden 'a))
      (should (eq glassmacs--hidden-final-frame 'a)))))

(ert-deftest glassmacs-macos-cocoa-close-of-nonfinal-frame-uses-original ()
  (glassmacs-test-with-close-event '(a b) '(a b)
    (let (original-event)
      (glassmacs--handle-delete-frame-preserving-app
       (lambda (event) (setq original-event event)) 'a)
      (should (eq original-event 'a))
      (should-not hidden))))

(ert-deftest glassmacs-macos-cocoa-close-with-only-hidden-others-hides ()
  (glassmacs-test-with-close-event '(a b) '(a)
    (glassmacs--handle-delete-frame-preserving-app #'ignore 'a)
    (should (eq hidden 'a))))

;; The installer is darwin-gated, so run it with a simulated Cocoa system
;; and restore global advice and hooks afterwards (Linux batch Emacs lacks them).
(defmacro glassmacs-test-with-installed-lifecycle (&rest body)
  "Run BODY after installing the lifecycle on a simulated darwin system."
  (declare (indent 0))
  `(let ((pre-command-hook pre-command-hook)
         (post-command-hook post-command-hook)
         (after-make-frame-functions after-make-frame-functions)
         (had-handle (advice-member-p
                      #'glassmacs--handle-delete-frame-preserving-app
                      'handle-delete-frame))
         (had-delete (advice-member-p
                      #'glassmacs--delete-frame-preserving-app 'delete-frame)))
     (unwind-protect
         (cl-letf (((symbol-function 'glassmacs--load-native-reopen-bridge)
                    #'ignore)
                   ((symbol-function 'glassmacs--install-reopen-event-handler)
                    #'ignore)
                   ((symbol-function
                     'glassmacs--install-native-preferences-command)
                    #'ignore)
                   ((symbol-function 'glassmacs--install-macos-menus)
                    #'ignore))
           (let ((system-type 'darwin))
             (glassmacs--install-macos-frame-lifecycle))
           ,@body)
       (unless had-handle
         (advice-remove 'handle-delete-frame
                        #'glassmacs--handle-delete-frame-preserving-app))
       (unless had-delete
         (advice-remove 'delete-frame
                        #'glassmacs--delete-frame-preserving-app)))))

(ert-deftest glassmacs-macos-lifecycle-advises-cocoa-close-handler ()
  (glassmacs-test-with-installed-lifecycle
    (should (advice-member-p #'glassmacs--handle-delete-frame-preserving-app
                             'handle-delete-frame))
    (should (advice-member-p #'glassmacs--delete-frame-preserving-app
                             'delete-frame))))

(ert-deftest glassmacs-macos-explicit-quit-is-not-intercepted ()
  (should-not (advice-member-p #'glassmacs--handle-delete-frame-preserving-app
                               'save-buffers-kill-emacs))
  (should-not (advice-member-p #'glassmacs--delete-frame-preserving-app
                               'save-buffers-kill-emacs)))

(ert-deftest glassmacs-macos-reopen-after-cocoa-close-shows-hidden-frame ()
  (glassmacs-test-with-close-event '(a) '(a)
    (glassmacs--handle-delete-frame-preserving-app #'ignore 'a)
    (let (shown)
      (cl-letf (((symbol-function 'make-frame-visible)
                 (lambda (f) (setq shown f)))
                ((symbol-function 'select-frame-set-input-focus) #'ignore))
        (glassmacs-reopen)
        (should (eq shown 'a))
        (should-not glassmacs--hidden-final-frame)))))

(ert-deftest glassmacs-macos-final-frame-close-keeps-process-frame ()
  (let ((system-type 'darwin)
        (frame 'glassmacs-test-frame)
        (glassmacs--hidden-final-frame nil)
        hidden
        deleted)
    (cl-letf (((symbol-function 'frame-list) (lambda () (list frame)))
              ((symbol-function 'frame-live-p) (lambda (candidate) (eq candidate frame)))
              ((symbol-function 'display-graphic-p) (lambda (&optional _candidate) t))
              ((symbol-function 'selected-frame) (lambda () frame))
              ((symbol-function 'make-frame-invisible)
               ;; Real Emacs signals an error for the sole frame unless FORCE.
               (lambda (candidate &optional force)
                 (unless force
                   (error "Attempt to make invisible the sole visible or iconified frame"))
                 (setq hidden candidate))))
      (should-not
       (glassmacs--delete-frame-preserving-app
        (lambda (&rest _arguments) (setq deleted t))
        frame))
      (should (eq hidden frame))
      (should (eq glassmacs--hidden-final-frame frame))
      (should-not deleted))))

(ert-deftest glassmacs-macos-closing-nonfinal-frame-deletes-only-that-frame ()
  (let ((system-type 'darwin)
        (frame 'glassmacs-test-frame)
        (other-frame 'glassmacs-test-other-frame)
        deleted)
    (cl-letf (((symbol-function 'frame-list)
               (lambda () (list frame other-frame)))
              ((symbol-function 'frame-live-p)
               (lambda (candidate) (memq candidate (list frame other-frame))))
              ((symbol-function 'display-graphic-p)
               (lambda (&optional _candidate) t)))
      (should
       (eq (glassmacs--delete-frame-preserving-app
            (lambda (candidate force)
              (setq deleted (list candidate force))
              'deleted)
            frame)
           'deleted))
      (should (equal deleted (list frame nil))))))

(ert-deftest glassmacs-macos-reopen-restores-hidden-frame-without-duplicating-it ()
  (let ((system-type 'darwin)
        (frame 'glassmacs-test-frame)
        (glassmacs--hidden-final-frame 'glassmacs-test-frame)
        visible
        focused
        created)
    (cl-letf (((symbol-function 'frame-live-p)
               (lambda (candidate) (eq candidate frame)))
              ((symbol-function 'frame-visible-p) (lambda (_frame) visible))
              ((symbol-function 'make-frame-visible)
               (lambda (candidate) (setq visible candidate)))
              ((symbol-function 'select-frame-set-input-focus)
               (lambda (candidate) (setq focused candidate)))
              ((symbol-function 'make-frame-command)
               (lambda () (setq created t))))
      (glassmacs-reopen)
      (should (eq visible frame))
      (should (eq focused frame))
      (should-not created)
      (should-not glassmacs--hidden-final-frame))))

(ert-deftest glassmacs-macos-reopen-creates-frame-when-none-was-retained ()
  (let ((system-type 'darwin)
        (glassmacs--hidden-final-frame nil)
        created)
    (cl-letf (((symbol-function 'make-frame-command)
               (lambda () (setq created t))))
      (glassmacs-reopen)
      (should created))))

(ert-deftest glassmacs-macos-reopen-event-uses-reopen-command ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (glassmacs--install-reopen-event-handler)
    (should (eq (lookup-key global-map [ns-new-frame])
                #'glassmacs-reopen))))

(ert-deftest glassmacs-macos-native-reopen-bridge-loads-from-bundle ()
  (let ((system-type 'darwin)
        (glassmacs-root "/Applications/Glassmacs.app/Contents/Resources/Glassmacs")
        (loaded nil))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t))
              ((symbol-function 'file-readable-p)
               (lambda (path)
                 (string-suffix-p
                  "macos/libglassmacs-lifecycle.dylib" path)))
              ((symbol-function 'module-load)
               (lambda (path) (setq loaded path))))
      (glassmacs--load-native-reopen-bridge))
    (should (equal loaded
                   (expand-file-name
                    "macos/libglassmacs-lifecycle.dylib"
                    glassmacs-root)))))

(ert-deftest glassmacs-macos-new-window-creates-a-frame ()
  (let (created)
    (cl-letf (((symbol-function 'make-frame-command)
               (lambda () (setq created t))))
      (glassmacs-new-window)
      (should created))))

(ert-deftest glassmacs-macos-new-window-does-not-change-quit-binding ()
  (let ((global-map (copy-keymap global-map)))
    (define-key global-map [?\s-q] #'save-buffers-kill-emacs)
    (define-key global-map [ns-power-off] #'save-buffers-kill-emacs)
    (glassmacs--install-reopen-event-handler)
    (should (eq (lookup-key global-map [?\s-q])
                #'save-buffers-kill-emacs))
    (should (eq (lookup-key global-map [ns-power-off])
                #'save-buffers-kill-emacs))))

(ert-deftest glassmacs-native-jit-is-disabled-by-default-before-packages ()
  (should (boundp 'native-comp-jit-compilation))
  (should-not native-comp-jit-compilation)
  (should (boundp 'native-comp-enable-subr-trampolines))
  (should-not native-comp-enable-subr-trampolines)
  (should package--initialized)
  (let* ((native-comp-eln-load-path '("/user/cache/eln-cache/"))
         (bundle (make-temp-file "glassmacs-native-bundle-" t))
         (contents (expand-file-name "Contents/" bundle))
         (data-directory (expand-file-name "Resources/etc/" contents))
         (native-lisp (expand-file-name "Frameworks/native-lisp/" contents)))
    (unwind-protect
        (progn
          (make-directory data-directory t)
          (make-directory native-lisp t)
          (write-region "" nil (expand-file-name "Info.plist" contents))
          (let ((system-type 'darwin))
            (glassmacs--configure-native-compilation)
            (should (equal native-comp-eln-load-path
                           (list (file-name-as-directory
                                  (file-truename native-lisp))))))
          (let ((system-type 'gnu/linux))
            (glassmacs--configure-native-compilation)
            (should-not native-comp-eln-load-path)))
      (delete-directory bundle t))))

(ert-deftest glassmacs-native-compilation-does-not-use-user-cache ()
  (should-not native-comp-enable-subr-trampolines)
  (should-not
   (member (expand-file-name "eln-cache/" user-emacs-directory)
           native-comp-eln-load-path)))

(ert-deftest glassmacs-emacs-31-when-let-star-is-supported ()
  (should (equal (when-let* ((first 1)
                             (second (1+ first)))
                   (list first second))
                 '(1 2))))

(ert-deftest glassmacs-ordinary-elisp-and-bytecode-remain-loadable ()
  (let* ((directory (make-temp-file "glassmacs-lisp-package-" t))
         (source (expand-file-name "glassmacs-test-package.el" directory))
         (load-path (cons directory load-path)))
    (unwind-protect
        (progn
          (with-temp-file source
            (insert "(defun glassmacs-test-package-value () 'loaded)\n"
                    "(provide 'glassmacs-test-package)\n"))
          (should (byte-compile-file source))
          (require 'glassmacs-test-package)
          (should (eq (glassmacs-test-package-value) 'loaded))
          (unload-feature 'glassmacs-test-package t)
          (delete-file source)
          (require 'glassmacs-test-package)
          (should (eq (glassmacs-test-package-value) 'loaded)))
      (when (featurep 'glassmacs-test-package)
        (unload-feature 'glassmacs-test-package t))
      (delete-directory directory t))))

(ert-deftest glassmacs-document-classification-excludes-special-buffers ()
  (let ((document (generate-new-buffer "glassmacs-document"))
        (untitled (generate-new-buffer "Untitled"))
        (internal (generate-new-buffer "*Completions*"))
        (help (generate-new-buffer "glassmacs-help"))
        (r-process (generate-new-buffer "Glassmacs R session")))
    (unwind-protect
        (progn
          (with-current-buffer document
            (setq buffer-file-name "/tmp/analysis.R")
            (fundamental-mode))
          (with-current-buffer untitled
            (fundamental-mode))
          (with-current-buffer internal
            (fundamental-mode))
          (with-current-buffer help
            (help-mode))
          (with-current-buffer r-process
            (comint-mode))
          (should (glassmacs--ordinary-document-buffer-p document))
          (should (glassmacs--ordinary-document-buffer-p untitled))
          (should-not (glassmacs--ordinary-document-buffer-p internal))
          (should-not (glassmacs--ordinary-document-buffer-p help))
          (should-not (glassmacs--ordinary-document-buffer-p r-process)))
      (mapc (lambda (buffer)
              (when (buffer-live-p buffer) (kill-buffer buffer)))
            (list document untitled internal help r-process)))))

(ert-deftest glassmacs-document-policy-requires-graphical-ordinary-buffer ()
  (let ((document (generate-new-buffer "glassmacs-policy-document"))
        (special (generate-new-buffer "*Glassmacs Special*"))
        (policies '(new-frame new-tab reuse-current)))
    (unwind-protect
        (progn
          (with-current-buffer document
            (setq buffer-file-name "/tmp/analysis.R")
            (fundamental-mode))
          (with-current-buffer special
            (special-mode))
          (dolist (policy policies)
            (let ((glassmacs-document-opening-policy policy))
              (cl-letf (((symbol-function 'display-graphic-p)
                         (lambda (&optional _frame) t)))
                (should (eq (glassmacs--document-opening-action document)
                            policy))
                (should-not (glassmacs--document-opening-action special)))
              (cl-letf (((symbol-function 'display-graphic-p)
                         (lambda (&optional _frame) nil)))
                (should-not (glassmacs--document-opening-action document)))))
          (cl-letf (((symbol-function 'display-graphic-p)
                     (lambda (&optional _frame) nil)))
            (should-not (glassmacs--document-opening-action document))))
      (mapc (lambda (buffer)
              (when (buffer-live-p buffer) (kill-buffer buffer)))
            (list document special)))))

(ert-deftest glassmacs-document-opening-policy-is-persisted ()
  (let ((policies '(new-frame new-tab reuse-current))
         (original-default
          (default-value 'glassmacs-document-opening-policy)))
    (unwind-protect
        (dolist (policy policies)
          (let ((custom-file (make-temp-file "glassmacs-custom-")))
            (unwind-protect
                (progn
                  (delete-file custom-file)
                  (glassmacs-set-document-opening-policy policy)
                  (should (eq glassmacs-document-opening-policy policy))
                  (should (file-readable-p custom-file))
                  (set-default 'glassmacs-document-opening-policy
                               original-default)
                  (load custom-file nil t)
                  (should (eq glassmacs-document-opening-policy policy)))
              (when (file-exists-p custom-file)
                (delete-file custom-file)))))
      (set-default 'glassmacs-document-opening-policy original-default))))

(ert-deftest glassmacs-document-opening-command-works-graphically-and-in-terminal ()
  (let* ((custom-file (make-temp-file "glassmacs-custom-"))
         (policies '(new-frame new-tab reuse-current))
         (original-default
          (default-value 'glassmacs-document-opening-policy)))
    (unwind-protect
        (dolist (graphical '(nil t))
          (dolist (policy policies)
            (cl-letf (((symbol-function 'display-graphic-p)
                       (lambda (&optional _frame) graphical))
                      ((symbol-function 'completing-read)
                       (lambda (&rest _) (symbol-name policy))))
              (call-interactively #'glassmacs-set-document-opening-policy))
            (should (eq glassmacs-document-opening-policy policy))))
      (set-default 'glassmacs-document-opening-policy original-default)
      (when (file-exists-p custom-file)
        (delete-file custom-file)))))

(ert-deftest glassmacs-document-opening-policy-rejects-unknown-values ()
  (should-error (glassmacs-set-document-opening-policy 'unknown)
                :type 'user-error))

(ert-deftest glassmacs-file-menu-uses-document-opening-command ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (glassmacs--install-document-menu))
    (should (eq (lookup-key global-map [menu-bar file open-file])
                'glassmacs-open-file))
    (should (eq (lookup-key global-map [menu-bar file new-document])
                'glassmacs-new-document))
    (should (eq (lookup-key global-map [menu-bar file new-file])
                'glassmacs-open-file))))

(ert-deftest glassmacs-macos-menus-install-without-duplicating-cocoa-items ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin)
        (native-quit (lookup-key global-map [ns-power-off])))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (glassmacs--install-macos-menus)
      (glassmacs--install-macos-menus))
    (let ((menu (lookup-key global-map [menu-bar glassmacs]))
          (file-menu (lookup-key global-map [menu-bar file]))
          (window-menu (lookup-key global-map [menu-bar window]))
          (count 0))
      (map-keymap (lambda (event _binding)
                    (when (eq event 'glassmacs-new-window)
                      (setq count (1+ count))))
                  file-menu)
      (should (= count 1))
      (setq count 0)
      (map-keymap (lambda (event _binding)
                    (when (eq event 'glassmacs-new-window)
                      (setq count (1+ count))))
                  window-menu)
      (should (= count 1))
      (should-not (lookup-key menu [about]))
      (should-not (lookup-key menu [preferences]))
      (should (eq (lookup-key menu [keyboard-profile hybrid])
                  'glassmacs-select-hybrid-keyboard-profile))
      (should (eq (lookup-key menu [keyboard-profile traditional])
                  'glassmacs-select-traditional-keyboard-profile))
      (should (eq (lookup-key global-map [ns-power-off]) native-quit)))))

(ert-deftest glassmacs-native-preferences-menu-opens-glassmacs-settings ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (glassmacs--install-native-preferences-command)
    (should (eq (lookup-key global-map [ns-show-prefs])
                'glassmacs-open-preferences))))

(ert-deftest glassmacs-new-document-uses-each-configured-policy ()
  (let ((policies '(new-frame new-tab reuse-current))
        displayed)
    (unwind-protect
        (dolist (policy policies)
          (let ((glassmacs-document-opening-policy policy))
            (cl-letf (((symbol-function 'display-graphic-p)
                       (lambda (&optional _frame) t))
                      ((symbol-function 'called-interactively-p)
                       (lambda (&rest _) t))
                      ((symbol-function 'glassmacs--show-document-buffer)
                       (lambda (_buffer action)
                         (push action displayed))))
              (let ((buffer (call-interactively #'glassmacs-new-document)))
                (should (buffer-live-p buffer))
                (kill-buffer buffer)))))
      (should (equal (nreverse displayed) policies)))))

(ert-deftest glassmacs-cocoa-file-open-event-uses-document-policy ()
  (let* ((file (make-temp-file "glassmacs macOS ñ " nil ".R"))
         (ns-input-file (list file))
         (command-line-default-directory temporary-file-directory)
         (glassmacs-document-opening-policy 'new-tab)
         (shown nil))
    (unwind-protect
        (cl-letf (((symbol-function 'display-graphic-p)
                   (lambda (&optional _) t))
                  ((symbol-function 'ns-hide-emacs)
                   (lambda (&rest _) nil))
                  ((symbol-function 'glassmacs--show-document-buffer)
                   (lambda (buffer action)
                     (push (cons buffer action) shown))))
          (let ((buffer
                 (glassmacs--ns-find-file
                  (lambda (&rest _) (ert-fail "Cocoa file event was not intercepted")))))
            (should (buffer-live-p buffer))
            (should (equal (buffer-file-name buffer) (file-truename file))))
          (should (= 1 (length shown)))
          (should (eq (cdar shown) 'new-tab))
          (should-not ns-input-file))
      (delete-file file))))

(ert-deftest glassmacs-visible-document-is-not-opened-in-an-extra-frame ()
  (let ((buffer (generate-new-buffer "glassmacs-visible-document"))
        (old-buffer (window-buffer (selected-window)))
        frame-created)
    (unwind-protect
        (progn
          (set-window-buffer (selected-window) buffer)
          (cl-letf (((symbol-function 'select-frame-set-input-focus)
                     (lambda (&rest _) nil))
                    ((symbol-function 'make-frame)
                     (lambda (&rest _)
                       (setq frame-created t)
                       (error "A visible document must be reused"))))
            (glassmacs--show-document-buffer buffer 'new-frame))
          (should-not frame-created)
          (should (eq (window-buffer (selected-window)) buffer))
          (should (eq (selected-window)
                      (get-buffer-window buffer t))))
      (set-window-buffer (selected-window) old-buffer)
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(ert-deftest glassmacs-new-document-programmatic-call-does-not-create-frame ()
  (let ((glassmacs-document-opening-policy 'new-frame)
        (displayed nil))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t))
              ((symbol-function 'called-interactively-p)
               (lambda (&rest _) nil))
              ((symbol-function 'glassmacs--show-document-buffer)
               (lambda (&rest _) (setq displayed t))))
      (let ((buffer (glassmacs-new-document)))
        (should (buffer-live-p buffer))
        (should-not displayed)
        (kill-buffer buffer)))))

(ert-deftest glassmacs-open-file-policy-preserves-noninteractive-opens ()
  (let (called)
    (cl-letf (((symbol-function 'find-file)
               (lambda (filename &optional _wildcards)
                 (setq called filename)
                 'original-result)))
      (should
       (eq (glassmacs-open-file "/tmp/startup.R")
           'original-result))
      (should (equal called "/tmp/startup.R")))))

(ert-deftest glassmacs-diagnostics-report-local-capabilities-only ()
  (let ((glassmacs-home "/private/glassmacs")
        (buffer nil))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) nil))
              ((symbol-function 'locate-library)
               (lambda (_library &optional _path _nosuffix) nil))
              ((symbol-function 'executable-find)
               (lambda (_program) nil))
              ((symbol-function 'call-process)
               (lambda (&rest _) (ert-fail "Diagnostics must not run processes"))))
      (glassmacs-diagnostics)
      (setq buffer (get-buffer "*Glassmacs Diagnostics*"))
      (with-current-buffer buffer
        (goto-char (point-min))
        (should (search-forward "Emacs:" nil t))
        (should (search-forward "Operating system:" nil t))
        (should (search-forward "/private/glassmacs" nil t))
        (should (search-forward "ESS: not found" nil t))
        (should (search-forward "R: not found" nil t))
        (should-not (search-forward "SSH_AUTH_SOCK" nil t)))
      (kill-buffer buffer))))

(ert-deftest glassmacs-interactive-find-file-uses-configured-policy ()
  (let* ((file (make-temp-file "glassmacs-open-policy-"))
         (opened-buffer nil)
         (selected-action nil)
         (glassmacs-document-opening-policy 'reuse-current))
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'display-graphic-p)
                     (lambda (&optional _frame) t))
                    ((symbol-function 'find-file-read-args)
                     (lambda (&rest _) (list file nil)))
                    ((symbol-function 'called-interactively-p)
                     (lambda (&rest _) t))
                    ((symbol-function 'glassmacs--show-document-buffer)
                     (lambda (buffer action)
                       (setq opened-buffer buffer
                             selected-action action)
                       (switch-to-buffer buffer))))
            (call-interactively #'glassmacs-open-file))
          (should (buffer-live-p opened-buffer))
          (should (eq selected-action 'reuse-current)))
      (when (buffer-live-p opened-buffer)
        (kill-buffer opened-buffer))
      (delete-file file))))

(ert-deftest glassmacs-package-state-is-isolated ()
  (should (equal user-emacs-directory
                 (file-name-as-directory (expand-file-name glassmacs-home))))
  (should (equal package-user-dir
                 (expand-file-name "elpa" glassmacs-home))))

(ert-deftest glassmacs-startup-does-not-touch-ordinary-emacs-home ()
  (let* ((temporary-home (make-temp-file "glassmacs-startup-" t))
         (ordinary-home (expand-file-name "ordinary-home" temporary-home))
         (ordinary-emacs-directory (expand-file-name ".emacs.d" ordinary-home))
         (ordinary-config-directory (expand-file-name ".config" ordinary-home))
         (ordinary-init (expand-file-name "init.el" ordinary-emacs-directory))
         (ordinary-dotemacs (expand-file-name ".emacs" ordinary-home))
         (isolated-home (expand-file-name "glassmacs" temporary-home))
         (launcher (expand-file-name "scripts/glassmacs" glassmacs-root))
         (original-files nil)
         (output (generate-new-buffer " *glassmacs startup test*"))
         (status nil))
    (unwind-protect
        (progn
          (make-directory ordinary-emacs-directory t)
          (make-directory ordinary-config-directory t)
          (write-region "(error \"ordinary init must not load\")\n" nil
                        ordinary-init)
          (write-region "ordinary Emacs settings\n" nil ordinary-dotemacs)
          (setq original-files
                (directory-files-recursively ordinary-home "." t))
          (let* ((process-environment (copy-sequence process-environment))
                 (default-directory glassmacs-root)
                 (expression
                  (format
                   (concat
                    "(progn"
                    " (unless (equal user-emacs-directory %S)"
                    "   (error \"unexpected user-emacs-directory: %s\""
                    "          user-emacs-directory))"
                    " (unless (equal package-user-dir %S)"
                    "   (error \"unexpected package-user-dir: %s\""
                    "          package-user-dir))"
                    " (unless (equal custom-file %S)"
                    "   (error \"unexpected custom-file: %s\" custom-file))"
                    " (when (and (boundp 'native-comp-jit-compilation)"
                    "            native-comp-jit-compilation)"
                    "   (error \"Glassmacs left native JIT enabled\"))"
                    " (when (and (boundp 'native-comp-enable-subr-trampolines)"
                    "            native-comp-enable-subr-trampolines)"
                    "   (error \"Glassmacs left trampoline generation enabled\"))"
                    " (when (and (boundp 'native-comp-eln-load-path)"
                    "            (member (expand-file-name \"eln-cache/\""
                    "                                     (expand-file-name \".emacs.d/\""
                    "                                                       (getenv \"HOME\")))"
                    "                    native-comp-eln-load-path))"
                    "   (error \"Glassmacs included the ordinary user .eln cache\")))")
                   (file-name-as-directory isolated-home)
                   (file-name-as-directory isolated-home)
                   (expand-file-name "elpa" isolated-home)
                   (expand-file-name "elpa" isolated-home)
                   (expand-file-name "custom.el" isolated-home)
                   (expand-file-name "custom.el" isolated-home))))
            (setenv "HOME" ordinary-home)
            (setenv "XDG_CONFIG_HOME" ordinary-config-directory)
            (setenv "GLASSMACS_HOME" isolated-home)
            (setq status
                  (call-process launcher nil output t
                                "--batch" "--eval" expression)))
          (unless (and (integerp status) (zerop status))
            (ert-fail
             (format "Glassmacs launcher failed (%s): %s"
                     status
                     (with-current-buffer output (buffer-string)))))
          (should (equal original-files
                         (directory-files-recursively ordinary-home "." t)))
          (with-temp-buffer
            (insert-file-contents ordinary-init)
            (should (equal (buffer-string)
                           "(error \"ordinary init must not load\")\n")))
          (with-temp-buffer
            (insert-file-contents ordinary-dotemacs)
            (should (equal (buffer-string) "ordinary Emacs settings\n")))
          (should-not (file-exists-p
                       (expand-file-name "elpa" ordinary-emacs-directory)))
          (should-not (file-exists-p
                       (expand-file-name "glassmacs" ordinary-config-directory))))
      (when (buffer-live-p output)
        (kill-buffer output))
      (delete-directory temporary-home t))))

(ert-deftest glassmacs-launcher-forwards-emacs-arguments ()
  (let* ((directory (make-temp-file "glassmacs-launcher-" t))
        (fake-emacs (expand-file-name "fake-emacs" directory))
        (arguments-file (expand-file-name "arguments" directory))
        (launcher (expand-file-name "scripts/glassmacs" glassmacs-root))
        (arguments '("-nw" "some file.R"
                     "/ssh:research:/home/user/project/analysis.R"
                     "--eval" "(message \"argument preserved\")"))
        (status nil))
    (unwind-protect
        (progn
         (with-temp-file fake-emacs
           (insert "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$GLASSMACS_TEST_ARGS\"\n"))
         (set-file-modes fake-emacs #o755)
         (let ((process-environment (copy-sequence process-environment)))
           (setenv "GLASSMACS_EMACS" fake-emacs)
           (setenv "GLASSMACS_TEST_ARGS" arguments-file)
           (setq status (apply #'call-process launcher nil nil nil arguments)))
         (should (zerop status))
         (should
          (equal
           (with-temp-buffer
             (insert-file-contents arguments-file)
             (split-string (buffer-string) "\n" t))
           (append '("-Q" "--load")
                   (list (expand-file-name "init.el" glassmacs-root))
                   arguments))))
      (delete-directory directory t))))

(ert-deftest glassmacs-launcher-reports-a-missing-emacs ()
  (let* ((directory (make-temp-file "glassmacs-launcher-missing-" t))
        (launcher (expand-file-name "scripts/glassmacs" glassmacs-root))
        (error-file (expand-file-name "stderr" directory))
        (output (generate-new-buffer " *glassmacs missing Emacs*"))
        (status nil))
    (unwind-protect
        (progn
         (let ((process-environment (copy-sequence process-environment)))
           (setenv "GLASSMACS_EMACS"
                   (expand-file-name "not-installed" directory))
           (setq status
                 (call-process launcher nil (list output error-file) nil)))
         (should (equal status 127))
         (with-temp-buffer
           (insert-file-contents error-file)
           (should (search-forward "GNU Emacs executable" nil t))
           (should (search-forward "GLASSMACS_EMACS" nil t))))
      (when (buffer-live-p output)
        (kill-buffer output))
      (delete-directory directory t))))

(ert-deftest glassmacs-plain-text-files-open-and-save-without-research-tools ()
  (let* ((directory (make-temp-file "glassmacs-plain-text-" t))
         (text-file (expand-file-name "notes.txt" directory))
         (extensionless-file (expand-file-name "NOTES" directory))
         buffers)
    (unwind-protect
        (cl-letf (((symbol-function 'executable-find)
                   (lambda (_program) nil))
                  ((symbol-function 'locate-library)
                   (lambda (_library &optional _path _nosuffix) nil)))
          (with-temp-file text-file
            (insert "plain text\n"))
          (with-temp-file extensionless-file
            (insert "extensionless text\n"))
          (push (find-file-noselect text-file) buffers)
          (push (find-file-noselect extensionless-file) buffers)
          (with-current-buffer (car (last buffers))
            (should (derived-mode-p 'text-mode))
            (goto-char (point-max))
            (insert "edited\n")
            (save-buffer))
          (with-current-buffer (car buffers)
            (should (eq major-mode 'fundamental-mode))
            (goto-char (point-max))
            (insert "edited\n")
            (save-buffer))
          (with-temp-buffer
            (insert-file-contents text-file)
            (should (equal (buffer-string) "plain text\nedited\n")))
          (with-temp-buffer
            (insert-file-contents extensionless-file)
            (should (equal (buffer-string) "extensionless text\nedited\n"))))
      (dolist (buffer buffers)
        (when (buffer-live-p buffer)
          (kill-buffer buffer)))
      (delete-directory directory t))))

(ert-deftest glassmacs-hybrid-bindings-are-defined ()
  (dolist (binding glassmacs-hybrid-keybindings)
    (should (commandp (cdr binding))))
  (should (eq (cdr (assoc [?\s-o] glassmacs-hybrid-keybindings))
              'glassmacs-open-file))
  (should (eq (cdr (assoc [?\s-S] glassmacs-hybrid-keybindings)) 'write-file))
  (should (eq (cdr (assoc [?\s-q] glassmacs-hybrid-keybindings))
              'save-buffers-kill-emacs)))

(ert-deftest glassmacs-does-not-rebind-emacs-prefix-keys ()
  (should (eq (lookup-key global-map (kbd "C-x")) 'Control-X-prefix))
  (should (eq (lookup-key global-map (kbd "C-c")) 'mode-specific-command-prefix))
  (should (eq (lookup-key global-map (kbd "M-x")) 'execute-extended-command)))

(ert-deftest glassmacs-installs-bindings-only-in-macos-graphical-frames ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (let ((glassmacs--saved-hybrid-keybindings nil))
      (cl-letf (((symbol-function 'display-graphic-p)
                 (lambda (&optional _frame) t)))
        (glassmacs--install-hybrid-bindings))
      (should (eq (lookup-key global-map [?\s-o]) 'glassmacs-open-file))))
  (let ((global-map (copy-keymap global-map))
        (system-type 'gnu/linux))
    (let ((glassmacs--saved-hybrid-keybindings nil))
      (cl-letf (((symbol-function 'display-graphic-p)
                 (lambda (&optional _frame) t)))
        (glassmacs--install-hybrid-bindings))
      (should-not (eq (lookup-key global-map [?\s-o]) 'glassmacs-open-file))))
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (let ((glassmacs--saved-hybrid-keybindings nil))
      (cl-letf (((symbol-function 'display-graphic-p)
                 (lambda (&optional _frame) nil)))
        (glassmacs--install-hybrid-bindings))
      (should-not (eq (lookup-key global-map [?\s-o]) 'glassmacs-open-file)))))

(ert-deftest glassmacs-hybrid-profile-can-be-disabled ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin)
        (glassmacs-keyboard-profile nil)
        (glassmacs--saved-hybrid-keybindings nil)
        (original (lookup-key global-map [?\s-o])))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (glassmacs--install-hybrid-bindings))
    (should (equal (lookup-key global-map [?\s-o]) original))))

(ert-deftest glassmacs-traditional-profile-restores-hybrid-overrides ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin)
        (glassmacs-keyboard-profile 'glassmacs-hybrid)
        (glassmacs--saved-hybrid-keybindings nil))
    (define-key global-map [?\s-o] #'find-file)
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (glassmacs--install-hybrid-bindings)
      (should (eq (lookup-key global-map [?\s-o]) 'glassmacs-open-file))
      (setq glassmacs-keyboard-profile 'traditional-emacs)
      (glassmacs--install-hybrid-bindings)
      (should (eq (lookup-key global-map [?\s-o]) 'find-file))
      (setq glassmacs-keyboard-profile 'glassmacs-hybrid)
      (glassmacs--install-hybrid-bindings)
      (should (eq (lookup-key global-map [?\s-o]) 'glassmacs-open-file))
      (define-key global-map [?\s-o] #'find-file-literally)
      (setq glassmacs-keyboard-profile 'traditional-emacs)
      (glassmacs--install-hybrid-bindings)
      (should (eq (lookup-key global-map [?\s-o]) 'find-file-literally)))))

(ert-deftest glassmacs-hybrid-profile-follows-selected-frame-type ()
  (let* ((global-map (copy-keymap global-map))
         (system-type 'darwin)
         (glassmacs-keyboard-profile 'glassmacs-hybrid)
         (glassmacs--saved-hybrid-keybindings nil)
         (original (lookup-key global-map [?\s-o])))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (frame) (eq frame 'graphical-frame))))
      (glassmacs--install-hybrid-bindings 'graphical-frame)
      (should (eq (lookup-key global-map [?\s-o]) 'glassmacs-open-file))
      (glassmacs--install-hybrid-bindings 'terminal-frame)
      (should (equal (lookup-key global-map [?\s-o]) original))
      (glassmacs--install-hybrid-bindings 'graphical-frame)
      (should (eq (lookup-key global-map [?\s-o]) 'glassmacs-open-file)))))

(ert-deftest glassmacs-keyboard-profile-is-persisted ()
  (let ((custom-file (make-temp-file "glassmacs-custom-"))
        (original-default (default-value 'glassmacs-keyboard-profile)))
    (unwind-protect
        (progn
          (delete-file custom-file)
          (glassmacs-set-keyboard-profile 'traditional-emacs)
          (should (eq (default-value 'glassmacs-keyboard-profile)
                      'traditional-emacs))
          (should (file-readable-p custom-file))
          (set-default 'glassmacs-keyboard-profile 'glassmacs-hybrid)
          (load custom-file nil t)
          (should (eq (default-value 'glassmacs-keyboard-profile)
                      'traditional-emacs)))
      (when (file-exists-p custom-file)
        (delete-file custom-file))
      (set-default 'glassmacs-keyboard-profile original-default))))

(ert-deftest glassmacs-file-associations-are-present ()
  (dolist (entry '(("\\.[Rr]\\'" . glassmacs-r-mode)
                   ("\\.Rmd\\'" . glassmacs-rmarkdown-mode)
                   ("\\.qmd\\'" . glassmacs-quarto-mode)
                   ("\\.\\(?:Rnw\\|Snw\\)\\'" . glassmacs-sweave-mode)
                   ("\\.Rd\\'" . glassmacs-rd-mode)))
    (should (member entry auto-mode-alist))))

(ert-deftest glassmacs-themes-load ()
  (glassmacs-load-theme 'dark)
  (should (memq 'glassmacs-dark custom-enabled-themes))
  (glassmacs-load-theme 'light)
  (should (memq 'glassmacs-light custom-enabled-themes)))

(ert-deftest glassmacs-optional-tools-fail-clearly ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_program) nil)))
    (should-error (glassmacs-run-process "missing-tool" nil)
                  :type 'user-error))
  (cl-letf (((symbol-function 'locate-library) (lambda (_library) nil)))
    (should-error (glassmacs-r-start) :type 'user-error)))

(ert-deftest glassmacs-renderers-report-missing-executables ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/report with spaces.Rmd")
    (cl-letf (((symbol-function 'executable-find) (lambda (_program) nil)))
      (should-error (glassmacs-render-rmarkdown) :type 'user-error)
      (should-error (glassmacs-render-quarto) :type 'user-error)
      (should-error (glassmacs-knit-sweave) :type 'user-error))))

(ert-deftest glassmacs-shiny-reports-missing-rscript ()
  (let ((directory (make-temp-file "glassmacs-shiny-test-" t)))
    (unwind-protect
        (progn
          (write-region "" nil (expand-file-name "app.R" directory))
          (let ((default-directory directory))
            (cl-letf (((symbol-function 'executable-find)
                       (lambda (_program) nil)))
              (should-error (glassmacs-shiny-start) :type 'user-error))))
      (delete-directory directory t))))

(ert-deftest glassmacs-r-string-literals-escape-special-characters ()
  (should (equal (glassmacs-r-quote "a\\b\"c\n")
                 "\"a\\\\b\\\"c\\n\"")))

(ert-deftest glassmacs-rscript-evaluates-when-installed ()
  (unless (executable-find "Rscript")
    (ert-skip "Rscript is not installed"))
  (with-temp-buffer
    (should (zerop (process-file "Rscript" nil t nil "-e"
                                 "stopifnot(1 + 1 == 2)")))))

(ert-deftest glassmacs-rscript-renders-base-plot-to-png-when-available ()
  (unless (executable-find "Rscript")
    (ert-skip "Rscript is not installed"))
  (unless (zerop (process-file "Rscript" nil nil nil "-e"
                               "quit(status = !capabilities('png'))"))
    (ert-skip "R build has no PNG graphics capability"))
  (let ((image (make-temp-file "glassmacs-plot-" nil ".png")))
    (unwind-protect
        (let ((status
               (process-file
                "Rscript" nil nil nil "-e"
                (format "png(%s); plot(cars); dev.off()"
                        (glassmacs-r-quote image)))))
          (should (zerop status))
          (should (> (file-attribute-size (file-attributes image)) 0)))
      (when (file-exists-p image)
        (delete-file image)))))

(ert-deftest glassmacs-ess-mode-is-available-when-installed ()
  (unless (locate-library "ess-r-mode")
    (ert-skip "ESS is not installed"))
  (require 'ess-r-mode)
  (with-temp-buffer
    (ess-r-mode)
    (should (eq major-mode 'ess-r-mode))
    (should (eq (key-binding (kbd "C-c C-c"))
                'ess-eval-region-or-function-or-paragraph-and-step))
    (should (eq (key-binding (kbd "C-c C-r")) 'ess-eval-region))))

(ert-deftest glassmacs-ess-starts-r-and-evaluates-when-available ()
  (unless (and (locate-library "ess-site") (executable-find "R"))
    (ert-skip "ESS and R are required for the ESS integration test"))
  (require 'ess-site)
  (let ((ess-ask-for-ess-directory nil)
        (ess-ask-about-ess-directory nil)
        (buffer nil)
        process)
    (unwind-protect
        (progn
          (glassmacs-r-start)
          (setq buffer (get-buffer "*R*"))
          (unless buffer
            (setq buffer
                  (cl-find-if
                   (lambda (candidate)
                     (and (buffer-live-p candidate)
                          (get-buffer-process candidate)
                          (with-current-buffer candidate
                            (derived-mode-p 'inferior-ess-mode))))
                   (buffer-list))))
          (should buffer)
          (setq process (get-buffer-process buffer))
          (should (process-live-p process))
          (ess-wait-for-process process)
          (ess-send-string process "cat('GLASSMACS_ERT_OK')\n")
          (let ((deadline (+ (float-time) 15))
                found)
            (while (and (not found) (< (float-time) deadline))
              (accept-process-output process 0.1)
              (with-current-buffer buffer
                (setq found
                      (save-excursion
                        (goto-char (point-min))
                        (search-forward "GLASSMACS_ERT_OK" nil t)))))
            (should found)))
      (when (and (processp process) (process-live-p process))
        (set-process-query-on-exit-flag process nil)
        (delete-process process))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(provide 'test-glassmacs)
;;; test-glassmacs.el ends here

(defmacro glassmacs-test-with-profile (profile &rest body)
  "Run BODY with PROFILE installed on a copy of the global map."
  (declare (indent 1))
  `(let ((global-map (copy-keymap global-map))
         (system-type 'darwin)
         (glassmacs--saved-hybrid-keybindings nil)
         (glassmacs-keyboard-profile ,profile))
     (cl-letf (((symbol-function 'display-graphic-p)
                (lambda (&optional _frame) t)))
       (glassmacs--install-hybrid-bindings)
       ,@body)))

(ert-deftest glassmacs-command-n-is-new-document-in-hybrid-profile ()
  ;; Cocoa delivers Command-N as the integer event ?\s-n, not `super-n'.
  (glassmacs-test-with-profile 'glassmacs-hybrid
    (should (eq (lookup-key global-map [?\s-n]) 'glassmacs-new-document))))

(ert-deftest glassmacs-command-n-is-new-frame-in-traditional-profile ()
  (glassmacs-test-with-profile 'traditional-emacs
    (should-not (eq (lookup-key global-map [?\s-n]) 'glassmacs-new-document))))

(ert-deftest glassmacs-hybrid-bindings-use-cocoa-integer-events ()
  (dolist (binding glassmacs-hybrid-keybindings)
    (should (integerp (aref (car binding) 0)))))

(ert-deftest glassmacs-file-menu-dispatches-new-window-and-new-document ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (require 'menu-bar)
      (glassmacs--install-document-menu)
      (glassmacs--install-macos-menus))
    (should (eq (lookup-key global-map [menu-bar file new-document])
                'glassmacs-new-document))
    (should (eq (lookup-key global-map [menu-bar file glassmacs-new-window])
                'glassmacs-new-window))))

(ert-deftest glassmacs-new-document-creates-distinct-buffers ()
  (let (first second)
    (unwind-protect
        (progn
          (setq first (glassmacs-new-document)
                second (glassmacs-new-document))
          (should (buffer-live-p first))
          (should-not (eq first second))
          (should-not (eq first (get-buffer "*scratch*")))
          (should-not (buffer-file-name first)))
      (mapc #'kill-buffer (delq nil (list first second))))))

(ert-deftest glassmacs-new-window-restores-hidden-frame-without-new-frame ()
  (let ((system-type 'darwin)
        (glassmacs--hidden-final-frame 'hidden)
        shown created buffers-created)
    (cl-letf (((symbol-function 'frame-live-p) (lambda (f) (eq f 'hidden)))
              ((symbol-function 'frame-visible-p) (lambda (_f) nil))
              ((symbol-function 'make-frame-visible)
               (lambda (f) (setq shown f)))
              ((symbol-function 'select-frame-set-input-focus) #'ignore)
              ((symbol-function 'generate-new-buffer)
               (lambda (&rest _) (setq buffers-created t)))
              ((symbol-function 'make-frame-command)
               (lambda () (setq created t))))
      (glassmacs-new-window)
      (should (eq shown 'hidden))
      (should-not created)
      (should-not buffers-created))))

(ert-deftest glassmacs-reopen-and-new-window-share-semantics ()
  (let ((system-type 'darwin) (glassmacs--hidden-final-frame nil) created)
    (cl-letf (((symbol-function 'make-frame-command)
               (lambda () (setq created t))))
      (glassmacs-reopen)
      (should created))))

;;; Windowless (no visible frame) command handling.  These are mock tests;
;;; real Cocoa event delivery is exercised by the physical-Mac procedure.

(defmacro glassmacs-test-windowless (&rest body)
  "Run BODY with one hidden retained frame `hid' and no visible frame."
  (declare (indent 0))
  `(let ((system-type 'darwin)
         (glassmacs--hidden-final-frame 'hid)
         (visible nil) made buffers-shown)
     (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) t))
               ((symbol-function 'called-interactively-p) (lambda (&rest _) t))
               ((symbol-function 'frame-list) (lambda () '(hid)))
               ((symbol-function 'frame-live-p) (lambda (f) (eq f 'hid)))
               ((symbol-function 'frame-parent) (lambda (_f) nil))
               ((symbol-function 'frame-visible-p) (lambda (_f) visible))
               ((symbol-function 'make-frame-visible)
                (lambda (_f) (setq visible t)))
               ((symbol-function 'select-frame-set-input-focus) #'ignore)
               ((symbol-function 'make-frame)
                (lambda (&rest _) (setq made t) 'new))
               ((symbol-function 'make-frame-command)
                (lambda () (setq made t)))
               ((symbol-function 'switch-to-buffer)
                (lambda (b &rest _) (push b buffers-shown))))
       ,@body)))

(ert-deftest glassmacs-windowless-detects-no-visible-frame ()
  (glassmacs-test-windowless
    (should (glassmacs--no-visible-graphical-frame-p))
    (setq visible t)
    (should-not (glassmacs--no-visible-graphical-frame-p))))

(ert-deftest glassmacs-windowless-new-document-reuses-hidden-frame-per-policy ()
  (dolist (policy '(new-frame new-tab reuse-current))
    (glassmacs-test-windowless
      (let ((glassmacs-document-opening-policy policy) buffer)
        (unwind-protect
            (progn
              (setq buffer (call-interactively #'glassmacs-new-document))
              (should visible)
              (should-not made)
              (should (equal buffers-shown (list buffer)))
              (should-not (eq buffer (get-buffer "*scratch*")))
              (should-not glassmacs--hidden-final-frame))
          (when (buffer-live-p buffer) (kill-buffer buffer)))))))

(ert-deftest glassmacs-windowless-open-file-shows-in-hidden-frame ()
  (glassmacs-test-windowless
    (let ((glassmacs-document-opening-policy 'new-frame)
          (buffer (generate-new-buffer "doc.txt")))
      (unwind-protect
          (progn
            (glassmacs--show-document-buffer buffer 'new-frame)
            (should visible)
            (should-not made)
            (should (equal buffers-shown (list buffer))))
        (kill-buffer buffer)))))

(ert-deftest glassmacs-visible-new-document-still-honors-new-frame-policy ()
  (let ((system-type 'darwin)
        (glassmacs--hidden-final-frame nil)
        (glassmacs-document-opening-policy 'new-frame)
        made buffer)
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) t))
              ((symbol-function 'called-interactively-p) (lambda (&rest _) t))
              ((symbol-function 'frame-list) (lambda () '(vis)))
              ((symbol-function 'frame-live-p) (lambda (f) (eq f 'vis)))
              ((symbol-function 'frame-parent) (lambda (_f) nil))
              ((symbol-function 'frame-visible-p) (lambda (_f) t))
              ((symbol-function 'make-frame)
               (lambda (&rest _) (setq made t) (selected-frame)))
              ((symbol-function 'select-frame-set-input-focus) #'ignore))
      (unwind-protect
          (progn (setq buffer (call-interactively #'glassmacs-new-document))
                 (should made))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest glassmacs-windowless-buffer-command-reveals-frame ()
  (glassmacs-test-windowless
    (let ((glassmacs--command-started-windowless nil)
          (this-command 'switch-to-buffer))
      (glassmacs--note-windowless-command-start)
      (should glassmacs--command-started-windowless)
      (glassmacs--reveal-frame-after-windowless-command)
      (should visible)
      (should-not made))))

(ert-deftest glassmacs-windowless-quit-and-hide-do-not-reveal-frame ()
  (dolist (command '(save-buffers-kill-emacs kill-emacs delete-frame))
    (glassmacs-test-windowless
      (let ((glassmacs--command-started-windowless t)
            (this-command command))
        (glassmacs--reveal-frame-after-windowless-command)
        (should-not visible)))))

(ert-deftest glassmacs-command-started-visible-does-not-reveal-frame ()
  (glassmacs-test-windowless
    (setq visible t)
    (let ((glassmacs--command-started-windowless nil)
          (this-command 'switch-to-buffer))
      (glassmacs--reveal-frame-after-windowless-command)
      (should-not glassmacs--command-started-windowless))))

(ert-deftest glassmacs-windowless-dock-reopen-creates-no-buffers ()
  (glassmacs-test-windowless
    (let ((before (buffer-list)))
      (glassmacs-reopen)
      (should visible)
      (should-not made)
      (should (equal before (buffer-list))))))

(ert-deftest glassmacs-windowless-hooks-are-installed ()
  (glassmacs-test-with-installed-lifecycle
    (should (memq #'glassmacs--note-windowless-command-start
                  pre-command-hook))
    (should (memq #'glassmacs--reveal-frame-after-windowless-command
                  post-command-hook))))

(ert-deftest glassmacs-windowless-command-n-follows-keyboard-profile ()
  (glassmacs-test-with-profile 'glassmacs-hybrid
    (should (eq (lookup-key global-map [?\s-n]) 'glassmacs-new-document)))
  ;; Only Cocoa's ns-win.el binds Command-N to `make-frame'; emulate it.
  (let ((global-map (copy-keymap global-map)))
    (define-key global-map [?\s-n] 'make-frame)
    (glassmacs-test-with-profile 'traditional-emacs
      (should (eq (lookup-key global-map [?\s-n]) 'make-frame)))))
