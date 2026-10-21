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

**Known Emacs 31 macOS test failure:** the full suite currently fails
`glassmacs-startup-does-not-touch-ordinary-emacs-home` because an Emacs 31
subprocess creates an `ordinary-home/.emacs.d/eln-cache/...trampoline...eln`
file while Glassmacs is starting with `-Q` and `GLASSMACS_HOME` set. This is a
native-compilation cache-isolation issue; it has not been resolved. Do not
count the full suite as green or suppress the failure by weakening native
compilation security.

GitHub Actions runs the ERT suite, including remote-workflow stubs, and byte-compiles all Lisp modules on Ubuntu
24.04 with `emacs-nox`. A separate integration job installs `r-base-core` and
`elpa-ess`, adds the packaged ESS directory to `EMACSLOADPATH`, and runs the
same suite against real R/ESS processes and a base-graphics PNG smoke test.
Neither job verifies a native macOS graphics device; the real ESS/R check only
establishes Linux process/evaluation behavior. Quarto and TeX remain optional
and are skipped unless available.

Run `./scripts/benchmark-r-output` for deterministic output-filter stress
measurements. It prints host/CPU, OS, Emacs, optional ESS/R versions; elapsed
time for one 8 MiB chunk and 20,480 1 KiB chunks; inserted character counts;
primary-prompt filter recovery time; final buffer size; and available Emacs
allocation counters. It uses a synthetic process and does not measure ESS
process-filter throughput, backpressure, GUI responsiveness, or physical
allocation peaks. The real ESS/R ERT tests separately exercise process recovery
and queued-command dispatch.

The `macos-launcher` job runs Swift tests, builds the standalone bundle from a
pinned Cocoa Emacs archive, validates bundle structure and direct executable
dependencies, runs ERT with the bundled Emacs, starts the bundled Glassmacs
configuration, verifies relocation, and uploads an app ZIP. These are build and
batch checks only; they do not exercise Finder, LaunchServices, Dock identity,
Cocoa windows, native menus, or interactive Emacs behavior. See the
[macOS application guide](macos-launcher.md) for build inputs and manual GUI
verification steps. The portable Python tests mock codesign, notarytool,
stapler, and Gatekeeper to cover release ordering and failure behavior without
Apple credentials.

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
sending against throwaway processes, plus real ESS/R tests for output
suppression, recovery, interruption and concurrent sessions. These skip unless
R and ESS are discoverable (`GLASSMACS_SKIP_INTEGRATION=1` forces a skip). The
dedicated CI job supplies these dependencies. To run locally against a system
ESS, add its directory to `EMACSLOADPATH` when invoking `scripts/test`.

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

On macOS, use a graphical Cocoa GNU Emacs executable. If it is not on the
launching shell's `PATH`, select the executable inside the installed app bundle:

```sh
GLASSMACS_EMACS="/Applications/Emacs.app/Contents/MacOS/Emacs" ./scripts/glassmacs
```

Adjust the path to match the installed app. This starts the upstream Emacs GUI
with the checkout's Glassmacs configuration; it is not a standalone Glassmacs
app or an in-process Swift integration.

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

