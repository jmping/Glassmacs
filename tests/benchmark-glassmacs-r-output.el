;;; benchmark-glassmacs-r-output.el --- Output filter stress benchmark -*- lexical-binding: t; -*-

(require 'comint)
(require 'glassmacs-sessions)

(defun glassmacs-r-output-benchmark--command-output (program &rest arguments)
  "Return PROGRAM output for ARGUMENTS, or \"unavailable\"."
  (with-temp-buffer
    (if (and (executable-find program)
             (zerop (apply #'process-file program nil t nil arguments)))
        (string-trim (buffer-string))
      "unavailable")))

(defun glassmacs-r-output-benchmark--memory ()
  "Return available Emacs allocation counters."
  (if (fboundp 'memory-use-counts)
      (memory-use-counts)
    "unavailable"))

(defun glassmacs-r-output-benchmark-run ()
  "Run reproducible large-chunk and repeated-small-chunk filter timings."
  (interactive)
  (let* ((ess-version
          (when (and (locate-library "ess") (require 'ess nil t)
                     (fboundp 'ess-version))
            (ess-version)))
         (cpu (glassmacs-r-output-benchmark--command-output
               "awk" "-F:"
               "/model name/{gsub(/^ /,\"\",$2); print $2; exit}"
               "/proc/cpuinfo"))
         (buffer (generate-new-buffer " *Glassmacs R Output Benchmark*"))
         process)
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (comint-mode)
            (setq-local inferior-ess-primary-prompt "> "
                        inferior-ess-secondary-prompt "+ ")
            (glassmacs-r--configure-output-protection))
          (setq process
                (make-process :name "glassmacs-r-output-benchmark"
                              :buffer buffer :command '("cat")
                              :connection-type 'pipe :noquery t))
          (process-put process 'busy t)
          (with-current-buffer buffer
            (let* ((chunk (make-string (* 8 1024 1024) ?x))
                   (memory-before (glassmacs-r-output-benchmark--memory))
                   (start (float-time))
                   (filtered (glassmacs-r--filter-output chunk))
                   (large-chunk-seconds (- (float-time) start))
                   (large-chunk-buffer-size (length filtered))
                   (small-chunk (make-string 1024 ?y))
                   (small-chunk-count 20480)
                   small-start
                   (small-output-length 0))
              (goto-char (process-mark process))
              (insert filtered)
              (set-marker (process-mark process) (point))
              (erase-buffer)
              (set-marker (process-mark process) (point-min))
              (glassmacs-r--reset-output-state)
              (process-put process 'busy t)
              (setq small-start (float-time))
              (dotimes (_ small-chunk-count)
                (setq filtered (glassmacs-r--filter-output small-chunk)
                      small-output-length (+ small-output-length
                                              (length filtered)))
                (goto-char (process-mark process))
                (insert filtered)
                (set-marker (process-mark process) (point)))
              (let ((small-chunk-seconds (- (float-time) small-start))
                    (memory-after (glassmacs-r-output-benchmark--memory)))
                (comint-truncate-buffer)
                (process-put process 'busy nil)
                (setq start (float-time)
                      filtered (glassmacs-r--filter-output "> "))
                (let ((recovery-seconds (- (float-time) start)))
                  (message
                   (concat
                    "Glassmacs output-filter benchmark\n"
                    "Host: %s\nCPU: %s\nOS: %s / %s\nEmacs: %s\nESS: %s\nR: %s\n"
                    "Budget: %d characters; retained-line limit: %d\n"
                    "Single 8 MiB chunk: %.6f s; inserted characters: %d\n"
                    "20,480 x 1 KiB chunks (20 MiB input): %.6f s; inserted characters: %d\n"
                    "Primary-prompt recovery: %.6f s\n"
                    "Final buffer characters: %d; suppression reset: %s\n"
                    "Emacs allocation counters before/after: %S / %S")
                   (system-name)
                   (if (string-empty-p cpu) system-configuration cpu)
                   system-type
                   (or (and (boundp 'operating-system-release)
                            operating-system-release)
                       "unknown")
                   emacs-version (or ess-version "unavailable")
                   (glassmacs-r-output-benchmark--command-output "R" "--version")
                   glassmacs-r-output-budget
                   glassmacs-r-output-buffer-maximum-lines
                   large-chunk-seconds large-chunk-buffer-size
                   small-chunk-seconds small-output-length recovery-seconds
                   (buffer-size) (not glassmacs-r--output-suppressed)
                   memory-before memory-after))))))
      (when (and process (process-live-p process))
        (delete-process process))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(provide 'benchmark-glassmacs-r-output)
;;; benchmark-glassmacs-r-output.el ends here
