;;; test-glassmacs-close.el --- Close-document tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs)

(defmacro glassmacs-close-test--with-split (buffer &rest body)
  "Show BUFFER in a new window beside the current one and run BODY there.
The extra window means closing deletes a window rather than the frame."
  (declare (indent 1))
  `(save-window-excursion
     (delete-other-windows)
     (let ((window (split-window)))
       (set-window-buffer window ,buffer)
       (select-window window)
       ,@body)))

(defmacro glassmacs-close-test--answering (answer &rest body)
  "Run BODY with `read-multiple-choice' answering ANSWER, counting prompts."
  (declare (indent 1))
  `(let ((prompts 0))
     (cl-letf (((symbol-function 'read-multiple-choice)
                (lambda (&rest _) (cl-incf prompts) (list ,answer))))
       ,@body)))

(ert-deftest glassmacs-close-unmodified-document-kills-buffer-and-window ()
  (let ((buffer (generate-new-buffer "glassmacs-close-clean")))
    (glassmacs-close-test--with-split buffer
      (glassmacs-close-test--answering ?c
        (glassmacs-close-document)
        (should (= prompts 0))
        (should-not (buffer-live-p buffer))
        (should-not (window-live-p window))))))

(ert-deftest glassmacs-close-cancel-keeps-modified-document-open ()
  (let ((buffer (generate-new-buffer "glassmacs-close-cancel")))
    (unwind-protect
        (glassmacs-close-test--with-split buffer
          (with-current-buffer buffer (insert "unsaved"))
          (glassmacs-close-test--answering ?c
            (glassmacs-close-document)
            (should (= prompts 1))
            (should (buffer-live-p buffer))
            (should (buffer-modified-p buffer))
            (should (window-live-p window))))
      (with-current-buffer buffer (set-buffer-modified-p nil))
      (kill-buffer buffer))))

(ert-deftest glassmacs-close-dont-save-discards-without-writing ()
  (let* ((file (make-temp-file "glassmacs-close-" nil ".txt" "original"))
         (buffer (find-file-noselect file)))
    (unwind-protect
        (glassmacs-close-test--with-split buffer
          (with-current-buffer buffer (insert "edit "))
          (glassmacs-close-test--answering ?d
            (glassmacs-close-document)
            (should-not (buffer-live-p buffer))
            (should (equal (with-temp-buffer
                             (insert-file-contents file)
                             (buffer-string))
                           "original"))))
      (delete-file file))))

(ert-deftest glassmacs-close-save-writes-then-closes ()
  (let* ((file (make-temp-file "glassmacs-close-" nil ".txt" "original"))
         (buffer (find-file-noselect file)))
    (unwind-protect
        (glassmacs-close-test--with-split buffer
          (with-current-buffer buffer
            (goto-char (point-max))
            (insert " saved"))
          (glassmacs-close-test--answering ?s
            (glassmacs-close-document)
            (should-not (buffer-live-p buffer))
            ;; `require-final-newline' may append a newline on save.
            (should (string-prefix-p "original saved"
                                     (with-temp-buffer
                                       (insert-file-contents file)
                                       (buffer-string))))))
      (delete-file file))))

(ert-deftest glassmacs-close-keeps-document-shown-in-another-window ()
  (let ((buffer (generate-new-buffer "glassmacs-close-shared")))
    (unwind-protect
        (glassmacs-close-test--with-split buffer
          (with-current-buffer buffer (insert "unsaved"))
          (set-window-buffer (next-window window) buffer)
          (glassmacs-close-test--answering ?d
            (glassmacs-close-document)
            (should (= prompts 0))
            (should (buffer-live-p buffer))
            (should (buffer-modified-p buffer))
            (should-not (window-live-p window))))
      (with-current-buffer buffer (set-buffer-modified-p nil))
      (kill-buffer buffer))))

(ert-deftest glassmacs-close-never-kills-console-or-special-buffers ()
  (let ((console (generate-new-buffer "*glassmacs-close-console*")))
    (unwind-protect
        (progn
          (with-current-buffer console (comint-mode) (insert "> x <- 1"))
          (glassmacs-close-test--with-split console
            (glassmacs-close-test--answering ?d
              (glassmacs-close-document)
              (should (= prompts 0))
              (should (buffer-live-p console))
              (should-not (window-live-p window)))))
      (kill-buffer console))))

