;;; test-glassmacs-menu.el --- Tests for dynamic menu key labels -*- lexical-binding: t; -*-

(require 'glassmacs-menu)

(defun glassmacs-menu-test-command ()
  "Command used by dynamic menu key-label tests."
  (interactive))

(define-derived-mode glassmacs-menu-test-mode prog-mode "Glassmacs Menu Test"
  "Mode map used to verify context-specific menu shortcuts.")

(ert-deftest glassmacs-menu-keys-follow-active-profile-and-mode-map ()
  (let ((hybrid-map (make-sparse-keymap))
        (traditional-map (make-sparse-keymap))
        (original-global-map (current-global-map)))
    (define-key hybrid-map (kbd "s-o") #'glassmacs-menu-test-command)
    (define-key traditional-map (kbd "C-x C-o") #'glassmacs-menu-test-command)
    (unwind-protect
        (with-temp-buffer
          (glassmacs-menu-test-mode)
          (use-global-map hybrid-map)
          (should (equal (glassmacs-menu-effective-key-description
                          #'glassmacs-menu-test-command)
                         "s-o"))
          (use-global-map traditional-map)
          (should (equal (glassmacs-menu-effective-key-description
                          #'glassmacs-menu-test-command)
                         "C-x C-o"))
          (use-global-map hybrid-map)
          (define-key glassmacs-menu-test-mode-map (kbd "C-c C-o")
            #'glassmacs-menu-test-command)
          (should (equal (glassmacs-menu-effective-key-description
                          #'glassmacs-menu-test-command)
                         "C-c C-o"))
          (use-global-map traditional-map)
          (should (equal (glassmacs-menu-effective-key-description
                          #'glassmacs-menu-test-command)
                         "C-c C-o")))
      (use-global-map original-global-map))))

(ert-deftest glassmacs-menu-keys-respect-user-override-and-unbound-state ()
  (let ((user-map (make-sparse-keymap))
        (test-global-map (make-sparse-keymap))
        (original-global-map (current-global-map)))
    (define-key test-global-map (kbd "s-o") #'glassmacs-menu-test-command)
    (with-temp-buffer
      (use-global-map test-global-map)
      (use-local-map user-map)
      (define-key user-map (kbd "C-c o") #'glassmacs-menu-test-command)
      (should (equal (glassmacs-menu-effective-key-description
                      #'glassmacs-menu-test-command)
                     "C-c o"))
      (define-key user-map (kbd "C-c o") nil)
      (define-key test-global-map (kbd "s-o") nil)
      (should (equal (glassmacs-menu-effective-key-description
                      #'glassmacs-menu-test-command)
                     ""))
      (use-global-map original-global-map))))

(ert-deftest glassmacs-menu-keys-refresh-without-touching-upstream-menus ()
  (let ((glassmacs-menu (make-sparse-keymap "Glassmacs"))
        (upstream-menu (make-sparse-keymap "File"))
        (test-global-map (make-sparse-keymap))
        (original-global-map (current-global-map)))
    (define-key glassmacs-menu [open]
      '(menu-item "Open" glassmacs-menu-test-command :keys "stale"))
    (define-key upstream-menu [other]
      '(menu-item "Other" glassmacs-menu-test-command :keys "upstream"))
    (define-key test-global-map (kbd "s-o") #'glassmacs-menu-test-command)
    (with-temp-buffer
      (use-global-map test-global-map)
      (glassmacs-menu-install-dynamic-keys glassmacs-menu)
      (let* ((item (glassmacs-menu--raw-binding glassmacs-menu 'open))
             (keys (plist-get (nthcdr 3 item) :keys)))
        (should (functionp keys))
        (should (equal (funcall keys) "s-o"))
        (define-key test-global-map (kbd "s-o") nil)
        (should (equal (funcall keys) "")))
      (should (equal (plist-get
                      (nthcdr 3 (glassmacs-menu--raw-binding upstream-menu 'other))
                      :keys)
                     "upstream"))
      (use-global-map original-global-map))))

(ert-deftest glassmacs-menu-keeps-ess-mode-bindings-authoritative ()
  (unless (locate-library "ess-r-mode")
    (ert-skip "ESS is not installed"))
  (require 'ess-r-mode)
  (with-temp-buffer
    (ess-r-mode)
    (let ((region-binding (key-binding (kbd "C-c C-r")))
          (menu (make-sparse-keymap "Glassmacs test")))
      (define-key menu [run-region]
        '(menu-item "Run Region" ess-eval-region))
      (glassmacs-menu-install-dynamic-keys menu)
      (should (eq (key-binding (kbd "C-c C-r")) region-binding))
      (let ((expected (car (where-is-internal region-binding
                                             (current-active-maps)))))
        (should expected)
        (should (equal
                 (funcall (plist-get
                           (nthcdr 3 (glassmacs-menu--raw-binding menu 'run-region))
                           :keys)
                 (key-description expected))))))))

(provide 'test-glassmacs-menu)
;;; test-glassmacs-menu.el ends here
