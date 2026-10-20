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
- SSH/TRAMP uses built-in TRAMP and local OpenSSH; Mosh is optional, and tmux remains external.

## Test and compile

Run ERT in isolated batch mode:

```sh
./scripts/test
```

GitHub Actions runs the ERT suite, including remote-workflow stubs, and byte-compiles all Lisp modules on Ubuntu
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

`tests/test-glassmacs-sessions.el` covers sessions and the queue with mocked
sending against throwaway processes, plus `glassmacs-sessions-integration-real-ess`,
which skips unless R and ESS are discoverable (`GLASSMACS_SKIP_INTEGRATION=1`
forces a skip). To run it against a system ESS, add `-L <ess directory>` to the
`emacs` command in `scripts/test`.

Remote tests use constructed TRAMP paths and mocked commands, not a real SSH server. See the optional manual SSH procedure in [R workflows](r-workflows.md).

For a real ESS/R integration check, install ESS and R, start Glassmacs, open an
R file, run `M-x glassmacs-r-start`, and evaluate `1 + 1`. Rendering tests
likewise require R packages or the Quarto CLI. GUI key behavior must be checked
on macOS with a graphical Cocoa Emacs; Linux batch tests do not validate it.
Native macOS GUI behavior, including hybrid shortcuts, appearance, and frame
handling, remains a manual verification item.

## Installation, isolated launch, and dependencies

**Required:** upstream GNU Emacs. GNU Emacs 29 or newer is recommended; the
launcher looks for `emacs` on `PATH`. Set `GLASSMACS_EMACS` to an executable path
or command name to select another installation. A graphical macOS launch needs
a graphical Emacs build; terminal and batch use need no graphical display.

From the repository checkout:

```sh
./scripts/glassmacs                 # graphical startup where supported
./scripts/glassmacs -nw             # terminal startup
./scripts/glassmacs some-file.R
./scripts/glassmacs /ssh:research:/home/user/project/analysis.R
```

These are ordinary Emacs command-line arguments. GNU Emacs handles file names
and TRAMP paths. Opening a remote path is an explicit user action; startup does
not establish SSH connections, start R, or execute project configuration.

Glassmacs starts Emacs with `-Q`, loads this checkout's `init.el`, and puts
`user-emacs-directory`, packages, and the `custom-file` under the isolated
Glassmacs home. The default is `~/.config/glassmacs`; set `GLASSMACS_HOME` before
launch to choose another directory. Optional user customizations belong in
`$GLASSMACS_HOME/custom.el`. Ordinary GNU Emacs and Aquamacs configuration is
neither loaded nor modified. To return to ordinary GNU Emacs, start it directly
with `emacs` rather than `./scripts/glassmacs`.

The core editor has no required Emacs packages beyond GNU Emacs. ESS and
document-editing packages (markdown-mode, Quarto mode, polymode/poly-R, and
AUCTeX) are optional. R/Rscript, Quarto, TeX, OpenSSH and Mosh are external
optional tools; SSH/TRAMP uses Emacs' built-in TRAMP and local OpenSSH. Plain
text editing and local startup do not require these tools. Glassmacs reports
missing optional tools when the related commands are invoked.

To install the optional Emacs packages explicitly, run `./scripts/bootstrap`.
It installs packages that are missing under the isolated package directory and
requires network access when installation is needed. It does not run
automatically on startup. After the chosen packages are installed, normal
startup does not refresh archives or initiate network access. Package archives
are not version-locked, so this setup is not yet reproducible across dates or
machines.

### Manual smoke test

1. Launch `./scripts/glassmacs`, open a local `.txt` file, edit it, and save it.
2. Launch `./scripts/glassmacs -nw` and verify ordinary text editing and saving.
3. Start with an empty `GLASSMACS_HOME` and no R/ESS or document tools; verify
   startup and plain-text editing still work.
4. If you have a configured SSH alias, verify launch itself made no connection,
   then explicitly open a test TRAMP path.
5. Launch ordinary `emacs` and verify it still uses the existing Emacs setup.

### Troubleshooting and verification limits

- If startup reports GNU Emacs is missing, install it or set `GLASSMACS_EMACS`
  to its executable. `GLASSMACS_EMACS` selects an executable, not extra
  command-line options; pass options such as `-nw` to the Glassmacs launcher.
- If ESS or a document mode is unavailable, run `./scripts/bootstrap` while
  online. If an external tool is missing, install it separately and ensure it
  is on `PATH`; Glassmacs does not install R, Quarto, TeX, SSH or Mosh.
- If package installation fails offline, plain-text startup remains available;
  retry bootstrap when network access is available.
- Linux ERT and batch checks do not establish Cocoa behavior. Native macOS GUI
  startup, Finder/LaunchServices integration, hybrid shortcut event handling,
  appearance, and frame behavior have not been verified by Linux tests and
  require a graphical macOS Emacs smoke test. This distribution does not
  include a packaged/signed/notarized macOS application.

## Execution architecture verification plan

Basic SSH/TRAMP file/shell operations are implemented; remote execution backends and remote ESS remain planned in [architecture](architecture.md). Extend CI to test routing selection, session identity, process lifecycle, argv handling and cwd mapping with no real SSH credentials. Add opt-in integration tests using an explicitly provisioned SSH test host for TRAMP/ESS; distinguish those results from Linux mocks and native macOS GUI checks.

Benchmark against equivalent local Terminal and remote SSH workflows using matched R versions, packages, input and environment. Measure Emacs/Glassmacs startup, R process startup, first versus subsequent ESS round trips, direct Rscript, large-output handling, SSH connection/setup, warmed remote evaluation, rendering and responsiveness under load. Separate wall-clock R computation from GUI/process/network overhead and report repeat counts and variance. Do not claim a performance improvement until measured.

Security test cases must cover paths with whitespace, Unicode and shell metacharacters, SSH failures, host-key validation behavior, port conflicts and cleanup. Do not run tests against an implicit server or require secrets in public CI.
