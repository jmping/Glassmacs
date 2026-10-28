;;; test-glassmacs-editing.el --- Mac editing default tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'comint)
(require 'glassmacs)
;; Defined only in Cocoa builds; declare it so `let' binds it dynamically.
(defvar ns-right-alternate-modifier)

(defmacro glassmacs-editing-test--in-selected-buffer (&rest body)
  "Run BODY in a fresh buffer shown in the selected window.
Keyboard macros type into the selected window's buffer, so the buffer
must be displayed there, not merely current."
  `(save-window-excursion
     (let ((buffer (generate-new-buffer " *glassmacs-editing-test*")))
       (unwind-protect
           (progn
             (switch-to-buffer buffer)
             ,@body)
         (kill-buffer buffer)))))

(defconst glassmacs-editing-test--literal-input
  "\"quoted\" 'single' it's -- --- ... x <- 1 y_z `code` (a) teh adn  two  spaces"
  "Typed text that autocorrect, smart punctuation or smart spacing would alter.")

(defun glassmacs-editing-test--type (mode)
  "Type the literal test input into a fresh MODE buffer and return its text."
  (glassmacs-editing-test--in-selected-buffer
   (funcall mode)
   (execute-kbd-macro glassmacs-editing-test--literal-input)
   (buffer-substring-no-properties (point-min) (point-max))))

(ert-deftest glassmacs-editing-literal-text-entry ()
  "Typed text is inserted literally in prose, markup, code and consoles.
Guards the policy that Glassmacs enables no automatic correction, smart
punctuation, substitution or smart spacing by default."
  (dolist (mode (append '(text-mode fundamental-mode emacs-lisp-mode prog-mode
                                     comint-mode)
                       ;; R source is the key code context when ESS exists.
                       (and (fboundp 'ess-r-mode) '(ess-r-mode))))
    (should (equal (glassmacs-editing-test--type mode)
                   glassmacs-editing-test--literal-input)))
  (should-not (bound-and-true-p electric-quote-mode))
  (should-not (bound-and-true-p abbrev-mode)))

(ert-deftest glassmacs-editing-typing-replaces-selection-literally ()
  (should delete-selection-mode)
  (glassmacs-editing-test--in-selected-buffer
   (transient-mark-mode 1)
   (insert "hello world")
   (set-mark 7)
   (goto-char (point-max))
   (activate-mark)
   (execute-kbd-macro "there...")
   (should (equal (buffer-string) "hello there..."))))

(ert-deftest glassmacs-editing-options-can-be-turned-off ()
  (let ((glassmacs-typing-replaces-selection nil)
        (glassmacs-soft-wrap-text nil)
        (glassmacs-remember-positions nil))
    (unwind-protect
        (progn
          (glassmacs-editing-apply)
          (should-not delete-selection-mode)
          (should-not (memq #'visual-line-mode text-mode-hook))
          (should-not save-place-mode))
      (let ((glassmacs-typing-replaces-selection t)
            (glassmacs-soft-wrap-text t)
            (glassmacs-remember-positions t))
        (glassmacs-editing-apply)))))

(ert-deftest glassmacs-editing-right-option-types-characters-on-macos ()
  (let ((system-type 'darwin)
        (ns-right-alternate-modifier 'left))
    (let ((glassmacs-right-option-types-characters t))
      (glassmacs-editing-apply)
      (should (eq ns-right-alternate-modifier 'none)))
    (let ((glassmacs-right-option-types-characters nil))
      (glassmacs-editing-apply)
      (should (eq ns-right-alternate-modifier 'left)))))

(ert-deftest glassmacs-editing-soft-wrap-is-display-only-and-prose-only ()
  (with-temp-buffer
    (text-mode)
    (should visual-line-mode)
    (insert (make-string 300 ?a))
    (should-not (string-search "\n" (buffer-string))))
  (with-temp-buffer
    (emacs-lisp-mode)
    (should-not visual-line-mode)))

(ert-deftest glassmacs-editing-backups-go-to-home-and-remote-stay-remote ()
  (let ((glassmacs-home (file-name-as-directory
                         (make-temp-file "glassmacs-backup-home-" t)))
        (backup-directory-alist nil)
        (glassmacs-editing--managed-backup-alist nil)
        (glassmacs-keep-backups-in-home t))
    (unwind-protect
        (progn
          (glassmacs-editing-apply)
          (should (string-prefix-p (expand-file-name "backups/" glassmacs-home)
                                   (make-backup-file-name "/tmp/project/analysis.R")))
          ;; The first matching rule for a remote file has no directory,
          ;; which keeps its backup beside the original on the remote host.
          (should (equal (cl-find-if (lambda (entry)
                                       (string-match-p (car entry)
                                                       "/ssh:server:/home/me/a.R"))
                                     backup-directory-alist)
                         (cons glassmacs-editing--remote-file-regexp nil)))
          ;; Turning the option off removes only Glassmacs's own setting.
          (let ((glassmacs-keep-backups-in-home nil))
            (glassmacs-editing-apply))
          (should-not backup-directory-alist))
      (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-editing-user-backup-directory-is-respected ()
  (let ((backup-directory-alist '(("." . "/my/backups")))
        (glassmacs-editing--managed-backup-alist nil)
        (glassmacs-keep-backups-in-home t))
    (glassmacs-editing-apply)
    (should (equal backup-directory-alist '(("." . "/my/backups"))))))

(ert-deftest glassmacs-editing-command-delete-kills-to-line-start ()
  (with-temp-buffer
    (insert "first\nkeep this tail")
    (goto-char (- (point-max) 4))
    (glassmacs-kill-to-line-start)
    (should (equal (buffer-string) "first\ntail"))))

(ert-deftest glassmacs-editing-command-navigation-bindings ()
  (dolist (entry '(([s-up] . beginning-of-buffer)
                   ([s-down] . end-of-buffer)
                   ([s-backspace] . glassmacs-kill-to-line-start)
                   ([?\s-G] . isearch-repeat-backward)))
    (should (eq (alist-get (car entry) glassmacs-hybrid-keybindings nil nil #'equal)
                (cdr entry)))))

(ert-deftest glassmacs-editing-markdown-typing-is-literal ()
  "R Markdown prose and GitHub-flavored Markdown insert exactly what is typed."
  (unless (locate-library "markdown-mode")
    (ert-skip "markdown-mode is not installed"))
  (require 'markdown-mode)
  (should-not markdown-gfm-use-electric-backquote)
  (let ((input "```{r}\nx <- \"a\" -- 'b' ...\n```\n*em* `code` teh"))
    (dolist (mode '(markdown-mode gfm-mode))
      (glassmacs-editing-test--in-selected-buffer
       (funcall mode)
       (execute-kbd-macro input)
       (should (equal (buffer-substring-no-properties (point-min) (point-max))
                      input))))))

(provide 'test-glassmacs-editing)
;;; test-glassmacs-editing.el ends here
