;;; test-glassmacs-environment.el --- Shell environment import tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs-environment)

(defmacro glassmacs-env-test--with-isolated-environment (&rest body)
  "Run BODY with a private copy of the process environment and `exec-path'."
  `(let ((process-environment (copy-sequence process-environment))
         (exec-path (copy-sequence exec-path))
         (glassmacs-environment-status nil))
     ,@body))

(defun glassmacs-env-test--fake-shell (body)
  "Return a temporary executable acting as a login shell.
It prints some startup noise, runs BODY, then the command passed with -c."
  (let ((shell (make-temp-file "glassmacs-fake-shell-")))
    (with-temp-file shell
      (insert "#!/bin/sh\n"
              "echo 'Last login: noise from startup files'\n"
              "echo 'PATH=/not/the/real/value'\n"
              body "\n"
              "eval \"command=\\${$#}\"\n"
              "exec /bin/sh -c \"$command\"\n"))
    (set-file-modes shell #o700)
    shell))

(ert-deftest glassmacs-environment-parses-only-after-marker ()
  (let ((output (concat "PATH=/before/marker\nnoise\n"
                        glassmacs-environment--marker "\n"
                        "HOME=/home/user\nPATH=/opt/homebrew/bin:/usr/bin\n"
                        "LANG=en_US.UTF-8\nPATH=/second/value\n")))
    (should (equal (glassmacs-environment--parse output '("PATH" "LANG" "R_LIBS"))
                   '(("PATH" . "/opt/homebrew/bin:/usr/bin")
                     ("LANG" . "en_US.UTF-8"))))
    (should-not (glassmacs-environment--parse "PATH=/x\n" '("PATH")))))

(ert-deftest glassmacs-environment-shell-arguments-match-shell-family ()
  (should (equal (glassmacs-environment--shell-arguments "/bin/zsh") '("-l" "-i")))
  (should (equal (glassmacs-environment--shell-arguments "/bin/bash") '("-l" "-i")))
  (should (equal (glassmacs-environment--shell-arguments "/opt/homebrew/bin/fish")
                 '("-l")))
  (should (equal (glassmacs-environment--shell-arguments "/bin/tcsh") '("-d")))
  (should (equal (glassmacs-environment--shell-arguments "/bin/csh") '("-d"))))

(ert-deftest glassmacs-environment-imports-variables-from-login-shell ()
  (let ((shell (glassmacs-env-test--fake-shell
                "export PATH=/glassmacs/test/bin:/usr/bin:/bin R_LIBS_USER=/r/lib")))
    (unwind-protect
        (glassmacs-env-test--with-isolated-environment
         (setenv "SHELL" shell)
         (setenv "R_LIBS_USER")
         (let ((glassmacs-import-shell-environment t)
               (glassmacs-standard-tool-directories nil))
           (should (string-match-p "imported 2 variable"
                                   (glassmacs-import-shell-environment)))
           (should (equal (getenv "PATH") "/glassmacs/test/bin:/usr/bin:/bin"))
           (should (equal (getenv "R_LIBS_USER") "/r/lib"))
           (should (equal (car exec-path) "/glassmacs/test/bin/"))
           (should (equal (car (last exec-path)) exec-directory))))
      (delete-file shell))))

(ert-deftest glassmacs-environment-times-out-without-blocking-startup ()
  (let ((shell (glassmacs-env-test--fake-shell "sleep 10")))
    (unwind-protect
        (glassmacs-env-test--with-isolated-environment
         (let ((original-path (getenv "PATH"))
               (glassmacs-shell-environment-timeout 0.3)
               (started (float-time)))
           (should (string-match-p
                    "timed out"
                    (glassmacs-environment--read-shell shell '("PATH") 0.3)))
           (should (< (- (float-time) started) 3))
           (should (equal (getenv "PATH") original-path))))
      (delete-file shell))))

(ert-deftest glassmacs-environment-failure-warns-and-keeps-environment ()
  (glassmacs-env-test--with-isolated-environment
   (setenv "SHELL" "/glassmacs/no/such/shell")
   (let ((original-path (getenv "PATH"))
         (glassmacs-import-shell-environment t)
         (glassmacs-standard-tool-directories nil)
         warnings)
     (cl-letf (((symbol-function 'display-warning)
                (lambda (_type message &rest _) (push message warnings))))
       (should (string-match-p "shell import failed"
                               (glassmacs-import-shell-environment))))
     (should warnings)
     (should (equal (getenv "PATH") original-path)))))

(ert-deftest glassmacs-environment-appends-existing-standard-directories ()
  (let ((first (make-temp-file "glassmacs-tools-a-" t))
        (second (make-temp-file "glassmacs-tools-b-" t)))
    (unwind-protect
        (glassmacs-env-test--with-isolated-environment
         (setenv "PATH" (concat "/usr/bin" path-separator second))
         (let ((glassmacs-import-shell-environment nil)
               (glassmacs-standard-tool-directories
                (list first second "/glassmacs/missing/bin")))
           (glassmacs-import-shell-environment)
           ;; Appended (shell PATH keeps precedence), existing only, no duplicates.
           (should (equal (getenv "PATH")
                          (mapconcat #'identity (list "/usr/bin" second first)
                                     path-separator)))
           (should (member (file-name-as-directory first) exec-path))
           (should (string-match-p "shell import disabled; appended"
                                   glassmacs-environment-status))))
      (delete-directory first)
      (delete-directory second))))

(ert-deftest glassmacs-environment-is-skipped-outside-macos-gui ()
  (glassmacs-env-test--with-isolated-environment
   (let ((original-path (getenv "PATH")))
     (cl-letf (((symbol-function 'glassmacs-import-shell-environment)
                (lambda () (ert-fail "must not import in batch sessions"))))
       (glassmacs-environment-initialize))
     (should (string-match-p "not needed" glassmacs-environment-status))
     (should (equal (getenv "PATH") original-path)))))

(provide 'test-glassmacs-environment)
;;; test-glassmacs-environment.el ends here
