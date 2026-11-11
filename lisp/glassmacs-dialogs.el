;;; glassmacs-dialogs.el --- Native choice dialogs with a safe fallback -*- lexical-binding: t; -*-

;; Application-level decisions (closing a live R console, quitting with R
;; running) are presented as native macOS alerts, never as a typed yes/no
;; in the minibuffer.  The alert runs in the bundled GlassmacsQuitAlert
;; helper, which writes its answer to a JSON file; see
;; macos/Sources/GlassmacsQuitAlert/main.swift (`--choice' mode).
;;
;; Outside the packaged macOS app (a terminal, batch tests, a helper that
;; fails to run) the same choices are asked with `read-multiple-choice'.
;; Every failure, dismissal or keyboard quit resolves to the choice marked
;; :cancel, so an unanswered dialog can never close or terminate anything.

(require 'cl-lib)
(require 'json)

(defun glassmacs-dialog--helper-app ()
  "Return the bundled alert helper application directory."
  (expand-file-name "../Helpers/GlassmacsQuitAlert.app" invocation-directory))

(defun glassmacs-dialog--native-available-p ()
  "Whether the native alert helper can be used in this session."
  (and (eq system-type 'darwin)
       (display-graphic-p)
       (not noninteractive)
       (executable-find "open")
       (file-executable-p
        (expand-file-name "Contents/MacOS/GlassmacsQuitAlert"
                          (glassmacs-dialog--helper-app)))))

(defun glassmacs-dialog--cancel-id (choices)
  "Return the id of the :cancel choice in CHOICES, or nil."
  (car (cl-find-if (lambda (choice) (plist-get (cddr choice) :cancel))
                   choices)))

(defun glassmacs-dialog--native-choose (message informative choices)
  "Show MESSAGE and INFORMATIVE with CHOICES natively; return an id or nil.
Return nil, after reporting why, when the helper cannot answer."
  (let ((spec-file (make-temp-file "glassmacs-choice-spec-" nil ".json"))
        (response-file (make-temp-file "glassmacs-choice-response-" nil ".json"))
        (output (generate-new-buffer " *glassmacs-choice-helper*")))
    (unwind-protect
        (condition-case err
            (progn
              (with-temp-file spec-file
                (insert
                 (json-encode
                  `((message . ,message)
                    (informative . ,(or informative ""))
                    (buttons
                     . ,(vconcat
                         (mapcar
                          (lambda (choice)
                            (let ((props (cddr choice)))
                              `((id . ,(symbol-name (car choice)))
                                (label . ,(cadr choice))
                                (default . ,(if (plist-get props :default) t :json-false))
                                (cancel . ,(if (plist-get props :cancel) t :json-false))
                                (destructive
                                 . ,(if (plist-get props :destructive) t :json-false)))))
                          choices)))))))
              (let ((status (process-file
                             (executable-find "open") nil output nil
                             "-n" "-W" "-a" (glassmacs-dialog--helper-app)
                             "--args" "--choice" response-file spec-file)))
                (if (and (eql status 0) (file-readable-p response-file))
                    (let* ((json-object-type 'alist)
                           (response (with-temp-buffer
                                       (insert-file-contents response-file)
                                       (goto-char (point-min))
                                       (json-read)))
                           (id (cdr (assq 'choice response))))
                      (or (and (stringp id)
                               (car (cl-find id choices
                                             :key (lambda (c) (symbol-name (car c)))
                                             :test #'equal)))
                          (progn
                            (message "Glassmacs dialog helper returned no valid choice")
                            nil)))
                  (message "Glassmacs dialog helper failed (status %s): %s"
                           status (with-current-buffer output
                                    (string-trim (buffer-string))))
                  nil)))
          (error
           (message "Glassmacs dialog helper failed: %s" (error-message-string err))
           nil))
      (ignore-errors (delete-file spec-file))
      (ignore-errors (delete-file response-file))
      (kill-buffer output))))

(defun glassmacs-dialog--fallback-choose (message informative choices)
  "Ask MESSAGE with CHOICES through `read-multiple-choice'.
INFORMATIVE becomes the help text of each answer."
  (let* ((entries (mapcar (lambda (choice)
                            (let ((props (cddr choice)))
                              (list (or (plist-get props :key)
                                        (downcase (aref (cadr choice) 0)))
                                    (cadr choice)
                                    (or (plist-get props :description)
                                        informative
                                        (cadr choice))
                                    (car choice))))
                          choices))
         (answer (read-multiple-choice (concat message " ")
                                       (mapcar (lambda (e) (butlast e)) entries))))
    (nth 3 (assq (car answer) entries))))

(defun glassmacs-dialog-choose (message choices &optional informative)
  "Ask MESSAGE and return the id of the selected entry of CHOICES.
CHOICES is a list of (ID LABEL . PROPS).  PROPS may contain :default
\(the Return button), :cancel (Escape, closing, failure and quit),
:destructive (shown in the native destructive style), :key (the
fallback answer character) and :description (fallback help text).
INFORMATIVE is the explanatory text under MESSAGE.

In the packaged macOS app this is a native alert; elsewhere it uses
`read-multiple-choice'.  A dismissed, failed or quit dialog returns
the :cancel choice, never another action."
  (let ((cancel (glassmacs-dialog--cancel-id choices)))
    (condition-case nil
        (or (and (glassmacs-dialog--native-available-p)
                 (glassmacs-dialog--native-choose message informative choices))
            (glassmacs-dialog--fallback-choose message informative choices)
            cancel)
      ((quit error) cancel))))

(provide 'glassmacs-dialogs)
;;; glassmacs-dialogs.el ends here
