;;; test-glassmacs-recovery-home.el --- Recovery state isolation -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-core)
(require 'glassmacs-recovery)

(ert-deftest glassmacs-recovery-default-directory-uses-glassmacs-home ()
  "Recovery is based on Glassmacs home, not the global XDG data directory."
  (let* ((home (make-temp-file "glassmacs-home-isolated-" t))
         (external (make-temp-file "glassmacs-xdg-external-" t))
         (glassmacs-home home)
         (process-environment (copy-sequence process-environment)))
    (unwind-protect
        (progn
          (setenv "GLASSMACS_HOME" home)
          (setenv "XDG_DATA_HOME" external)
          (should (equal (glassmacs-recovery--default-directory)
                         (expand-file-name "Recovery/" home)))
          (should-not
           (string-prefix-p (file-name-as-directory external)
                            (glassmacs-recovery--default-directory))))
      (delete-directory home t)
      (delete-directory external t))))

(ert-deftest glassmacs-recovery-isolated-home-does-not-read-external-index ()
  "An isolated recovery directory never sees a different recovery index."
  (let* ((home (make-temp-file "glassmacs-home-isolated-" t))
         (external (make-temp-file "glassmacs-recovery-external-" t))
         (external-index (expand-file-name "crash.eldata" external))
         (glassmacs-home home)
         (glassmacs-recovery-directory
          (glassmacs-recovery--default-directory)))
    (unwind-protect
        (progn
          (with-temp-file external-index
            (insert "(:version 1 :buffers ((:id \"external\")))"))
          (should-not (glassmacs-recovery--read-index "crash.eldata"))
          (glassmacs-recovery--ensure-directory)
          (glassmacs-recovery--write-index-transaction "crash.eldata" nil)
          (should (file-exists-p
                   (expand-file-name "crash.eldata"
                                     glassmacs-recovery-directory)))
          (should (equal
                   (with-temp-buffer
                     (insert-file-contents external-index)
                     (buffer-string))
                   "(:version 1 :buffers ((:id \"external\")))")))
      (delete-directory home t)
      (delete-directory external t))))

(provide 'test-glassmacs-recovery-home)
;;; test-glassmacs-recovery-home.el ends here
