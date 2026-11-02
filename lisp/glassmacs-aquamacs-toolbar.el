;;; glassmacs-aquamacs-toolbar.el --- Aquamacs toolbar parity map -*- lexical-binding: t; -*-

;; Layout and icon identifiers adapted from Aquamacs' aquamacs-tool-bar.el.
;; Copyright (C) 2005, 2006, 2007, 2009, 2010, 2013 David Reitter.
;; Original: aquamacs/src/site-lisp/aquamacs-tool-bar.el (aquamacs3).
;; SPDX-License-Identifier: GPL-3.0-or-later
;;
;; The original bitmap artwork is NOT included here pending the asset-by-asset
;; provenance review in issue #57.  Existing GNU Emacs icons are the fallback.

(require 'tool-bar)

(defgroup glassmacs-aquamacs-toolbar nil
  "Aquamacs-style Glassmacs toolbar."
  :group 'glassmacs)

(defcustom glassmacs-aquamacs-toolbar-enabled nil
  "Whether to install the Aquamacs-style general toolbar.
Disabled until icon and GUI integration are validated."
  :type 'boolean
  :group 'glassmacs-aquamacs-toolbar)

(defconst glassmacs-aquamacs-toolbar-items
  '((new "New" glassmacs-new-document "new")
    (open "Open" find-file "open")
    (save "Save" save-buffer "save")
    (print "Print" print-buffer "print")
    (undo "Undo" undo "undo")
    (cut "Cut" kill-region "cut")
    (copy "Copy" kill-ring-save "copy")
    (paste "Paste" yank "paste")
    (search "Search" isearch-forward "search")
    (spelling "Spelling" ispell-buffer "spellcheck")
    (duplicate "Duplicate" make-frame-command "new_window")
    (preferences "Preferences" customize "preferences")
    (help "Help" help-command "help"))
  "Aquamacs 3 general toolbar order, labels, commands and image stems.
These are Glassmacs/GNU Emacs command bindings, not upstream Aquamacs
functions.  Recent, Close, Revert, Redo, Save As and separators need
additional contextual mapping before this becomes the default.")

(defun glassmacs-aquamacs-toolbar-map ()
  "Build a general toolbar with Aquamacs button order and fallback icons."
  (let ((map (make-sparse-keymap)))
    (dolist (item glassmacs-aquamacs-toolbar-items)
      (pcase-let ((`(,key ,label ,command ,icon) item))
        (when (fboundp command)
          (define-key-after
            map (vector key)
            `(menu-item ,label ,command
                         :image (find-image
                                 (list (list :type 'png
                                             :file ,(concat icon ".png")
                                             :ascent 'center)))
                         :help ,label)))))
    map))

(defun glassmacs-aquamacs-toolbar-install ()
  "Install the general Aquamacs-style toolbar for the current buffer."
  (interactive)
  (setq-local tool-bar-map (glassmacs-aquamacs-toolbar-map)))

(provide 'glassmacs-aquamacs-toolbar)
;;; glassmacs-aquamacs-toolbar.el ends here
