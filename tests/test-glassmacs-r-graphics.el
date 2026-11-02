;;; test-glassmacs-r-graphics.el --- Native R graphics ERT tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-r-graphics)

(ert-deftest glassmacs-r-graphics-devices-use-explicit-fallback ()
  (should (equal (glassmacs-r-graphics--device-command 'auto)
                 "if (grDevices::dev.cur() == 1L) grDevices::dev.new()"))
  (should (string-match-p "capabilities('X11')"
                          (glassmacs-r-graphics--device-command 'x11)))
  (let ((system-type 'darwin))
    (should (string-match-p "capabilities('aqua')"
                            (glassmacs-r-graphics--device-command 'quartz))))
  (let ((system-type 'gnu/linux))
    (should-error (glassmacs-r-graphics--device-command 'quartz)
                  :type 'user-error)))

(ert-deftest glassmacs-r-graphics-commands-are-explicit-not-startup-hooks ()
  (should (eq (default-value 'glassmacs-r-graphics-device) 'auto))
  (should-not (memq #'glassmacs-r-graphics-open-device
                    inferior-ess-r-mode-hook)))

(ert-deftest glassmacs-r-graphics-commands-keep-session-identity ()
  (gs-test--with-env
   (let* ((first (glassmacs-sessions-register (gs-test--proc "R-plot-a")))
          (second (glassmacs-sessions-register (gs-test--proc "R-plot-b"))))
     (with-temp-buffer
       (setq-local glassmacs-r-target-session
                   (glassmacs-session-id first))
       (let ((entry (glassmacs-r-graphics-smoke-plot)))
         (should (equal (glassmacs-entry-source entry) "plot(cars)"))
         (should (equal (glassmacs-entry-session-id entry)
                        (glassmacs-session-id first))))
       (should-not (glassmacs-session-entries second))
       (should (eq (glassmacs-session-state second) 'ready))
       (should (equal (glassmacs-entry-session-id
                       (glassmacs-r-graphics-list-devices))
                      (glassmacs-session-id first)))))))

(ert-deftest glassmacs-r-graphics-reject-stale-process-without-retargeting ()
  (gs-test--with-env
   (let* ((old (glassmacs-sessions-register (gs-test--proc "R-plot-old")))
          (old-id (glassmacs-session-id old))
          (live (glassmacs-sessions-register (gs-test--proc "R-plot-live"))))
     (with-temp-buffer
       (setq-local glassmacs-r-target-session old-id)
       (delete-process (glassmacs-session-process old))
       (should-error (glassmacs-r-graphics-close-device)
                     :type 'user-error)
       (should-not (glassmacs-session-entries live))))))

(ert-deftest glassmacs-r-graphics-reject-remote-buffer ()
  (with-temp-buffer
    (setq default-directory "/ssh:remote:/home/user/")
    (cl-letf (((symbol-function 'glassmacs-sessions-resolve)
               (lambda (&rest _) (ert-fail "Remote buffer should not resolve R"))))
      (should-error (glassmacs-r-graphics-smoke-plot) :type 'user-error))))

(ert-deftest glassmacs-r-graphics-reject-unavailable-device-number ()
  (should-error (glassmacs-r-graphics-select-device 0) :type 'user-error)
  (should-error (glassmacs-r-graphics-select-device -1) :type 'user-error)
  (should-error (glassmacs-r-graphics-select-device 1) :type 'user-error))

(ert-deftest glassmacs-r-graphics-source-and-console-menus-share-actions ()
  (require 'glassmacs-r-ui)
  (dolist (menu (list glassmacs-r-ui-source-menu
                      glassmacs-r-ui-console-menu))
    (should (eq (lookup-key menu [graphics-open])
                #'glassmacs-r-graphics-open-device))
    (should (eq (lookup-key menu [graphics-close])
                #'glassmacs-r-graphics-close-device))
    (should (eq (lookup-key menu [graphics-select])
                #'glassmacs-r-graphics-select-device))
    (should (eq (lookup-key menu [graphics-test])
                #'glassmacs-r-graphics-smoke-plot))))

(provide 'test-glassmacs-r-graphics)
;;; test-glassmacs-r-graphics.el ends here