(ert-deftest glassmacs-close-last-window-closes-frame-or-tab ()
  (let ((buffer (generate-new-buffer "glassmacs-close-frame"))
        deleted closed-tab)
    (save-window-excursion
      (delete-other-windows)
      (set-window-buffer (selected-window) buffer)
      (cl-letf (((symbol-function 'delete-frame)
                 (lambda (&optional frame _force) (setq deleted frame)))
                ((symbol-function 'tab-bar-close-tab)
                 (lambda (&rest _) (setq closed-tab t))))
        (let ((tab-bar-mode nil))
          (glassmacs-close-document))
        (should (eq deleted (selected-frame)))
        (should-not closed-tab)
        (setq deleted nil)
        (set-window-buffer (selected-window) (get-buffer-create "*scratch*"))
        (let ((tab-bar-mode t)
              (tab-bar-tabs-function (lambda (&optional _) '(tab-a tab-b))))
          (glassmacs-close-document))
        (should closed-tab)
        (should-not deleted)))
    (should-not (buffer-live-p buffer))))

(ert-deftest glassmacs-close-button-cancel-keeps-frame-open ()
  (let ((buffer (generate-new-buffer "glassmacs-close-button"))
        original-called hidden)
    (unwind-protect
        (save-window-excursion
          (delete-other-windows)
          (set-window-buffer (selected-window) buffer)
          (with-current-buffer buffer (insert "unsaved"))
          (cl-letf (((symbol-function 'event-start) (lambda (event) event))
                    ((symbol-function 'posn-window) (lambda (event) event))
                    ((symbol-function 'make-frame-invisible)
                     (lambda (frame &rest _) (setq hidden frame))))
            (glassmacs-close-test--answering ?c
              (should-not (glassmacs--handle-delete-frame-preserving-app
                           (lambda (_event) (setq original-called t))
                           (selected-frame)))
              (should (= prompts 1))))
          (should-not original-called)
          (should-not hidden)
          (should (buffer-live-p buffer)))
      (with-current-buffer buffer (set-buffer-modified-p nil))
      (kill-buffer buffer))))

(ert-deftest glassmacs-close-command-w-binding-closes-documents ()
  (should (eq (alist-get [?\s-w] glassmacs-hybrid-keybindings nil nil #'equal)
              'glassmacs-close-document))
  (should (memq 'glassmacs-close-document
                glassmacs--commands-that-stay-windowless)))

(ert-deftest glassmacs-close-scratch-modified-prompts-and-cancel-keeps-it ()
  (let ((scratch (get-buffer-create "*scratch*")))
    (unwind-protect
        (glassmacs-close-test--with-split scratch
          (with-current-buffer scratch
            (goto-char (point-max))
            (insert "scratch unsaved edit"))
          (glassmacs-close-test--answering ?c
            (glassmacs-close-document)
            (should (= prompts 1))
            (should (buffer-live-p scratch))
            (should (buffer-modified-p scratch))
            (should (window-live-p window))))
      (when (buffer-live-p scratch)
        (with-current-buffer scratch
          (erase-buffer)
          (set-buffer-modified-p nil))))))

(ert-deftest glassmacs-unsaved-review-includes-modified-scratch ()
  (let ((scratch (get-buffer-create "*scratch*")))
    (unwind-protect
        (progn
          (with-current-buffer scratch
            (goto-char (point-max))
            (insert "review scratch edit"))
          (should (memq scratch (glassmacs--modified-document-buffers))))
      (with-current-buffer scratch
        (erase-buffer)
        (set-buffer-modified-p nil)))))

(ert-deftest glassmacs-mode-menu-has-selectable-commands ()
  (let ((text-command (lookup-key glassmacs-new-buffer-mode-menu
                                  [text-mode])))
    ;; Emacs lookup-key resolves a menu-item to its executable command.
    (should (commandp text-command))
    (should (equal (cadr (assq 'text-mode
                               (cdr glassmacs-new-buffer-mode-menu)))
                   "Text"))))

(provide 'test-glassmacs-close)
;;; test-glassmacs-close.el ends here
