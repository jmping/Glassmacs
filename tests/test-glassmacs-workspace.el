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

;;; Interaction with recovery (glassmacs-recovery.el)
;;
;; Required startup order: preferences, then workspace restore, then the
;; offer to recover unsaved content.  Recovery never overwrites a buffer:
;; unsaved edits come back in a separate untitled "(Recovered)" buffer, and
;; preserved clean files reuse the buffer the workspace already opened.

(require 'glassmacs-recovery)

(ert-deftest glassmacs-workspace-restores-before-recovery-is-offered ()
  "Workspace restore runs while Glassmacs loads; recovery waits for startup."
  ;; Recovery is offered from `emacs-startup-hook', which Emacs runs after
  ;; command-line loading (where glassmacs.el, and so the workspace
  ;; restore, runs) has finished.
  (should (memq #'glassmacs-recovery--startup emacs-startup-hook))
  (should-not (memq #'glassmacs-workspace-restore-at-startup emacs-startup-hook))
  (let ((source (with-temp-buffer
                  (insert-file-contents (locate-library "glassmacs.el"))
                  (buffer-string))))
    ;; Preferences (custom.el) load before the workspace is restored.
    (should (< (string-search "(load custom-file" source)
               (string-search "(glassmacs-workspace-restore-at-startup)" source)))))

(defun glassmacs-workspace-test--buffers-visiting (file)
  "Return the live buffers visiting FILE."
  (cl-remove-if-not (lambda (buffer)
                      (equal (buffer-local-value 'buffer-file-name buffer)
                             (expand-file-name file)))
                    (buffer-list)))

(defun glassmacs-workspace-test--recovered-copies (file)
  "Return the recovered untitled buffers holding unsaved edits of FILE."
  ;; The variable exists only buffer-locally, in recovered buffers.
  (cl-remove-if-not (lambda (buffer)
                      (and (local-variable-p 'glassmacs-recovery-source-file buffer)
                           (equal (buffer-local-value 'glassmacs-recovery-source-file
                                                      buffer)
                                  file)))
                    (buffer-list)))

(ert-deftest glassmacs-workspace-and-recovery-after-abnormal-shutdown ()
  "Restoring the workspace and then recovery yields no duplicate or stale view.
The workspace reopens the saved file; recovery adds the unsaved edits as a
separate untitled buffer and never overwrites the file or its buffer."
  (glassmacs-workspace-test--with-home
   (let* ((glassmacs-recovery-directory
           (file-name-as-directory (make-temp-file "glassmacs-recovery-" t)))
          (file (expand-file-name "analysis.R" glassmacs-home))
          (glassmacs-restore-workspace t))
     (unwind-protect
         (progn
           (write-region "saved\n" nil file)
           (glassmacs-workspace--configure)
           (setq desktop-restore-frames nil)
           (let ((buffer (find-file-noselect file)))
             (desktop-save glassmacs-home t)
             ;; Unsaved edits are snapshotted, then the session ends abruptly.
             (with-current-buffer buffer
               (goto-char (point-max))
               (insert "unsaved edit\n"))
             (glassmacs-recovery-preserve)
             (with-current-buffer buffer (set-buffer-modified-p nil))
             (kill-buffer buffer))
           ;; Next start, in Glassmacs's order: workspace, then recovery.
           (let ((noninteractive nil))
             (desktop-read glassmacs-home))
           (glassmacs-recovery-restore)
           (glassmacs-recovery-restore)   ; offered again: still no duplicates
           (let ((views (glassmacs-workspace-test--buffers-visiting file))
                 (copies (glassmacs-workspace-test--recovered-copies file)))
             (should (= (length views) 1))
             (with-current-buffer (car views)
               (should (equal (buffer-string) "saved\n"))
               (should-not (buffer-modified-p)))
             (should (= (length copies) 1))
             (with-current-buffer (car copies)
               (should (equal (buffer-string) "saved\nunsaved edit\n"))
               (should-not buffer-file-name)))
           ;; The file on disk is never overwritten by recovery.
           (should (equal (with-temp-buffer
                            (insert-file-contents file)
                            (buffer-string))
                          "saved\n")))
       (dolist (buffer (append (glassmacs-workspace-test--buffers-visiting file)
                               (glassmacs-workspace-test--recovered-copies file)))
         (with-current-buffer buffer (set-buffer-modified-p nil))
         (kill-buffer buffer))
       (desktop-release-lock glassmacs-home)
       (delete-directory glassmacs-recovery-directory t)))))

(ert-deftest glassmacs-workspace-and-recovery-share-a-clean-file-buffer ()
  "A preserved clean file that the workspace already reopened is not duplicated."
  (glassmacs-workspace-test--with-home
   (let* ((glassmacs-recovery-directory
           (file-name-as-directory (make-temp-file "glassmacs-recovery-" t)))
          (file (expand-file-name "notes.txt" glassmacs-home))
          (glassmacs-restore-workspace t))
     (unwind-protect
         (progn
           (write-region "notes\n" nil file)
           (glassmacs-workspace--configure)
           (setq desktop-restore-frames nil)
           (let ((buffer (find-file-noselect file)))
             (desktop-save glassmacs-home t)
             (glassmacs-recovery-preserve)
             (kill-buffer buffer))
           (let ((noninteractive nil))
             (desktop-read glassmacs-home))
           (glassmacs-recovery-restore)
           (should (= (length (glassmacs-workspace-test--buffers-visiting file)) 1))
           (should-not (glassmacs-workspace-test--recovered-copies file)))
       (dolist (buffer (glassmacs-workspace-test--buffers-visiting file))
         (kill-buffer buffer))
       (desktop-release-lock glassmacs-home)
       (delete-directory glassmacs-recovery-directory t)))))

(provide 'test-glassmacs-workspace)
;;; test-glassmacs-workspace.el ends here
