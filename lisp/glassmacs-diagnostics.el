;;; glassmacs-diagnostics.el --- Local Glassmacs diagnostics -*- lexical-binding: t; -*-

;; `glassmacs-diagnostics' reports what Glassmacs found on this machine.
;; `glassmacs-self-check' runs the acceptance checks that can be made from
;; inside a running Glassmacs (see docs/acceptance-matrix.md), so that a
;; maintainer can run them on any Mac; the GUI acceptance harness in CI
;; (scripts/macos-gui-acceptance) runs the same checks against the packaged
;; app.  Neither runs R or other programs, changes files or settings, or
;; touches the clipboard.

(require 'cl-lib)
(require 'subr-x)

(defun glassmacs-diagnostics ()
  "Display local startup and optional R/ESS availability information."
  (interactive)
  (let ((buffer (get-buffer-create "*Glassmacs Diagnostics*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert
         (format "Glassmacs diagnostics\n\nEmacs: %s\nOperating system: %s\nWindow system: %s\nGlassmacs home: %s\n\n"
                 emacs-version system-type
                 (if (display-graphic-p) (or window-system "graphical") "terminal")
                 glassmacs-home)
         (format "Shell environment: %s\n"
                 (if (boundp 'glassmacs-environment-status)
                     glassmacs-environment-status
                   "unknown"))
         (format "Spell checker: %s\n"
                 (or (and (fboundp 'glassmacs-spelling-program)
                          (glassmacs-spelling-program))
                     "not found (brew install enchant or hunspell)"))
         (format "ESS: %s\nR: %s\nRscript: %s\n\n"
                 (if (locate-library "ess-site") "available" "not found")
                 (if (executable-find "R") "available" "not found")
                 (if (executable-find "Rscript") "available" "not found"))
         "Graphics guidance:\n"
         (if (and (eq system-type 'darwin) (display-graphic-p))
             (concat
              "In an ESS session, evaluate plot(cars) to check the R build's native macOS graphics device. "
              "If available, try ggplot2 separately. Use X11() only when XQuartz and its display are explicitly configured; Glassmacs does not select it automatically.\n")
           (concat
            "Graphics-device behavior depends on the R installation and display. "
            "A native macOS GUI graphics check requires graphical macOS Emacs and an ESS R session; X11 is optional and must be configured explicitly.\n"))
         "\nThis report is local. It does not include environment variables, credentials, process output, or project contents.\n")
        (special-mode)))
    (display-buffer buffer)))

;;; Menus

;; Emacs evaluates each menu item's :enable, :visible and :button forms and
;; calls its :filter whenever it builds the menu bar, which on macOS happens
;; when the Cocoa menu is updated.  GNU Emacs catches errors there, but the
;; item then silently disappears or empties and the error is logged on
;; every update; in Aquamacs, some modes' menus crashed the app (Aquamacs
;; issues #180, #256).  This walks the menus active in a buffer the same
;; way and reports errors and missing Glassmacs commands, without running
;; any command.

(defconst glassmacs-diagnostics--menu-depth-limit 8
  "Deepest submenu level checked.")

(defun glassmacs-diagnostics--menu-name (name)
  "Return NAME, a menu item name that may be a form, as a string."
  (cond ((stringp name) name)
        (t (condition-case nil (format "%s" (eval name t))
             (error (format "%S" name))))))

(defun glassmacs-diagnostics--check-form (form what path problems)
  "Evaluate FORM, a menu item's WHAT property, at PATH.
Return (VALUE . PROBLEMS): FORM's value, or nil with a description of
the error added to PROBLEMS when FORM signals one."
  (condition-case err
      (cons (eval form t) problems)
    (error (cons nil (cons (format "%s: %s signals %s" path what
                                   (error-message-string err))
                           problems)))))

(defun glassmacs-diagnostics--walk-menu (keymap path depth seen problems)
  "Check the items of menu KEYMAP at PATH; return PROBLEMS with any found.
DEPTH is the submenu level and SEEN the keymaps already checked.  As
when Emacs builds the menu, a hidden item is not looked at further, and
a disabled item's command and submenu are never used, so neither is
checked."
  (if (or (> depth glassmacs-diagnostics--menu-depth-limit) (memq keymap seen))
      problems
    (push keymap seen)
    (map-keymap
     (lambda (event binding)
       (let ((name (format "%s" event))
             (definition binding)
             (properties nil)
             (shown t)
             (enabled t))
         (pcase binding
           (`(menu-item ,item-name ,item-definition . ,item-properties)
            (setq name (glassmacs-diagnostics--menu-name item-name)
                  definition item-definition
                  properties item-properties))
           (`(,(and (pred stringp) item-name) . ,rest)
            (setq name item-name
                  definition (if (stringp (car-safe rest)) (cdr rest) rest))))
         (let ((item-path (concat path " > " name)))
           (when (plist-member properties :visible)
             (pcase-let ((`(,value . ,found) (glassmacs-diagnostics--check-form
                                              (plist-get properties :visible)
                                              :visible item-path problems)))
               (setq shown value problems found)))
           (when shown
             (when (plist-member properties :enable)
               (pcase-let ((`(,value . ,found) (glassmacs-diagnostics--check-form
                                                (plist-get properties :enable)
                                                :enable item-path problems)))
                 (setq enabled value problems found)))
             (when-let* ((button (plist-get properties :button)))
               (setq problems (cdr (glassmacs-diagnostics--check-form
                                    (cdr button) :button item-path problems))))
             (when-let* ((filter (plist-get properties :filter)))
               (condition-case err
                   (setq definition (funcall filter definition))
                 (error (push (format "%s: :filter signals %s" item-path
                                      (error-message-string err))
                              problems))))
             (cond
              ((not enabled))
              ((and (symbolp definition) definition
                    (autoloadp (symbol-function definition))))
              ((keymapp definition)
               (setq problems (glassmacs-diagnostics--walk-menu
                               (if (symbolp definition)
                                   (indirect-function definition)
                                 definition)
                               item-path (1+ depth) seen problems)))
              ;; Upstream menus name commands of libraries loaded on
              ;; demand (elp, for example); only Glassmacs's own must exist.
              ((and (symbolp definition) definition
                    (string-prefix-p "glassmacs-" (symbol-name definition))
                    (not (fboundp definition)))
               (push (format "%s: command %s does not exist" item-path definition)
                     problems)))))))
     keymap)
    problems))

(defun glassmacs-diagnostics-menu-problems (&optional buffer)
  "Return problems in the menu bar as it is built for BUFFER.
BUFFER defaults to the current buffer.  Each problem is a string naming
the menu item: a :visible, :enable, :button or :filter that signals an
error anywhere, or a Glassmacs command that does not exist.  The menu
bar update hook runs first, as when Emacs updates the menu bar."
  (with-current-buffer (or buffer (current-buffer))
    (let ((problems nil))
      (condition-case err
          (run-hooks 'menu-bar-update-hook)
        (error (push (format "menu-bar-update-hook signals %s"
                             (error-message-string err))
                     problems)))
      (dolist (map (current-active-maps t))
        (let ((menu (lookup-key map [menu-bar])))
          (when (keymapp menu)
            (setq problems (glassmacs-diagnostics--walk-menu
                            menu (buffer-name) 0 nil problems)))))
      (nreverse (delete-dups problems)))))

;;; Self-check

(defvar glassmacs-root)
(defvar glassmacs-follow-file-changes)

(defun glassmacs-diagnostics--native-code-check ()
  "Return (STATUS . DETAIL) for the native-code policy."
  (if (not (and (fboundp 'native-comp-available-p) (native-comp-available-p)))
      '(info . "this Emacs has no native compilation")
    (let ((jit (bound-and-true-p native-comp-jit-compilation))
          (writable (cl-remove-if-not #'file-writable-p
                                      (bound-and-true-p native-comp-eln-load-path))))
      (cond (jit '(fail . "just-in-time native compilation is on"))
            (writable (cons 'fail (format "user-writable native code directories: %s"
                                          (string-join writable ", "))))
            (t '(pass . "compilation off; only read-only native code directories"))))))

(defun glassmacs-diagnostics--literal-text-check ()
  "Return (STATUS . DETAIL) for the literal text entry policy."
  (let ((on (cl-remove-if-not
             (lambda (variable) (and (boundp variable) (symbol-value variable)))
             '(electric-quote-mode abbrev-mode
               markdown-gfm-use-electric-backquote))))
    (if on
        (cons 'fail (format "text transformations on: %s"
                            (mapconcat #'symbol-name on ", ")))
      '(pass . "no automatic text transformations are on"))))

(defun glassmacs-self-check-results ()
  "Run the in-app acceptance checks and return their results.
Each result is a list (CHECK STATUS DETAIL), where CHECK names the check,
STATUS is `pass', `fail', `warn' or `info', and DETAIL explains it."
  (let* ((graphical (display-graphic-p))
         (macos (eq system-type 'darwin))
         (menus (glassmacs-diagnostics-menu-problems))
         (warnings (when-let* ((buffer (get-buffer "*Warnings*")))
                     (with-current-buffer buffer
                       (cl-remove-if-not
                        (lambda (line) (string-match-p "glassmacs" line))
                        (split-string (buffer-string) "\n" t)))))
         (results
          (list
           (list "Graphical macOS session"
                 (if (and macos graphical (eq window-system 'ns)) 'pass 'info)
                 (format "system %s, window system %s" system-type window-system))
           (list "Startup warnings"
                 (if warnings 'warn 'pass)
                 (if warnings (string-join warnings "; ") "none from Glassmacs"))
           (cons "Native code policy" (let ((check (glassmacs-diagnostics--native-code-check)))
                                        (list (car check) (cdr check))))
           (cons "Literal text entry" (let ((check (glassmacs-diagnostics--literal-text-check)))
                                        (list (car check) (cdr check))))
           (list "Follow file changes"
                 (if (or noninteractive
                         (not glassmacs-follow-file-changes)
                         (bound-and-true-p global-auto-revert-mode))
                     'pass 'fail)
                 (format "%s; notifications: %s"
                         (if (bound-and-true-p global-auto-revert-mode) "on" "off")
                         (or (bound-and-true-p file-notify--library) "polling")))
           (list "Shell environment"
                 (if (string-match-p "failed" (format "%s" (bound-and-true-p
                                                          glassmacs-environment-status)))
                     'warn 'pass)
                 (format "%s" (bound-and-true-p glassmacs-environment-status)))
           (list "Spell checker"
                 (if (and (fboundp 'glassmacs-spelling-program)
                          (glassmacs-spelling-program))
                     'pass 'info)
                 (or (and (fboundp 'glassmacs-spelling-program)
                          (glassmacs-spelling-program))
                     "none found; spelling is unavailable but editing is unaffected"))
           (list (format "Menus in %s" (buffer-name))
                 (if menus 'fail 'pass)
                 (if menus (string-join menus "; ") "every item evaluates")))))
    results))

(defun glassmacs-self-check ()
  "Run Glassmacs's in-app acceptance checks and show the results.
The checks look at the running session only: no programs are run and no
files, settings or clipboard contents change.  Menus are checked for the
buffer that was current, so run this from the kind of document to check.
See docs/acceptance-matrix.md for the checks that need a person."
  (interactive)
  (let ((results (glassmacs-self-check-results))
        (buffer (get-buffer-create "*Glassmacs Self-Check*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Glassmacs self-check — %s\n\n"
                        (format-time-string "%F %T")))
        (dolist (result results)
          (insert (format "%-5s %s: %s\n"
                          (upcase (symbol-name (nth 1 result)))
                          (nth 0 result) (nth 2 result))))
        (insert "\nChecks that need a person (Dock, Finder, dialogs, keyboard layouts,\n"
                "displays, signing) are listed in docs/macos-acceptance-checklist.md.\n")
        (special-mode)))
    (display-buffer buffer)
    results))

(provide 'glassmacs-diagnostics)
;;; glassmacs-diagnostics.el ends here
