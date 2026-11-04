;;; glassmacs-menu.el --- Dynamic key labels for Glassmacs menus -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun glassmacs-menu-effective-key-description (command)
  "Return an active keyboard binding for COMMAND, or the empty string.
Bindings that are shadowed in the current context and mouse/menu-bar
events are ignored.  The lookup is side-effect-free and is intended for
menu `:keys' functions, which Emacs calls whenever it computes a menu."
  (let ((bindings (where-is-internal command (current-active-maps))))
    (setq bindings
          (cl-remove-if-not
           (lambda (sequence)
             (and (vectorp sequence)
                  (not (cl-some
                        (lambda (event)
                          (or (memq (event-basic-type event)
                                    '(menu-bar tool-bar mode-line))
                              (mouse-event-p event)))
                        sequence))
                  (eq (key-binding sequence t) command)))
           bindings))
    (if bindings
        (key-description (car bindings))
      "")))

(defun glassmacs-menu--annotate-item (keymap event)
  "Install a dynamic key label on KEYMAP's menu item EVENT."
  (let (binding)
    (map-keymap (lambda (candidate-event candidate-binding)
                  (when (equal candidate-event event)
                    (setq binding candidate-binding)))
                keymap)
    (when (and (consp binding)
               (eq (car binding) 'menu-item)
               (commandp (nth 2 binding)))
      (let* ((copy (copy-tree binding))
             (command (nth 2 copy))
             (properties (nthcdr 3 copy)))
        (setcdr (nthcdr 2 copy)
                (plist-put properties :keys
                           (let ((command command))
                             (lambda ()
                               (glassmacs-menu-effective-key-description
                                command)))))
        (define-key keymap (vector event) copy)))))

(defun glassmacs-menu--raw-binding (keymap event)
  "Return the raw KEYMAP binding for EVENT, retaining menu-item properties."
  (let (binding)
    (map-keymap (lambda (candidate-event candidate-binding)
                  (when (equal candidate-event event)
                    (setq binding candidate-binding)))
                keymap)
    binding))

(defun glassmacs-menu-install-dynamic-keys (keymap &optional events)
  "Install active-keymap labels on Glassmacs-owned items in KEYMAP.
If EVENTS is non-nil, update only those direct entries in a shared menu
such as the upstream File menu.  Otherwise recurse through KEYMAP, which
must be owned by Glassmacs.  Upstream and Cocoa-owned menus are never
walked implicitly."
  (if events
      (dolist (event events)
        (glassmacs-menu--annotate-item keymap event))
    (let (items submenus)
      (map-keymap
       (lambda (event binding)
         (cond
          ((keymapp binding)
           (push binding submenus))
          ((and (consp binding) (eq (car binding) 'menu-item))
           (push event items))))
       keymap)
      (dolist (event items)
        (glassmacs-menu--annotate-item keymap event))
      (dolist (submenu submenus)
        (glassmacs-menu-install-dynamic-keys submenu)))))

(provide 'glassmacs-menu)
;;; glassmacs-menu.el ends here
