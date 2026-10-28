;;; glassmacs-packages.el --- Optional package installation -*- lexical-binding: t; -*-

;; Aquamacs shipped ESS, AUCTeX and markdown-mode inside the application,
;; so R files worked on first launch.  Glassmacs keeps these packages out of
;; the bundle and installs them into the isolated package directory under
;; `glassmacs-home'.  This module is the single implementation of that
;; installation: the File/Glassmacs menu command, the first-use offer when
;; an R or research document opens without its mode, and scripts/bootstrap
;; all call `glassmacs-install-optional-packages'.

(require 'cl-lib)
(require 'package)

(defgroup glassmacs-packages nil
  "Optional Emacs packages used by Glassmacs."
  :group 'glassmacs)

(defconst glassmacs-optional-packages
  '(ess markdown-mode quarto-mode polymode poly-R auctex)
  "Optional packages for R and research documents.
Names must match their archive entries exactly: for example the MELPA
package is `quarto-mode', not `quarto'.")

(defcustom glassmacs-offer-package-installation t
  "Whether to offer installing optional packages when they are needed.
When non-nil and an R or research document opens while its mode is
missing, Glassmacs asks once per session whether to install
`glassmacs-optional-packages'.  Nothing is downloaded without consent."
  :type 'boolean
  :group 'glassmacs-packages)

(defvar glassmacs-packages--offered nil
  "Non-nil once installation has been offered in this session.")

(defun glassmacs-missing-optional-packages ()
  "Return the optional packages that are not installed."
  (cl-remove-if #'package-installed-p glassmacs-optional-packages))

(defvar-local glassmacs-packages--fallback-mode nil
  "Non-nil when this buffer fell back to a basic mode for lack of a package.")

(defun glassmacs-packages--refresh-document-modes ()
  "Reselect the major mode of documents that fell back to a basic mode.
Buffers opened before installation used a basic mode; choosing the mode
again lets them use the newly installed one."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and glassmacs-packages--fallback-mode buffer-file-name)
        (set-auto-mode)))))

(defun glassmacs-packages--warn (format-string &rest arguments)
  "Display a Glassmacs warning built from FORMAT-STRING and ARGUMENTS."
  (display-warning 'glassmacs (apply #'format format-string arguments) :warning))

(defun glassmacs-install-optional-packages (&optional no-confirm)
  "Install missing `glassmacs-optional-packages' into the Glassmacs home.
Ask for confirmation first unless NO-CONFIRM is non-nil.  Each package is
installed independently, so one unavailable package does not prevent the
others; failures are reported together at the end.  Return a plist with
:installed and :failed (a list of \"PACKAGE (reason)\" strings).  In
batch use (scripts/bootstrap) a failure signals an error so the script
exits with a nonzero status."
  (interactive)
  (let ((missing (glassmacs-missing-optional-packages))
        installed failed)
    (cond
     ((null missing)
      (message "All optional Glassmacs packages are already installed."))
     ((not (or no-confirm noninteractive
               (y-or-n-p
                (format "Install %s into %s? This downloads packages from GNU ELPA, NonGNU ELPA and MELPA. "
                        (mapconcat #'symbol-name missing ", ")
                        package-user-dir))))
      (message "Optional packages were not installed"))
     (t
      (message "Refreshing package archives...")
      (condition-case error-data
          (package-refresh-contents)
        (error
         (user-error "Could not refresh package archives; check network access and retry: %s"
                     (error-message-string error-data))))
      (dolist (package missing)
        (message "Installing %s..." package)
        (condition-case error-data
            (progn
              (package-install package)
              (push package installed))
          (error
           (push (format "%s (%s)" package (error-message-string error-data))
                 failed))))
      (setq installed (nreverse installed)
            failed (nreverse failed))
      (when installed
        (glassmacs-packages--refresh-document-modes)
        (message "Installed optional Glassmacs packages: %s"
                 (mapconcat #'symbol-name installed ", ")))
      (when failed
        (funcall (if noninteractive #'error #'glassmacs-packages--warn)
                 "Could not install optional Glassmacs packages: %s; check network access and retry"
                 (mapconcat #'identity failed "; ")))))
    (list :installed installed :failed failed)))

(defun glassmacs-packages-offer-installation (feature)
  "Offer once per session to install optional packages, for FEATURE.
FEATURE is a short description such as \"R editing (ESS)\".  The question
is asked after the current command finishes, so the document is already
visible.  Nothing happens in batch sessions, when the offer is disabled
by `glassmacs-offer-package-installation', or when nothing is missing.
The current buffer is marked so that it switches to the proper mode once
the packages are installed."
  (setq glassmacs-packages--fallback-mode t)
  (when (and glassmacs-offer-package-installation
             (not noninteractive)
             (not glassmacs-packages--offered)
             (glassmacs-missing-optional-packages))
    (setq glassmacs-packages--offered t)
    (run-at-time
     0 nil
     (lambda ()
       (when (y-or-n-p
              (format "%s is not installed. Install Glassmacs's optional packages now (requires network)? "
                      feature))
         (glassmacs-install-optional-packages t))))))

(provide 'glassmacs-packages)
;;; glassmacs-packages.el ends here
