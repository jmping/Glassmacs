;;; glassmacs-aquamacs-toolbar.el --- Aquamacs-style document toolbar -*- lexical-binding: t; -*-

;; Original layout and command ordering:
;;   Aquamacs aquamacs/src/site-lisp/aquamacs-tool-bar.el (branch aquamacs3)
;;   Copyright (C) 2005, 2006, 2007, 2009, 2010, 2013 David Reitter.
;;   SPDX-License-Identifier: GPL-3.0-or-later
;;
;; Original AQUAMACS IMAGES ARE NOT INCLUDED.  Its Icons/build/COPYING grants
;; many original icons only to the Aquamacs project; see Glassmacs issue #57.
;; The toolbar uses GNU Emacs' built-in icons instead.

(require 'cl-lib)
(require 'tool-bar)
(require 'glassmacs-frames)

(defgroup glassmacs-aquamacs-toolbar nil
  "Aquamacs-style document toolbar controls."
  :group 'glassmacs)

(defcustom glassmacs-aquamacs-toolbar-enabled t
  "Whether to enable Aquamacs-style document controls in graphical frames.
The visuals use Emacs' built-in icon assets until original Aquamacs artwork
can be licensed separately.  R buffers retain their contextual R toolbar."
  :type 'boolean
  :group 'glassmacs-aquamacs-toolbar)

(defconst glassmacs-aquamacs-toolbar-items
  '((new "New" glassmacs-new-document "new")
    (open "Open" glassmacs-open-document-from-toolbar "open")
    (recent "Recent" glassmacs-toolbar-open-recent "open")
    (close "Close" glassmacs-close-document "close")
    (revert "Revert" revert-buffer "refresh")
    (save "Save" save-buffer "save")
    (save-as "Save" glassmacs-save-document-as-prompt "save")
    (print "Print" glassmacs-toolbar-print "print")
    (separator-1)
    (undo "Undo" undo "undo")
    (redo "Redo" glassmacs-toolbar-redo "redo")
    (cut "Cut" kill-region "cut")
    (copy "Copy" kill-ring-save "copy")
    (paste "Paste" yank "paste")
    (search "Search" isearch-forward "search")
    (spelling "Spelling" ispell-buffer "spellcheck")
    (separator-2)
    (duplicate "Duplicate" make-frame-command "new-window")
    (preferences "Preferences" customize "preferences")
    (help "Help" glassmacs-toolbar-help "help"))
  "General toolbar entries in the original Aquamacs order.
Each nonseparator item is (KEY LABEL COMMAND GNU-EMACS-ICON-STEM).")

(defun glassmacs-open-document-from-toolbar ()
  "Open a document using Glassmacs' ordinary window-opening policy."
  (interactive)
  (call-interactively #'glassmacs-open-file))

(defun glassmacs-save-document-as-prompt ()
  "Prompt for a destination and save the current document."
  (interactive)
  (call-interactively #'glassmacs-save-document-as))

(defun glassmacs-toolbar-open-recent ()
  "Display the recent-file selector using standard Emacs facilities."
  (interactive)
  (if (and (fboundp 'recentf-open-files)
           (bound-and-true-p recentf-mode))
      (recentf-open-files)
    (call-interactively #'find-file)))

(defun glassmacs-toolbar-print ()
  "Print the current document using Emacs' existing print command."
  (interactive)
  (call-interactively #'print-buffer))

(defun glassmacs-toolbar-redo ()
  "Redo one change, when Emacs provides the redo command."
  (interactive)
  (if (fboundp 'undo-redo)
      (call-interactively #'undo-redo)
    (user-error "Redo is not available")))

(defun glassmacs-toolbar-help ()
  "Open Emacs' help entry point."
  (interactive)
  (call-interactively #'help-for-help))

(defun glassmacs-aquamacs-toolbar--image (stem)
  "Find GNU Emacs-provided toolbar art corresponding to STEM.
The built-in image search path is sufficient; no Aquamacs artwork is
redistributed.  A missing icon leaves the toolbar command available."
  (when (display-graphic-p)
    (let ((candidates (delete-dups
                       (list (concat stem ".xpm") (concat stem ".png")
                             (concat stem ".svg")))))
      (cl-loop for file in candidates
               thereis (find-image
                        (list (list :file file :ascent 'center)))))))

(defun glassmacs-aquamacs-toolbar--visible (key)
  "Return the contextual visibility rule for toolbar KEY."
  (pcase key
    ('recent '(bound-and-true-p recentf-mode))
    ('save '(and buffer-file-name (not (eq 'special (get major-mode 'mode-class)))))
    ('save-as '(and (not buffer-file-name)
                    (not (eq 'special (get major-mode 'mode-class)))))
    ('close '(not (minibufferp)))
    (_ t)))

(defun glassmacs-aquamacs-toolbar--enabled (key)
  "Return the contextual enabled rule for toolbar KEY."
  (pcase key
    ('save '(buffer-modified-p))
    ('cut '(use-region-p))
    ('copy '(use-region-p))
    ('undo '(not buffer-read-only))
    ('redo '(and (not buffer-read-only) (fboundp 'undo-redo)))
    (_ t)))

(defun glassmacs-aquamacs-toolbar-map ()
  "Build an Aquamacs-ordered toolbar with GNU Emacs-provided icons.
No original Aquamacs PNG/TIFF artwork is needed or loaded."
  (let ((map (make-sparse-keymap)))
    (dolist (item glassmacs-aquamacs-toolbar-items)
      (pcase item
        (`(,key)
         (define-key-after map (vector key) menu-bar-separator))
        (`(,key ,label ,command ,stem)
         (define-key-after
           map (vector key)
           `(menu-item ,label ,command
                       :image (glassmacs-aquamacs-toolbar--image ,stem)
                       :visible ,(glassmacs-aquamacs-toolbar--visible key)
                       :enable ,(glassmacs-aquamacs-toolbar--enabled key)
                       :help ,label)))))
    map))

(defun glassmacs-aquamacs-toolbar-install ()
  "Install the Aquamacs-style general toolbar as the current default."
  (when (and glassmacs-aquamacs-toolbar-enabled
             (display-graphic-p))
    ;; R source and console buffers use a separate buffer-local toolbar.
    (setq-default tool-bar-map (glassmacs-aquamacs-toolbar-map))
    (tool-bar-mode 1)))

(provide 'glassmacs-aquamacs-toolbar)
;;; glassmacs-aquamacs-toolbar.el ends here
