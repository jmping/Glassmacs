;;; test-glassmacs-workspace.el --- Workspace restore tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'comint)
(require 'glassmacs-workspace)

(defmacro glassmacs-workspace-test--with-home (&rest body)
  "Run BODY with a temporary Glassmacs home and desktop state restored after."
  `(let* ((glassmacs-home (file-name-as-directory
                           (make-temp-file "glassmacs-workspace-" t)))
          (desktop-dirname nil)
          (desktop-path nil)
          (desktop-base-file-name desktop-base-file-name)
          (desktop-base-lock-name desktop-base-lock-name)
          (desktop-save desktop-save)
          (desktop-load-locked-desktop desktop-load-locked-desktop)
          (desktop-restore-frames desktop-restore-frames)
          (frameset-filter-alist (copy-tree frameset-filter-alist))
          (glassmacs-workspace--restored nil))
     (unwind-protect (progn ,@body)
       (when (bound-and-true-p desktop-save-mode)
         (desktop-save-mode -1))
       (delete-directory glassmacs-home t))))

(ert-deftest glassmacs-workspace-is-opt-in ()
  (glassmacs-workspace-test--with-home
   (let ((glassmacs-restore-workspace nil)
         (noninteractive nil))
     (cl-letf (((symbol-function 'desktop-read)
                (lambda (&rest _) (ert-fail "must not restore when disabled"))))
       (glassmacs-workspace-restore-at-startup))
     (should-not (bound-and-true-p desktop-save-mode)))))

(ert-deftest glassmacs-workspace-restores-once-from-glassmacs-home ()
  (glassmacs-workspace-test--with-home
   (let ((glassmacs-restore-workspace t)
         (noninteractive nil)
         reads)
     (cl-letf (((symbol-function 'desktop-read)
                (lambda (&optional directory &rest _) (push directory reads))))
       (glassmacs-workspace-restore-at-startup)
       (glassmacs-workspace-restore-at-startup))
     (should (equal reads (list glassmacs-home)))
     (should desktop-save-mode)
     (should (equal desktop-base-file-name "workspace.desktop"))
     (should (eq desktop-load-locked-desktop 'check-pid))
     ;; Restored windows are always visible, even if hidden at quit.
     (should (equal (assq 'visibility frameset-filter-alist)
                    '(visibility . :never))))))

(ert-deftest glassmacs-workspace-is-never-read-in-batch ()
  (glassmacs-workspace-test--with-home
   (let ((glassmacs-restore-workspace t))
     (cl-letf (((symbol-function 'desktop-read)
                (lambda (&rest _) (ert-fail "must not restore in batch"))))
       (glassmacs-workspace-restore-at-startup)))))

(ert-deftest glassmacs-workspace-round-trip-reopens-local-files-only ()
  (glassmacs-workspace-test--with-home
   (let* ((file (expand-file-name "analysis.R" glassmacs-home))
          (console (generate-new-buffer "*glassmacs-workspace-console*"))
          (glassmacs-restore-workspace t))
     (write-region "x <- 1\n" nil file)
     (glassmacs-workspace--configure)
     ;; Frames are not meaningful in batch; the file list is what matters.
     (setq desktop-restore-frames nil)
     (with-current-buffer console (comint-mode))
     (let ((buffer (find-file-noselect file)))
       (with-current-buffer buffer (goto-char (point-max)))
       ;; RELEASE t releases the lock, as quitting Glassmacs does.
       (desktop-save glassmacs-home t)
       (kill-buffer buffer))
     (kill-buffer console)
     (should (file-exists-p (expand-file-name "workspace.desktop" glassmacs-home)))
     ;; `desktop-read' is a no-op in batch sessions.
     (let ((noninteractive nil))
       (desktop-read glassmacs-home))
     (let ((restored (get-file-buffer file)))
       (unwind-protect
           (progn
             (should restored)
             (should-not (get-buffer "*glassmacs-workspace-console*")))
         (when restored (kill-buffer restored))))
     (desktop-release-lock glassmacs-home))))

(ert-deftest glassmacs-workspace-is-not-read-again-by-its-own-session ()
  "A workspace this session already holds is not loaded a second time."
  (glassmacs-workspace-test--with-home
   (let ((file (expand-file-name "notes.txt" glassmacs-home)))
     (write-region "notes\n" nil file)
     (glassmacs-workspace--configure)
     (setq desktop-restore-frames nil)
     (let ((buffer (find-file-noselect file)))
       (desktop-save glassmacs-home)      ; keeps the lock, like a running session
       (kill-buffer buffer))
     (let ((noninteractive nil))
       (desktop-read glassmacs-home))
     (should-not (get-file-buffer file))
     (desktop-release-lock glassmacs-home))))

(ert-deftest glassmacs-workspace-never-saves-remote-files ()
  (should (string-match-p desktop-files-not-to-save "/ssh:server:/home/me/a.R"))
  (should-not (string-match-p desktop-files-not-to-save "/Users/me/a.R")))

(provide 'test-glassmacs-workspace)
;;; test-glassmacs-workspace.el ends here
