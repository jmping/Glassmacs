;;; test-glassmacs-spelling.el --- Check-only spell checking tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-spelling)
(require 'flyspell)
(require 'glassmacs-sessions)

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

;;; Skipping code and loaded names

(defmacro glassmacs-spelling-test--with-names (names &rest body)
  "Run BODY as if NAMES had been read from the R session."
  (declare (indent 1))
  `(let ((glassmacs-spelling--r-names (make-hash-table :test #'equal)))
     (dolist (name ,names) (puthash name t glassmacs-spelling--r-names))
     ,@body))

(defun glassmacs-spelling-test--skipped (text)
  "Return the words of TEXT that spell checking would skip, in order."
  (with-temp-buffer
    (insert text)
    (let (skipped)
      (goto-char (point-min))
      (while (re-search-forward "[[:alpha:]]+" nil t)
        (when (glassmacs-spelling-skip-word-p (match-beginning 0) (match-end 0))
          (push (match-string 0) skipped)))
      (nreverse skipped))))

(ert-deftest glassmacs-spelling-skips-identifier-shaped-words ()
  (let ((glassmacs-spelling--r-names nil))
    (should (equal (glassmacs-spelling-test--skipped
                    "Use my_data with data.frame, ggplot2 and readRDS. Teh end.")
                   '("my" "data" "data" "frame" "ggplot" "readRDS")))))

(ert-deftest glassmacs-spelling-skips-code-faces ()
  (let ((glassmacs-spelling--r-names nil))
    (with-temp-buffer
      (insert "prose zqx ")
      (insert (propertize "wqz" 'face 'markdown-inline-code-face))
      (insert " ")
      (insert (propertize "xvq" 'face '(bold font-latex-math-face)))
      (should (equal (glassmacs-spelling--skipped-words (point-min) (point-max))
                     '("xvq" "wqz"))))))

(ert-deftest glassmacs-spelling-skips-loaded-r-names ()
  (glassmacs-spelling-test--with-names '("mtcars" "lm" "tidyr")
    (should (equal (glassmacs-spelling-test--skipped "Fit lm on mtcars with tidyr, not teh.")
                   '("lm" "mtcars" "tidyr"))))
  (let ((glassmacs-spelling-skip-r-names nil))
    (glassmacs-spelling-test--with-names '("mtcars")
      (should-not (glassmacs-spelling-test--skipped "mtcars")))))

(ert-deftest glassmacs-spelling-emacs-symbols-are-opt-in ()
  (let ((glassmacs-spelling--r-names nil))
    (should-not (glassmacs-spelling-test--skipped "setq defun"))
    (let ((glassmacs-spelling-skip-emacs-symbols t))
      (should (equal (glassmacs-spelling-test--skipped "setq defun zqxw")
                     '("setq" "defun"))))))

(ert-deftest glassmacs-spelling-chains-after-mode-predicate ()
  (glassmacs-spelling-test--with-names '("mtcars")
    (with-temp-buffer
      (insert "mtcars teh")
      (setq glassmacs-spelling--mode-predicate (lambda () t))
      ;; flyspell-get-word needs a configured dictionary; stub it with the
      ;; alphabetic word before point.
      (cl-letf (((symbol-function 'flyspell-get-word)
                 (lambda (&rest _)
                   (let ((end (point)))
                     (save-excursion
                       (skip-chars-backward "[:alpha:]")
                       (list (buffer-substring (point) end) (point) end))))))
      (goto-char 7)                     ; after "mtcars"
      (should-not (glassmacs-spelling--flyspell-predicate))
      (goto-char (point-max))           ; after "teh"
      (should (glassmacs-spelling--flyspell-predicate))
      ;; The mode's own refusal (for example, Markdown code) still wins.
      (setq glassmacs-spelling--mode-predicate (lambda () nil))
      (should-not (glassmacs-spelling--flyspell-predicate))))))

(ert-deftest glassmacs-spelling-r-names-are-read-only-when-r-is-idle ()
  (let ((process (make-process :name "glassmacs-fake-r" :command '("cat")
                               :connection-type 'pipe :noquery t))
        (glassmacs-spelling--r-names nil)
        asked)
    (unwind-protect
        (cl-letf (((symbol-function 'glassmacs-spelling--r-session)
                   (lambda () (glassmacs-session--make :id "R-test" :process process)))
                  ((symbol-function 'ess-get-words-from-vector)
                   (lambda (&rest _) (setq asked t) '("mtcars" "lm"))))
          (process-put process 'busy t)
          (should-not (glassmacs-spelling-refresh-r-names t))
          (should-not asked)
          (should-not glassmacs-spelling--r-names)
          (process-put process 'busy nil)
          (should (= (glassmacs-spelling-refresh-r-names t) 2))
          (should (gethash "mtcars" glassmacs-spelling--r-names)))
      (delete-process process))))

(ert-deftest glassmacs-spelling-document-check-accepts-skipped-words-for-session-only ()
  (glassmacs-spelling-test--with-names '("mtcars")
    (with-temp-buffer
      (insert "Fit mtcars and my_data; teh end.")
      (let (accepted)
        (cl-letf (((symbol-function 'glassmacs-spelling--require-program) #'ignore)
                  ((symbol-function 'glassmacs-spelling-refresh-r-names) #'ignore)
                  ((symbol-function 'ispell-region)
                   (lambda (&rest _) (setq accepted ispell-buffer-session-localwords))))
          (glassmacs-check-spelling))
        (should (member "mtcars" accepted))
        (should (member "data" accepted))
        (should-not (member "teh" accepted))
        ;; Nothing persists after the check, and the text is unchanged.
        (should-not ispell-buffer-session-localwords)
        (should (equal (buffer-string) "Fit mtcars and my_data; teh end."))))))

(ert-deftest glassmacs-spelling-real-checker-flags-only-prose-misspellings ()
  (let ((program (glassmacs-spelling-program)))
    (unless program (ert-skip "No spell checker is installed"))
    (glassmacs-spelling-test--with-names '("mtcars")
      (let ((ispell-program-name program)
            (process-environment (cons "LANG=en_US.UTF-8" process-environment))
            (ispell-dictionary "en_US")
            (flyspell-issue-message-flag nil)
            (glassmacs-spelling-skip-r-names t))
        (with-temp-buffer
          (insert "Fit mtcars with my_data and ggplot2 but teh model.")
          (text-mode)
          (cl-letf (((symbol-function 'glassmacs-spelling-refresh-r-names) #'ignore))
            (flyspell-mode 1))
          (flyspell-buffer)
          (let ((flagged (mapcar (lambda (o) (buffer-substring (overlay-start o)
                                                               (overlay-end o)))
                                 (cl-remove-if-not #'flyspell-overlay-p
                                                   (overlays-in (point-min) (point-max))))))
            (should (equal flagged '("teh")))))))))

(ert-deftest glassmacs-spelling-reads-names-from-real-r-session ()
  (unless (and (locate-library "ess-site") (executable-find "R"))
    (ert-skip "ESS and R are not installed"))
  (require 'ess-site)
  (require 'glassmacs-sessions)
  (let ((glassmacs-sessions--list nil)
        (glassmacs-sessions--history nil)
        (default-directory temporary-file-directory)
        (ess-ask-for-ess-directory nil)
        (ess-history-file nil)
        (inhibit-message t)
        (glassmacs-spelling--r-names nil)
        buffer)
    (unwind-protect
        (progn
          (save-window-excursion (setq buffer (R)))
          (let* ((session (car (glassmacs-sessions-refresh)))
                 (process (glassmacs-session-process session)))
            ;; ess-command evaluates in a private environment, so assign
            ;; into the workspace explicitly, as code run in the console does.
            (ess-command "assign('glassmacsspellobj', 1, envir = globalenv())\n"
                         nil nil nil nil process)
            (with-temp-buffer
              (should (> (glassmacs-spelling-refresh-r-names t) 100))
              ;; A workspace object and functions from attached packages.
              (should (gethash "glassmacsspellobj" glassmacs-spelling--r-names))
              (should (gethash "lm" glassmacs-spelling--r-names))
              (should (gethash "mtcars" glassmacs-spelling--r-names)))))
      (when (buffer-live-p buffer)
        (let ((kill-buffer-query-functions nil)) (kill-buffer buffer))))))

(provide 'test-glassmacs-spelling)
;;; test-glassmacs-spelling.el ends here