For the bundled macOS app, automatic native JIT compilation is disabled before
Glassmacs modules/package initialization; `GLASSMACS_NATIVE_COMP=1` opts into
JIT for controlled testing. The bootstrap exports `MACOSX_DEPLOYMENT_TARGET`
13.0 by default, matching the app's minimum supported macOS version, while
preserving a valid explicit override. See the
[macOS application guide](macos-launcher.md#native-lisp-compilation) for the
separate generated-`.eln` Team ID limitation and release signing/notarization.

The core editor has no required Emacs packages beyond GNU Emacs. ESS and
document-editing packages (markdown-mode, Quarto mode, polymode/poly-R, and
AUCTeX) are optional. R/Rscript, Quarto, TeX, OpenSSH and Mosh are external
optional tools; SSH/TRAMP uses Emacs' built-in TRAMP and local OpenSSH. Plain
text editing and local startup do not require these tools. Glassmacs reports
missing optional tools when the related commands are invoked.

On a graphical macOS session, Glassmacs Open File (`M-x glassmacs-open-file`,
Command-O, and File > Open) opens ordinary documents in a separate frame by
default; `glassmacs-new-document` (Command-N) uses the same policy. Save changes
to `glassmacs-document-opening-policy` through Customize for future sessions,
or set it in `$GLASSMACS_HOME/custom.el`, for example:

```elisp
(setq glassmacs-document-opening-policy 'new-tab)
```

Use `reuse-current` instead of `new-tab` to keep opening in the current frame/tab.
Special-mode, Dired, comint, and process-backed buffers and non-graphical
sessions are not redirected.
Cocoa `[ns-open-file]` events use the same policy through a narrow adapter around
Emacs `ns-find-file`; this depends on the pinned Cocoa Emacs NS event interface.
Existing visible document views are focused instead of duplicated. ERT covers
the Lisp policy and a simulated NS event, but Finder delivery, startup ordering,
and Cocoa frame behavior have not been manually verified on macOS.

The standalone bundle also loads a small AppKit module that installs Emacs's
native application-reopen delegate callback. The callback routes a Dock reopen
with no visible windows into Emacs's normal `ns-new-frame` event, which Glassmacs
maps to restoring the retained final frame or creating one. Reopen is handled
through that event rather than a competing focus hook, so Cocoa session
restoration of already-visible windows does not create an extra frame. The Lisp
lifecycle tests cover these command decisions; they do not validate runtime
Objective-C method installation or Dock delivery. Build and sign the standalone
bundle before the required interactive lifecycle check.

Run `M-x glassmacs-diagnostics` for a local report of Emacs/OS/window-system,
Glassmacs home, ESS/R/Rscript availability and graphics guidance. It does not
include environment variables, credentials, process output or project contents,
and it does not run optional tools.

For R plotting, see the [ESS graphics smoke path](r-workflows.md#ess-r-graphics-smoke-path).
It uses ordinary R graphics devices and does not add a Glassmacs plot viewer or
make X11/XQuartz mandatory.

To install the optional Emacs packages explicitly, run `./scripts/bootstrap`.
It installs packages that are missing under the isolated package directory and
requires network access when installation is needed. It does not run
automatically on startup. After the chosen packages are installed, normal
startup does not refresh archives or initiate network access. Package archives
are not version-locked, so this setup is not yet reproducible across dates or
machines.

### Manual smoke test

Maintainer dogfood checklist (three checks):

1. Launch the graphical macOS build, edit and save a local text file, and verify
   a second ordinary document opens in a separate frame. Change the policy to
   `new-tab` or `reuse-current` and confirm it applies to later opens.
2. Start an ESS R session and evaluate `1 + 1` from an R source buffer.
3. Evaluate `plot(cars)` in ESS and verify the native macOS graphics device
   appears. If `ggplot2` is installed, also try the optional example in
   [R workflows](r-workflows.md#ess-r-graphics-smoke-path).

This checklist requires a graphical macOS Emacs build and has not been run in
the Linux development environment used for this change.

### Troubleshooting and verification limits

- If startup reports GNU Emacs is missing, install it or set `GLASSMACS_EMACS`
  to its executable. `GLASSMACS_EMACS` selects an executable, not extra
  command-line options; pass options such as `-nw` to the Glassmacs launcher.
- If ESS or a document mode is unavailable, run `./scripts/bootstrap` while
  online. If an external tool is missing, install it separately and ensure it
  is on `PATH`; Glassmacs does not install R, Quarto, TeX, SSH or Mosh.
- If package installation fails offline, plain-text startup remains available;
  retry bootstrap when network access is available.
- If the standalone app fails to start, run
  `./scripts/validate-macos-app /path/to/Glassmacs.app`, check Console for
  bootstrap errors, and inspect the bundled Emacs binary with `otool -L`.
  `M-x glassmacs-diagnostics` reports the active window system and whether ESS,
  R and Rscript are discoverable after Emacs starts.
- If `plot(cars)` does not open a native graphics window, check the R build's
  native graphics capability from the ESS console. Only try `X11()` when
  XQuartz and its display are installed and configured; Glassmacs does not
  select X11 or install XQuartz automatically.
- Linux ERT and batch checks do not establish Cocoa behavior. The app bundle is
  built and batch-validated in macOS CI, but Finder/Dock startup,
  LaunchServices integration, hybrid shortcut event handling, appearance, and
  actual frame behavior still require a graphical macOS smoke test. The app is
  not signed or notarized.

## Execution architecture verification plan

Basic SSH/TRAMP file/shell operations are implemented; remote execution backends and remote ESS remain planned in [architecture](architecture.md). Extend CI to test routing selection, session identity, process lifecycle, argv handling and cwd mapping with no real SSH credentials. Add opt-in integration tests using an explicitly provisioned SSH test host for TRAMP/ESS; distinguish those results from Linux mocks and native macOS GUI checks.

Benchmark against equivalent local Terminal and remote SSH workflows using matched R versions, packages, input and environment. Measure Emacs/Glassmacs startup, R process startup, first versus subsequent ESS round trips, direct Rscript, large-output handling, SSH connection/setup, warmed remote evaluation, rendering and responsiveness under load. Separate wall-clock R computation from GUI/process/network overhead and report repeat counts and variance. Do not claim a performance improvement until measured.

Security test cases must cover paths with whitespace, Unicode and shell metacharacters, SSH failures, host-key validation behavior, port conflicts and cleanup. Do not run tests against an implicit server or require secrets in public CI.
