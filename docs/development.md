# Development

> **Document ID:** DOC-DEV  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-20
> **Coverage:** Contributor setup, testing and verification workflow  
> **Supersedes:** None


## Requirements

- GNU Emacs 29 or newer is recommended. Emacs Lisp tests use ERT.
- R, Quarto, and optional Emacs packages are only needed for their respective
  integrations.

## Test and compile

Run ERT in isolated batch mode:

```sh
./scripts/test
```

GitHub Actions runs the ERT suite and byte-compiles all Lisp modules on Ubuntu
24.04 with its `emacs-nox` package. The CI environment does not install R, ESS,
Quarto, or TeX; integration tests requiring optional tools are skipped when
those dependencies are unavailable. CI verifies batch behavior only.

For PR #4, the workflow was created but the GitHub Actions run ended with
`action_required` before any jobs were created. This is an approval/permissions
gate outside the workflow definition, not a passing or failing test result.
Local checks are reported separately from GitHub Actions status.

Byte-compile the Lisp modules with `.elc` output redirected to the system
temporary directory:

```sh
emacs -Q --batch -l init.el \
  --eval '(let ((byte-compile-dest-file-function
                 (lambda (file)
                   (expand-file-name (file-name-nondirectory file)
                                     temporary-file-directory))))
            (dolist (file (directory-files "lisp" t "\\.el$"))
              (byte-compile-file file)))'
```

For a real ESS/R integration check, install ESS and R, start Glassmacs, open an
R file, run `M-x glassmacs-r-start`, and evaluate `1 + 1`. Rendering tests
likewise require R packages or the Quarto CLI. GUI key behavior must be checked
on macOS with a graphical Cocoa Emacs; Linux batch tests do not validate it.
Native macOS GUI behavior, including hybrid shortcuts, appearance, and frame
handling, remains a manual verification item.

## Isolated launch and dependencies

`./scripts/glassmacs` launches upstream Emacs with `-Q`, then loads this
checkout's `init.el`. `./scripts/bootstrap` installs current package versions
into the separate Glassmacs package directory. Set `GLASSMACS_HOME` before
launch/bootstrap to choose another location. Optional customizations can be
placed in `$GLASSMACS_HOME/custom.el` (default `~/.config/glassmacs/custom.el`).
This prevents Glassmacs from rewriting a pre-existing Emacs init or Aquamacs
preferences. ERT exercises this launcher with a temporary `GLASSMACS_HOME` and
a separate simulated ordinary Emacs home, and verifies the ordinary home files
are unchanged.

The package archives are not version-locked in this initial milestone. Tests
should be run with the project's supported Emacs version and with optional
dependencies absent as well as installed when practical.

## Execution architecture verification plan

Future execution backends are specified in [architecture](architecture.md), not yet implemented. Extend CI to test routing selection, session identity, process lifecycle, argv handling and cwd mapping with no real SSH credentials. Add opt-in integration tests using an explicitly provisioned SSH test host for TRAMP/ESS; distinguish those results from Linux mocks and native macOS GUI checks.

Benchmark against equivalent local Terminal and remote SSH workflows using matched R versions, packages, input and environment. Measure Emacs/Glassmacs startup, R process startup, first versus subsequent ESS round trips, direct Rscript, large-output handling, SSH connection/setup, warmed remote evaluation, rendering and responsiveness under load. Separate wall-clock R computation from GUI/process/network overhead and report repeat counts and variance. Do not claim a performance improvement until measured.

Security test cases must cover paths with whitespace, Unicode and shell metacharacters, SSH failures, host-key validation behavior, port conflicts and cleanup. Do not run tests against an implicit server or require secrets in public CI.
