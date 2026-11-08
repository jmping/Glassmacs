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

(ert-deftest glassmacs-native-quit-helper-returns-alert-decision ()
  (let* ((system-type 'darwin)
         (invocation-directory "/Applications/Glassmacs.app/Contents/MacOS/")
         (buffer (get-buffer-create "glassmacs-native-quit-test"))
         (called-with nil)
         (response-file nil))
    (unwind-protect
        (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                  ((symbol-function 'executable-find)
                   (lambda (program) (and (equal program "open") "/usr/bin/open")))
                  ((symbol-function 'file-executable-p) (lambda (_) t))
                  ((symbol-function 'process-file)
                   (lambda (program _infile _destination _display &rest args)
                     (setq called-with (cons program args)
                           response-file (nth 5 args))
                     (with-temp-file response-file
                       (insert "{\"action\":\"discard\",\"all\":true}"))
                     0)))
          (should (equal (glassmacs-recovery--native-quit-decision buffer)
                         '(discard . t)))
          (should (equal (car called-with) "/usr/bin/open"))
          (should (member "-W" (cdr called-with)))
          (should (equal (nth 3 (cdr called-with))
                         "/Applications/Glassmacs.app/Contents/Helpers/GlassmacsQuitAlert.app"))
          (should-not (file-exists-p response-file)))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest glassmacs-native-quit-helper-reports-helper-error ()
  (let* ((system-type 'darwin)
         (invocation-directory "/Applications/Glassmacs.app/Contents/MacOS/")
         (buffer (get-buffer-create "glassmacs-native-quit-error-test"))
         (reported nil))
    (unwind-protect
        (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                  ((symbol-function 'executable-find)
                   (lambda (program) (and (equal program "open") "/usr/bin/open")))
                  ((symbol-function 'file-executable-p) (lambda (_) t))
                  ((symbol-function 'process-file)
                   (lambda (_program _infile _destination _display &rest args)
                     (with-temp-file (nth 5 args)
                       (insert "{\"error\":\"test launch failure\"}"))
                     0))
                  ((symbol-function 'message)
                   (lambda (format-string &rest args)
                     (setq reported (apply #'format format-string args)))))
          (should-not (glassmacs-recovery--native-quit-decision buffer))
          (should (equal reported
                         "Glassmacs native quit helper failed: test launch failure")))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest glassmacs-native-quit-command-routes-through-review ()
  (let ((routed nil)
        (original-called nil))
    (cl-letf (((symbol-function 'glassmacs-recovery-quit)
               (lambda () (setq routed t))))
      (glassmacs-recovery--reviewed-quit-advice
       (lambda (&rest _) (setq original-called t)))
      (should routed)
      (should-not original-called))))

(ert-deftest glassmacs-reviewed-quit-command-calls-original ()
  (let ((glassmacs-recovery--save-reviewed-quit t)
        (original-called nil))
    (glassmacs-recovery--reviewed-quit-advice
     (lambda (&rest _) (setq original-called t)))
    (should original-called)))

(ert-deftest glassmacs-native-and-emacs-quit-entry-points-are-intercepted ()
  (should (advice-member-p #'glassmacs-recovery--reviewed-quit-advice
                           'save-buffers-kill-emacs))
  (should (advice-member-p #'glassmacs-recovery--reviewed-quit-advice
                           'kill-emacs)))

(ert-deftest glassmacs-close-coordinator-view-cancel-preserves-layout ()
  "A vetoed review never invokes view deletion."
  (let ((deleted nil))
    (cl-letf (((symbol-function 'glassmacs--review-close-windows)
               (lambda (_windows) nil))
              ((symbol-function 'glassmacs--close-view)
               (lambda (_window) (setq deleted t))))
      (should-not (glassmacs--close-reviewed 'view (selected-window)))
      (should-not deleted))))

(ert-deftest glassmacs-close-coordinator-frame-delegates-all-tabs ()
  "The frame scope must review all tabs before native frame deletion."
  (let ((seen nil))
    (cl-letf (((symbol-function 'glassmacs--frame-has-hidden-tabs-p)
               (lambda (_frame) t))
              ((symbol-function 'glassmacs--frame-tab-buffers)
               (lambda (_frame) '(one two)))
              ((symbol-function 'glassmacs--review-frame-tab-buffers)
               (lambda (_frame buffers) (setq seen buffers) t)))
      (should (glassmacs--close-reviewed 'frame (selected-frame)))
      (should (equal seen '(one two))))))

(ert-deftest glassmacs-reviewed-tab-close-menu-command ()
  "The Window menu exposes the guarded close, not raw tab-bar close."
  (let ((system-type 'darwin))
    (glassmacs--install-reviewed-tab-close-menu)
    (let ((item (lookup-key global-map [menu-bar window glassmacs-close-tab])))
      (should (eq (car item) 'menu-item))
      (should (eq (nth 2 item) 'glassmacs-close-current-tab)))))

(ert-deftest glassmacs-reviewed-tab-close-cancel-preserves-tab ()
  "A canceled document review must leave the current tab intact."
  (let ((closed nil))
    (cl-letf (((symbol-function 'glassmacs--frame-has-hidden-tabs-p)
               (lambda (_frame) t))
              ((symbol-function 'glassmacs--confirm-console-windows-close)
               (lambda (_windows) t))
              ((symbol-function 'glassmacs--close-documents-in-windows)
               (lambda (_windows) nil))
              ((symbol-function 'tab-bar-close-tab)
               (lambda (&rest _) (setq closed t))))
      (glassmacs-close-current-tab)
      (should-not closed))))

(ert-deftest glassmacs-reviewed-tab-close-protects-r-process ()
  "The reviewed tab close delegates only to view closing, not session exit."
  (let ((closed nil)
        (reviewed nil))
    (cl-letf (((symbol-function 'glassmacs--frame-has-hidden-tabs-p)
               (lambda (_frame) t))
              ((symbol-function 'glassmacs--confirm-console-windows-close)
               (lambda (_windows) (setq reviewed t) t))
              ((symbol-function 'glassmacs--close-documents-in-windows)
               (lambda (_windows) t))
              ((symbol-function 'tab-bar-close-tab)
               (lambda (&rest _) (setq closed t))))
      (glassmacs-close-current-tab)
      (should reviewed)
      (should closed))))

(ert-deftest glassmacs-native-frame-close-reviews-hidden-tabs ()
  "A native multi-tab close routes through the all-tab review."
  (let ((reviewed nil)
        (tab-bar-mode t))
    (cl-letf (((symbol-function 'tab-bar-tabs-function)
               (lambda (_frame) '((name . "one") (name . "two"))))
              ((symbol-function 'glassmacs--frame-tab-buffers)
               (lambda (_frame) '(first second)))
              ((symbol-function 'glassmacs--review-frame-tab-buffers)
               (lambda (_frame buffers)
                 (setq reviewed buffers)
                 nil)))
      (should-not (glassmacs-close-frame-documents (selected-frame)))
      (should (equal reviewed '(first second))))))

(ert-deftest glassmacs-native-frame-review-cancel-keeps-documents ()
  "Cancel after one approval must not kill any document."
  (let ((first (generate-new-buffer "glassmacs-frame-first"))
        (second (generate-new-buffer "glassmacs-frame-second"))
        (answers '(?d ?c)))
    (unwind-protect
        (progn
          (with-current-buffer first (insert "one"))
          (with-current-buffer second (insert "two"))
          (cl-letf (((symbol-function 'glassmacs--buffer-visible-in-other-frame-p)
                     (lambda (&rest _) nil))
                    ((symbol-function 'read-multiple-choice)
                     (lambda (&rest _) (prog1 (list (car answers))
                                         (setq answers (cdr answers))))))
            (should-not (glassmacs--review-frame-tab-buffers
                         (selected-frame) (list first second)))
            (should (buffer-live-p first))
            (should (buffer-live-p second))
            (should (buffer-modified-p first))
            (should (buffer-modified-p second))))
      (dolist (buffer (list first second))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

(ert-deftest glassmacs-native-frame-close-single-tab-continues-review ()
  "A frame with one tab still performs its usual close checks."
  (let ((tab-bar-mode t)
        (checked nil))
    (cl-letf (((symbol-function 'tab-bar-tabs-function)
               (lambda (_frame) '((name . "only"))))
              ((symbol-function 'glassmacs--confirm-console-windows-close)
               (lambda (windows) (setq checked windows) nil)))
      (should-not (glassmacs--frame-has-hidden-tabs-p (selected-frame)))
      (should-not (glassmacs-close-frame-documents (selected-frame)))
      (should checked))))

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

(ert-deftest glassmacs-close-button-save-writes-then-closes-document ()
  "Native close-button handler saves edits before proceeding to frame close."
  (let* ((file (make-temp-file "glassmacs-button-save-" nil ".txt" "original"))
         (buffer (find-file-noselect file))
         (original-called nil))
    (unwind-protect
        (save-window-excursion
          (delete-other-windows)
          (set-window-buffer (selected-window) buffer)
          (with-current-buffer buffer
            (goto-char (point-max))
            (insert " saved"))
          (cl-letf (((symbol-function 'event-start) #'identity)
                    ((symbol-function 'posn-window) #'identity)
                    ((symbol-function 'make-frame-invisible)
                     (lambda (&rest _) (setq original-called t))))
            (glassmacs-close-test--answering ?s
              (glassmacs--handle-delete-frame-preserving-app
               (lambda (_event) (setq original-called t))
               (selected-frame))
              (should (= prompts 1))))
          (should original-called)
          (should-not (buffer-live-p buffer))
          (should (string-prefix-p
                   "original saved"
                   (with-temp-buffer
                     (insert-file-contents file)
                     (buffer-string)))))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (delete-file file))))

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

(ert-deftest glassmacs-console-close-dismissed-dialog-preserves-live-session ()
  "A quit or UI failure during the hide prompt must never close R's view."
  (let ((buffer (generate-new-buffer " *live-r-close-test*"))
        (window nil))
    (unwind-protect
        (glassmacs-close-test--with-split buffer
          (setq window (selected-window))
          (cl-letf (((symbol-function 'glassmacs--live-r-console-p)
                     (lambda (candidate) (eq candidate buffer)))
                    ((symbol-function 'read-multiple-choice)
                     (lambda (&rest _) (signal 'quit nil))))
            (should-not (glassmacs--confirm-console-windows-close
                         (list window)))
            (should (window-live-p window)))
          (cl-letf (((symbol-function 'glassmacs--live-r-console-p)
                     (lambda (candidate) (eq candidate buffer)))
                    ((symbol-function 'read-multiple-choice)
                     (lambda (&rest _) (error "Dialog unavailable"))))
            (should-not (glassmacs--confirm-console-windows-close
                         (list window)))
            (should (window-live-p window))))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer)))))

(ert-deftest glassmacs-untitled-close-cancel-preserves-edits ()
  "An edited untitled document cannot disappear on canceled Command-W."
  (let ((buffer (generate-new-buffer "Untitled P0 Close")))
    (unwind-protect
        (glassmacs-close-test--with-split buffer
          (with-current-buffer buffer (insert "unsaved untitled content"))
          (glassmacs-close-test--answering ?c
            (glassmacs-close-document)
            (should (= prompts 1))
            (should (buffer-live-p buffer))
            (should (buffer-modified-p buffer))
            (should (window-live-p window))))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer)))))

(ert-deftest glassmacs-untitled-close-save-error-preserves-edits ()
  "Failed save of an untitled document must veto window closure."
  (let ((buffer (generate-new-buffer "Untitled P0 Save Failure")))
    (unwind-protect
        (glassmacs-close-test--with-split buffer
          (with-current-buffer buffer (insert "must survive"))
          (cl-letf (((symbol-function 'read-multiple-choice)
                     (lambda (&rest _) '(?s "save")))
                    ((symbol-function 'save-buffer)
                     (lambda (&rest _) (error "Simulated save failure"))))
            (glassmacs-close-document)
            (should (buffer-live-p buffer))
            (should (buffer-modified-p buffer))
            (should (window-live-p window))))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer)))))

(provide 'test-glassmacs-close)
;;; test-glassmacs-close.el ends here
