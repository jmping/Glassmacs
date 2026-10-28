;;; test-glassmacs-spelling.el --- Check-only spell checking tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-spelling)
(require 'flyspell)

(ert-deftest glassmacs-spelling-prefers-enchant-then-hunspell-then-aspell ()
  (dolist (case '((("enchant-2" "hunspell" "aspell") . "/bin/enchant-2")
                  (("hunspell" "aspell") . "/bin/hunspell")
                  (("aspell") . "/bin/aspell")
                  (nil . nil)))
    (let ((installed (car case)))
      (cl-letf (((symbol-function 'executable-find)
                 (lambda (program) (and (member program installed)
                                        (concat "/bin/" program)))))
        (should (equal (glassmacs-spelling-program) (cdr case)))))))

(ert-deftest glassmacs-spelling-respects-user-chosen-checker ()
  (let ((ispell-program-name "my-checker"))
    (put 'ispell-program-name 'saved-value '("my-checker"))
    (unwind-protect
        (cl-letf (((symbol-function 'executable-find)
                   (lambda (program) (concat "/bin/" program))))
          (glassmacs-spelling-configure)
          (should (equal ispell-program-name "my-checker")))
      (put 'ispell-program-name 'saved-value nil))))

(ert-deftest glassmacs-spelling-never-corrects-on-its-own ()
  "Flyspell is configured so no key or correction rewrites text by itself."
  (should-not flyspell-use-meta-tab)
  (should-not flyspell-abbrev-p)
  (should-not (lookup-key flyspell-mode-map (kbd "M-TAB")))
  (should-not glassmacs-check-spelling-while-typing))

(ert-deftest glassmacs-spelling-while-typing-is-prose-only-and-opt-in ()
  (let (enabled)
    (cl-letf (((symbol-function 'flyspell-mode)
               (lambda (&optional arg) (push (cons major-mode arg) enabled)))
              ((symbol-function 'glassmacs-spelling-program)
               (lambda () "/bin/hunspell")))
      (with-temp-buffer (text-mode))
      (should-not enabled)
      (let ((glassmacs-check-spelling-while-typing t))
        (with-temp-buffer (text-mode))
        (with-temp-buffer (emacs-lisp-mode))
        (with-temp-buffer (prog-mode)))
      (should (equal enabled '((text-mode . 1)))))))

(ert-deftest glassmacs-spelling-missing-checker-explains-installation ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_program) nil)))
    (let ((glassmacs-check-spelling-while-typing nil))
      (should-error (glassmacs-toggle-spell-checking) :type 'user-error)
      (should-not glassmacs-check-spelling-while-typing))
    (should-error (glassmacs-check-spelling) :type 'user-error)))

(ert-deftest glassmacs-spelling-highlights-but-never-changes-typed-text ()
  "With a real checker, misspellings are marked and the text is untouched."
  (let ((program (glassmacs-spelling-program)))
    (unless program (ert-skip "No spell checker is installed"))
    (let ((ispell-program-name program)
          ;; Checkers pick their dictionary from LANG, which test machines
          ;; may not set; on macOS, Cocoa Emacs and the shell import set it.
          (process-environment (cons "LANG=en_US.UTF-8" process-environment))
          (ispell-dictionary "en_US")
          ;; flyspell waits this long after typing; in batch it really waits.
          (flyspell-delay 0)
          (flyspell-issue-message-flag nil)
          (ispell-local-dictionary nil)
          (input "teh adn \"quoted\" it's -- ..."))
      (unless (ignore-errors (ispell-valid-dictionary-list)
                             (member "en_US" (ispell-valid-dictionary-list)))
        (ert-skip "No en_US dictionary is installed"))
      (save-window-excursion
        (let ((buffer (generate-new-buffer " *glassmacs-spelling-test*")))
          (unwind-protect
              (progn
                (switch-to-buffer buffer)
                (text-mode)
                (flyspell-mode 1)
                (execute-kbd-macro (concat input " "))
                (flyspell-buffer)
                (should (equal (buffer-string) (concat input " ")))
                (should (cl-some #'flyspell-overlay-p (overlays-in 1 4))))
            (kill-buffer buffer)))))))

(provide 'test-glassmacs-spelling)
;;; test-glassmacs-spelling.el ends here
