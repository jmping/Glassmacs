;;; test-glassmacs.el --- Glassmacs ERT tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (expand-file-name "../lisp"
                               (file-name-directory (or load-file-name buffer-file-name))))
(require 'glassmacs)

(ert-deftest glassmacs-configuration-loads ()
  (should (featurep 'glassmacs))
  (should (featurep 'glassmacs-core))
  (should (featurep 'glassmacs-r)))

(ert-deftest glassmacs-hybrid-bindings-are-defined ()
  (dolist (binding glassmacs-hybrid-keybindings)
    (should (commandp (cdr binding))))
  (should (eq (cdr (assoc [super-o] glassmacs-hybrid-keybindings)) 'find-file))
  (should (eq (cdr (assoc [super-S] glassmacs-hybrid-keybindings)) 'write-file)))

(ert-deftest glassmacs-does-not-rebind-emacs-prefix-keys ()
  (should (eq (lookup-key global-map (kbd "C-x")) 'Control-X-prefix))
  (should (eq (lookup-key global-map (kbd "C-c")) 'mode-specific-command-prefix))
  (should (eq (lookup-key global-map (kbd "M-x")) 'execute-extended-command)))

(ert-deftest glassmacs-installs-bindings-only-in-macos-graphical-frames ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (glassmacs--install-hybrid-bindings))
    (should (eq (lookup-key global-map [super-o]) 'find-file)))
  (let ((global-map (copy-keymap global-map))
        (system-type 'gnu/linux))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (glassmacs--install-hybrid-bindings))
    (should-not (lookup-key global-map [super-o])))
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) nil)))
      (glassmacs--install-hybrid-bindings))
    (should-not (lookup-key global-map [super-o]))))

(ert-deftest glassmacs-hybrid-profile-can-be-disabled ()
  (let ((global-map (copy-keymap global-map))
        (system-type 'darwin)
        (glassmacs-keyboard-profile nil))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t)))
      (glassmacs--install-hybrid-bindings))
    (should-not (lookup-key global-map [super-o]))))

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
