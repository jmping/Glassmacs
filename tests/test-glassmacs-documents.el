;;; test-glassmacs-documents.el --- Mixed R document tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'glassmacs)

(defmacro glassmacs-chunks-test--in-document (name text &rest body)
  "Run BODY in a buffer named NAME containing TEXT."
  (declare (indent 2))
  `(with-temp-buffer
     (rename-buffer ,name t)
     (insert ,text)
     (goto-char (point-min))
     ,@body))
;; Defined by polymode; declared so `let' binds it dynamically without it.
(defvar polymode-move-these-vars-from-base-buffer)

(defmacro glassmacs-documents-test--with-modes (available &rest body)
  "Run BODY where only the mode functions in AVAILABLE are defined.
Each available mode records its name in `chosen'; `offered' records
installation offers."
  (declare (indent 1))
  `(let ((chosen nil) (offered nil))
     (cl-letf ,(append
                (mapcar (lambda (mode)
                          `((symbol-function ',mode)
                            ,(if (memq mode available)
                                 `(lambda () (setq chosen ',mode))
                               nil)))
                        '(poly-noweb+r-mode Rnw-mode poly-markdown+r-mode quarto-mode
                                            LaTeX-mode latex-mode markdown-mode))
                '(((symbol-function 'glassmacs-packages-offer-installation)
                   (lambda (feature) (setq offered feature)))))
       ,@body)))

(ert-deftest glassmacs-documents-sweave-uses-poly-r ()
  "ESS 18.10 removed Rnw-mode; Sweave files use poly-R's noweb mode."
  (glassmacs-documents-test--with-modes (poly-noweb+r-mode Rnw-mode latex-mode)
    (with-temp-buffer (glassmacs-sweave-mode))
    (should (eq chosen 'poly-noweb+r-mode))
    (should-not offered))
  (glassmacs-documents-test--with-modes (Rnw-mode latex-mode)
    (with-temp-buffer (glassmacs-sweave-mode))
    (should (eq chosen 'Rnw-mode)))
  (glassmacs-documents-test--with-modes (latex-mode)
    (with-temp-buffer (glassmacs-sweave-mode))
    (should (eq chosen 'latex-mode))
    (should (equal offered "Sweave editing (poly-R)"))))

(ert-deftest glassmacs-documents-quarto-falls-back-to-r-markdown-editing ()
  (glassmacs-documents-test--with-modes (quarto-mode poly-markdown+r-mode markdown-mode)
    (with-temp-buffer (glassmacs-quarto-mode))
    (should (eq chosen 'quarto-mode)))
  (glassmacs-documents-test--with-modes (poly-markdown+r-mode markdown-mode)
    (with-temp-buffer (glassmacs-quarto-mode))
    (should (eq chosen 'poly-markdown+r-mode))
    (should (equal offered "Quarto editing (quarto-mode)"))))

;;; One R target per document

(ert-deftest glassmacs-documents-r-target-is-shared-by-all-chunk-buffers ()
  "A target chosen inside a chunk applies to the prose and every chunk."
  (let* ((base (generate-new-buffer "glassmacs-target.Rmd"))
         (chunk (make-indirect-buffer base " glassmacs-target-r-chunk"))
         (other (make-indirect-buffer base " glassmacs-target-yaml"))
         (unrelated (generate-new-buffer "glassmacs-unrelated.R")))
    (unwind-protect
        (cl-letf (((symbol-function 'glassmacs-sessions-find)
                   (lambda (_id) (glassmacs-session--make :id "R-2" :state 'ready)))
                  ((symbol-function 'glassmacs-sessions--process-live-p)
                   (lambda (_process) t)))
          (with-current-buffer chunk (glassmacs-r-select-session "R-2"))
          (dolist (buffer (list base chunk other))
            (should (equal (buffer-local-value 'glassmacs-r-target-session buffer)
                           "R-2"))
            (should (buffer-local-value 'glassmacs-r-target-indicator-mode buffer)))
          (should-not (buffer-local-value 'glassmacs-r-target-session unrelated))
          (with-current-buffer base (glassmacs-r-clear-session-target))
          (dolist (buffer (list base chunk other))
            (should-not (buffer-local-value 'glassmacs-r-target-session buffer))))
      (kill-buffer chunk)
      (kill-buffer other)
      (kill-buffer base)
      (kill-buffer unrelated))))

(ert-deftest glassmacs-documents-polymode-copies-the-target-to-new-chunks ()
  (let ((polymode-move-these-vars-from-base-buffer '(buffer-file-name)))
    (glassmacs-r--register-polymode-variables)
    (glassmacs-r--register-polymode-variables)
    (should (equal polymode-move-these-vars-from-base-buffer
                   '(glassmacs-r-target-session buffer-file-name)))))

;;; Rendering and opening the result

(defun glassmacs-documents-test--render (render file process-output)
  "Run RENDER on FILE as if the renderer printed PROCESS-OUTPUT.
Return (ARGUMENTS . OPENED): the renderer's arguments and the file opened."
  (let (arguments opened)
    (with-temp-buffer
      (setq buffer-file-name file)
      (cl-letf (((symbol-function 'glassmacs-run-process)
                 (lambda (&rest args) (setq arguments args)))
                ((symbol-function 'glassmacs-open-rendered-output)
                 (lambda (output) (setq opened output))))
        (funcall render)
        (with-current-buffer (get-buffer-create glassmacs-process-buffer-name)
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert process-output)))
        (funcall (nth 3 arguments)))
      (setq buffer-file-name nil))
    (cons arguments opened)))

(ert-deftest glassmacs-documents-rmarkdown-render-opens-the-reported-output ()
  (let* ((result (glassmacs-documents-test--render
                  #'glassmacs-render-rmarkdown "/tmp/project/report.Rmd"
                  "processing file: report.Rmd\noutput file: report.knit.md\nGLASSMACS_RENDER_OUTPUT=/tmp/project/report.html\n"))
         (arguments (car result)))
    (should (equal (car arguments) "Rscript"))
    (should (string-match-p "rmarkdown::render(\"/tmp/project/report.Rmd\")"
                            (cadr (cadr arguments))))
    (should (equal (cdr result) "/tmp/project/report.html"))))

(ert-deftest glassmacs-documents-quarto-render-opens-the-reported-output ()
  (let ((result (glassmacs-documents-test--render
                 #'glassmacs-render-quarto "/tmp/project/analysis.qmd"
                 "processing...\nOutput created: analysis.html\n")))
    (should (equal (car (car result)) "quarto"))
    (should (equal (cdr result) "/tmp/project/analysis.html"))))

(ert-deftest glassmacs-documents-render-can-leave-output-closed ()
  (let ((glassmacs-render-open-output nil))
    (should-not (cdr (glassmacs-documents-test--render
                      #'glassmacs-render-quarto "/tmp/project/a.qmd"
                      "Output created: a.html\n")))))

(ert-deftest glassmacs-documents-rendered-output-opens-in-its-viewer ()
  (let ((file (make-temp-file "glassmacs-output-" nil ".html")) opened)
    (unwind-protect
        (cl-letf (((symbol-function 'browse-url-of-file)
                   (lambda (f) (setq opened (cons 'browser f))))
                  ((symbol-function 'glassmacs-latex-open-pdf)
                   (lambda (f) (setq opened (cons 'pdf f)))))
          (glassmacs-open-rendered-output file)
          (should (equal opened (cons 'browser file)))
          (let ((pdf (concat (file-name-sans-extension file) ".pdf")))
            (write-region "" nil pdf)
            (unwind-protect
                (progn (glassmacs-open-rendered-output pdf)
                       (should (equal opened (cons 'pdf pdf))))
              (delete-file pdf)))
          (should-error (glassmacs-open-rendered-output "/tmp/glassmacs-missing.html")
                        :type 'user-error))
      (delete-file file))))

;;; Shiny apps and interactive documents

(defmacro glassmacs-documents-test--fresh-shiny (&rest body)
  "Run BODY with no Glassmacs Shiny app running, and stop any it starts."
  `(let ((glassmacs-shiny-process nil)
         (glassmacs-shiny-url nil)
         (glassmacs-shiny--last-start nil))
     (unwind-protect (progn ,@body)
       (when (process-live-p glassmacs-shiny-process)
         (delete-process glassmacs-shiny-process)))))

(defun glassmacs-documents-test--wait-for (predicate)
  "Accept process output until PREDICATE returns non-nil or 5 seconds pass."
  (let ((deadline (+ (float-time) 5)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.05))))

(ert-deftest glassmacs-documents-shiny-opens-the-app-once-it-is-listening ()
  "The address is recognized even when it arrives split across output."
  (glassmacs-documents-test--fresh-shiny
   (let (opened)
     (cl-letf (((symbol-function 'browse-url) (lambda (url &rest _) (push url opened)))
               ((symbol-function 'message) #'ignore))
       (glassmacs-shiny--start
        "test app"
        '("sh" "-c" "printf 'Loading\\nListening on http://127.0.0.1:43'; sleep 0.3; printf '21\\n'; sleep 30")
        temporary-file-directory #'ignore)
       (glassmacs-documents-test--wait-for (lambda () glassmacs-shiny-url))
       (should (equal glassmacs-shiny-url "http://127.0.0.1:4321"))
       (should (equal opened '("http://127.0.0.1:4321")))
       (should-error (glassmacs-shiny--start "second" '("true") temporary-file-directory #'ignore)
                     :type 'user-error)
       (glassmacs-shiny-stop)
       (should-not glassmacs-shiny-url)))))

(ert-deftest glassmacs-documents-shiny-reload-restarts-the-last-app ()
  (glassmacs-documents-test--fresh-shiny
   (let ((starts 0))
     (cl-letf (((symbol-function 'message) #'ignore))
       (letrec ((restart (lambda ()
                        (cl-incf starts)
                        (glassmacs-shiny--start "test" '("sleep" "30")
                                                temporary-file-directory restart))))
         (funcall restart)
         (let ((first glassmacs-shiny-process))
           (glassmacs-shiny-reload)
           (should (= starts 2))
           (should-not (process-live-p first))
           (should (process-live-p glassmacs-shiny-process))))))))

(ert-deftest glassmacs-documents-detects-interactive-documents ()
  (dolist (case '(("---\ntitle: A\nruntime: shiny\n---\nText\n" . t)
                  ("---\nruntime: shiny_prerendered\n---\n" . t)
                  ("---\ntitle: Q\nserver: shiny\n---\n" . t)
                  ("---\ntitle: A\noutput: html_document\n---\nruntime: shiny\n" . nil)
                  ("No front matter\nruntime: shiny\n" . nil)))
    (with-temp-buffer
      (insert (car case))
      (should (eq (and (glassmacs-shiny-interactive-document-p) t) (cdr case))))))

(ert-deftest glassmacs-documents-run-interactive-document-commands ()
  (dolist (case '(("/tmp/app/report.Rmd" "Rscript" "rmarkdown::run")
                  ("/tmp/app/report.qmd" "quarto" "preview")))
    (let (started)
      (with-temp-buffer
        (insert "---\nruntime: shiny\n---\n")
        (set-buffer-modified-p nil)
        (setq buffer-file-name (car case))
        (cl-letf (((symbol-function 'executable-find) (lambda (p) (concat "/bin/" p)))
                  ((symbol-function 'glassmacs-shiny--start)
                   (lambda (_description command directory _restart)
                     (setq started (list command directory)))))
          (glassmacs-run-interactive-document))
        (setq buffer-file-name nil))
      (let ((command (car started)))
        (should (equal (car command) (concat "/bin/" (nth 1 case))))
        (should (cl-some (lambda (arg) (string-match-p (nth 2 case) arg)) command))
        ;; The app listens only locally, and Glassmacs opens the browser.
        (should (cl-some (lambda (arg) (string-match-p "127\\.0\\.0\\.1\\|--no-browser" arg))
                         command))
        (should (equal (nth 1 started) "/tmp/app/"))))))

(ert-deftest glassmacs-documents-render-runs-interactive-documents ()
  (glassmacs-chunks-test--in-document "app.Rmd" "---\nruntime: shiny\n---\n"
    (let (ran)
      (cl-letf (((symbol-function 'glassmacs-run-interactive-document)
                 (lambda () (setq ran t)))
                ((symbol-function 'glassmacs-render-rmarkdown)
                 (lambda () (ert-fail "must not render an interactive document"))))
        (glassmacs-chunks-render))
      (should ran))))

;;; With real R packages

(defun glassmacs-documents-test--r-package-p (package)
  "Return non-nil when Rscript and the R PACKAGE are installed."
  (and (executable-find "Rscript")
       (zerop (call-process "Rscript" nil nil nil "-e"
                            (format "quit(status = !requireNamespace('%s', quietly = TRUE))"
                                    package)))))

(ert-deftest glassmacs-documents-real-shiny-app-serves-at-its-reported-address ()
  (unless (glassmacs-documents-test--r-package-p "shiny")
    (ert-skip "R and the shiny package are not installed"))
  (require 'url)
  (let ((directory (make-temp-file "glassmacs-shiny-app-" t)))
    (unwind-protect
        (glassmacs-documents-test--fresh-shiny
         (write-region "library(shiny)\nshinyApp(fluidPage('glassmacs-shiny-ok'), function(input, output) {})\n"
                       nil (expand-file-name "app.R" directory))
         (cl-letf (((symbol-function 'browse-url) #'ignore)
                   ((symbol-function 'message) #'ignore))
           (with-temp-buffer
             (setq default-directory (file-name-as-directory directory))
             (glassmacs-shiny-start))
           (let ((deadline (+ (float-time) 60)))
             (while (and (not glassmacs-shiny-url) (< (float-time) deadline)
                         (process-live-p glassmacs-shiny-process))
               (accept-process-output nil 0.2)))
           (should (string-match-p "\\`http://127\\.0\\.0\\.1:[0-9]+" glassmacs-shiny-url))
           ;; Fetch the page directly, not through any configured proxy.
           (let* ((url-proxy-services nil)
                  (page (url-retrieve-synchronously glassmacs-shiny-url t t 30)))
             (should page)
             (with-current-buffer page
               (should (string-match-p "glassmacs-shiny-ok" (buffer-string))))
             (kill-buffer page))
           (glassmacs-shiny-stop)))
      (delete-directory directory t))))

(ert-deftest glassmacs-documents-real-rmarkdown-render-opens-html ()
  (unless (and (glassmacs-documents-test--r-package-p "rmarkdown")
               (executable-find "pandoc"))
    (ert-skip "R, rmarkdown and pandoc are not installed"))
  (let* ((directory (make-temp-file "glassmacs-render-" t))
         (file (expand-file-name "report.Rmd" directory))
         (glassmacs--current-process nil)
         opened)
    (unwind-protect
        (progn
          (write-region "---\ntitle: Glassmacs\noutput: html_document\n---\n\n```{r}\n6 * 7\n```\n"
                        nil file)
          (with-current-buffer (find-file-noselect file)
            (cl-letf (((symbol-function 'glassmacs-open-rendered-output)
                       (lambda (output) (setq opened output)))
                      ((symbol-function 'display-buffer) #'ignore)
                      ((symbol-function 'message) #'ignore))
              (let ((process (glassmacs-render-rmarkdown))
                    (deadline (+ (float-time) 120)))
                (while (and (process-live-p process) (< (float-time) deadline))
                  (accept-process-output process 0.2))
                (accept-process-output nil 0.2)))
            (kill-buffer))
          (should (equal opened (expand-file-name "report.html" directory)))
          (should (file-exists-p opened)))
      (delete-directory directory t))))

(provide 'test-glassmacs-documents)
;;; test-glassmacs-documents.el ends here
