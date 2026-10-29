;;; test-glassmacs-packages.el --- Optional package installation tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-packages)
(require 'glassmacs-r)

(defmacro glassmacs-packages-test--with-archive (failing &rest body)
  "Run BODY with package.el stubbed; installing a package in FAILING fails.
Inside BODY, `installed' holds the packages installed so far."
  (declare (indent 1))
  `(let ((installed nil)
         (glassmacs-packages--offered nil))
     (cl-letf (((symbol-function 'package-refresh-contents) #'ignore)
               ((symbol-function 'package-installed-p)
                (lambda (package &rest _) (memq package installed)))
               ((symbol-function 'package-install)
                (lambda (package &rest _)
                  (when (memq package ,failing)
                    (error "Package `%s' is unavailable" package))
                  (push package installed))))
       ,@body)))

(ert-deftest glassmacs-packages-install-each-package-independently ()
  (glassmacs-packages-test--with-archive '(polymode)
    (let ((noninteractive nil) warnings)
      (cl-letf (((symbol-function 'display-warning)
                 (lambda (_type message &rest _) (push message warnings)))
                ((symbol-function 'glassmacs-packages--refresh-document-modes)
                 #'ignore))
        (let ((result (glassmacs-install-optional-packages t)))
          (should (equal (plist-get result :installed)
                         '(ess markdown-mode quarto-mode poly-R auctex)))
          (should (string-match-p "\\`polymode (" (car (plist-get result :failed))))
          (should (string-match-p "polymode" (car warnings))))))))

(ert-deftest glassmacs-packages-batch-failure-signals-error ()
  (glassmacs-packages-test--with-archive '(ess)
    (cl-letf (((symbol-function 'glassmacs-packages--refresh-document-modes)
               #'ignore))
      (should-error (glassmacs-install-optional-packages t))
      ;; The other packages were still installed before the error.
      (should (memq 'auctex installed)))))

(ert-deftest glassmacs-packages-decline-installs-nothing ()
  (glassmacs-packages-test--with-archive nil
    (let ((noninteractive nil))
      (cl-letf (((symbol-function 'y-or-n-p) (lambda (_prompt) nil)))
        (glassmacs-install-optional-packages)
        (should-not installed)))))

(ert-deftest glassmacs-packages-refresh-reselects-research-document-modes ()
  (let ((r-buffer (generate-new-buffer " *glassmacs-pkg-r*"))
        (text-buffer (generate-new-buffer " *glassmacs-pkg-text*"))
        reselected)
    (unwind-protect
        (progn
          (with-current-buffer r-buffer
            (setq buffer-file-name "/tmp/analysis.R")
            (let ((noninteractive t))
              (glassmacs-packages-offer-installation "R editing (ESS)")))
          (with-current-buffer text-buffer (setq buffer-file-name "/tmp/notes.txt"))
          (cl-letf (((symbol-function 'set-auto-mode)
                     (lambda (&rest _) (push (current-buffer) reselected))))
            (glassmacs-packages--refresh-document-modes))
          (should (memq r-buffer reselected))
          (should-not (memq text-buffer reselected)))
      (dolist (buffer (list r-buffer text-buffer))
        (with-current-buffer buffer (setq buffer-file-name nil))
        (kill-buffer buffer)))))

(ert-deftest glassmacs-packages-offer-is-asked-once-per-session ()
  (glassmacs-packages-test--with-archive nil
    (let ((noninteractive nil) (asked 0)
          (glassmacs-packages--startup-finished t))
      (cl-letf (((symbol-function 'run-with-idle-timer)
                 (lambda (_time _repeat function &rest args)
                   (apply function args)))
                ((symbol-function 'y-or-n-p)
                 (lambda (_prompt) (cl-incf asked) nil)))
        (glassmacs-packages-offer-installation "R editing (ESS)")
        (glassmacs-packages-offer-installation "R editing (ESS)")
        (should (= asked 1))
        (should-not installed)))))

(ert-deftest glassmacs-packages-offer-is-silent-in-batch-and-when-disabled ()
  (glassmacs-packages-test--with-archive nil
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (&rest _) (ert-fail "must not schedule an offer"))))
      (glassmacs-packages-offer-installation "R editing (ESS)")
      (let ((noninteractive nil)
            (glassmacs-offer-package-installation nil))
        (glassmacs-packages-offer-installation "R editing (ESS)")))))

(ert-deftest glassmacs-packages-offer-waits-for-startup-and-other-questions ()
  "A document restored at startup must not ask while Glassmacs is still
starting (it held up the Finder document and the crash-recovery offer),
nor while another question is open."
  (glassmacs-packages-test--with-archive nil
    (let ((noninteractive nil) (asked 0) (timers nil)
          (glassmacs-packages--startup-finished nil)
          (minibuffer-open nil))
      (cl-letf (((symbol-function 'run-with-idle-timer)
                 (lambda (_time _repeat function &rest args)
                   (push (lambda () (apply function args)) timers)))
                ((symbol-function 'active-minibuffer-window)
                 (lambda () minibuffer-open))
                ((symbol-function 'y-or-n-p)
                 (lambda (_prompt) (cl-incf asked) nil)))
        (let ((run-idle-timers (lambda ()
                                 (let ((due (nreverse timers)))
                                   (setq timers nil)
                                   (mapc #'funcall due)))))
          (glassmacs-packages-offer-installation "R Markdown editing (poly-R)")
          ;; Still starting: Emacs idles (for example in a prompt), no question.
          (funcall run-idle-timers)
          (should (= asked 0))
          (should timers)
          ;; Started, but another question is open.
          (setq glassmacs-packages--startup-finished t minibuffer-open t)
          (funcall run-idle-timers)
          (should (= asked 0))
          ;; Idle with nothing else asking: now it asks, once.
          (setq minibuffer-open nil)
          (funcall run-idle-timers)
          (should (= asked 1))
          (should-not timers))))))

(ert-deftest glassmacs-r-mode-without-ess-offers-installation ()
  (when (or (fboundp 'ess-r-mode) (fboundp 'R-mode))
    (ert-skip "ESS is installed, so R mode needs no offer"))
  (let (offered)
    (cl-letf (((symbol-function 'glassmacs-packages-offer-installation)
               (lambda (feature) (setq offered feature))))
      (with-temp-buffer
        (glassmacs-r-mode)
        (should (eq major-mode 'fundamental-mode))))
    (should (equal offered "R editing (ESS)"))))

(provide 'test-glassmacs-packages)
;;; test-glassmacs-packages.el ends here
