# Standalone macOS application

> **Document ID:** DOC-MAC-LAUNCHER<br>
> **Status:** Informational<br>
> **Owner:** Glassmacs maintainers<br>
> **Effective date:** 2026-10-20<br>
> **Last reviewed:** 2026-10-20<br>
> **Coverage:** Building and operating the standalone Cocoa application<br>
> **Supersedes:** Optional Swift launcher guide

## Architecture decision

Glassmacs is assembled as one top-level `Glassmacs.app` using the complete
upstream Cocoa GNU Emacs application bundle as its base. The build preserves
Emacs's `Contents/MacOS/Emacs`, Cocoa resources, Lisp runtime, and upstream
bundle metadata, then applies the Glassmacs bundle identifier, display name,
and document declarations. Glassmacs Lisp and its bootstrap are copied into
`Contents/Resources/Glassmacs`.

`GlassmacsBootstrap` is the bundle's LaunchServices executable. It sets the
Glassmacs data directory, then calls `execv` on the bundled Emacs executable
with `-Q --load <bundle>/Contents/Resources/Glassmacs/init.el`. This replaces
the bootstrap process rather than keeping a Swift parent and an Emacs child.
Emacs remains the only editor and owns the Cocoa event loop, frames, buffers,
menus, document state, and ESS processes. This avoids the unresolved
two-application identity of an AppKit helper that launches a nested
`Emacs.app`; it does **not** by itself prove how LaunchServices, Dock, or open
document events behave after process replacement. Those behaviors require GUI
verification on macOS.

This decision is informed by GNU Emacs's Cocoa bundle structure and
self-contained installation instructions: the app bundle includes the
executable, runtime resources, and application metadata, and a self-contained
bundle can be moved. Renaming only `Emacs.app` would retain GNU's bundle ID;
nesting it would leave the inner Emacs app identity. The build therefore
customizes the outer bundle metadata and validates the concrete executable's
Mach-O dependencies rather than assuming that every Emacs build is
self-contained. References:

- [GNU Emacs macOS build/install instructions](https://github.com/emacs-mirror/emacs/blob/master/nextstep/INSTALL)
- [GNU Emacs Cocoa application Info.plist template](https://github.com/emacs-mirror/emacs/blob/master/nextstep/templates/Info.plist.in)
- [GNU Emacs Cocoa application bundle Makefile](https://github.com/emacs-mirror/emacs/blob/master/nextstep/Makefile.in)
- [Pinned Cocoa Emacs release source and checksum](../macos/upstream-emacs.env), mirrored by [Homebrew Cask `emacs-app`](https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/e/emacs-app.rb)

The configured document types are `.R`, `.r`, `.Rmd`, `.qmd`, and `.Rnw`, with
alternate handler rank. The app does not silently become a user's default
handler. Finder registration, Dock identity, reopen behavior, file event
routing, and activation remain manual macOS GUI checks.

## Build and install

Build prerequisites: macOS 13 or newer, Swift 6, Python 3, and standard macOS
tools `curl`, `shasum`, `hdiutil`, `ditto`, `plutil`, `PlistBuddy`, and `otool`.
The default build downloads a pinned Cocoa GNU Emacs release archive and checks
its SHA-256 before copying it. To build from a separately obtained compatible
Cocoa Emacs bundle instead, set `GLASSMACS_UPSTREAM_EMACS_APP` to its absolute
`.app` path; the build does not modify that source bundle.

```sh
./scripts/build-macos-app
./scripts/validate-macos-app build/Glassmacs.app
```

The result is `build/Glassmacs.app`. The build copies only `init.el`, `lisp/`,
and the package bootstrap into the bundle; it does not depend on the source
checkout at runtime. The validation script checks bundle metadata, document
extensions, required files, direct executable dependencies, and a batch startup
of the bundled Emacs. It rejects absolute non-system library dependencies and
non-relocatable runtime search paths. CI additionally runs Swift tests and ERT,
tests the bundled configuration, relocates the app, and produces a downloadable
ZIP artifact.

Drag `Glassmacs.app` into `/Applications` (or another location) to install.
Developer ID signing is supported as a separate, opt-in step. The build itself
does not sign with a personal identity and notarization is not yet automated.
On managed Macs requiring identified-developer signatures, **sign before
running the validator**, because validation launches bundled Emacs:

```sh
./scripts/build-macos-app
GLASSMACS_SIGN_IDENTITY="<Developer ID Application certificate SHA-1>" \\
  bash ./scripts/sign-macos-app build/Glassmacs.app
./scripts/validate-macos-app build/Glassmacs.app
```

The signing script signs regular Mach-O files within the bundle, then the
outer application, using hardened runtime and a secure timestamp. It verifies
the resulting bundle. Do not modify the bundle after signing. Signatures alone
do not imply notarization or compliance with every enterprise policy; perform
launch tests and notarize before public distribution. The workflow does not
set the app as a default document handler.

## User data and R setup

The app's default writable state is
`~/Library/Application Support/Glassmacs`. Package downloads, `custom.el`, and
generated state are written there, never into the app bundle. Setting
`GLASSMACS_HOME` to an absolute path overrides this location. The development
launcher `scripts/glassmacs` retains its existing default,
`~/.config/glassmacs`.

On first use, install the optional ESS and document packages explicitly:

```sh
GLASSMACS_HOME="$HOME/Library/Application Support/Glassmacs" \
GLASSMACS_EMACS="/Applications/Glassmacs.app/Contents/MacOS/Emacs" \
  "/Applications/Glassmacs.app/Contents/Resources/Glassmacs/scripts/bootstrap"
```

This step requires network access when packages are missing. It uses the
isolated Glassmacs package directory; startup itself does not install packages.
R, Quarto, TeX, and other command-line tools remain separate dependencies. Set
`glassmacs-r-executable` in
`~/Library/Application Support/Glassmacs/custom.el` if R is not found on the
app's inherited `PATH`, for example:

```elisp
(setq glassmacs-r-executable "/opt/homebrew/bin/R")
```

`GLASSMACS_HOME` can also be set in the environment used to launch the app.
Native Quartz graphics are supplied by the installed R build; Glassmacs does
not add a graphics device or R execution backend. ESS remains responsible for
process readiness and evaluation. The documented split-prompt limitation is
unchanged.

## Launch and diagnostics

Launch `Glassmacs.app` from Finder, Spotlight, or the Dock. For terminal
diagnostics, the bundle bootstrap forwards its command-line arguments:

```sh
"/Applications/Glassmacs.app/Contents/MacOS/GlassmacsBootstrap" \
  --batch --eval '(princ emacs-version)'
```

Once Emacs starts, use `M-x glassmacs-diagnostics`, inspect `*Messages*` and
`*Warnings*`, and check package initialization errors. Bootstrap failures are
written to standard error; when launched from Finder, inspect them in Console
if available. To debug a build, run
`./scripts/validate-macos-app /path/to/Glassmacs.app` and inspect the Emacs
binary with `otool -L`.

## Verification and limitations

The macOS CI job validates build inputs, bundle structure and metadata, direct
Mach-O dependencies, Swift tests, batch startup, existing ERT tests, and app
relocation. These are **build and batch checks, not interactive GUI tests**.
This repository change has not been exercised on a macOS GUI. Therefore none of
the following are claimed as verified: Finder or Dock launch, one coherent
Dock/application-switcher identity after `execv`, reopening, LaunchServices
document delivery, multiple document opens, policy-aware new-frame/new-tab
behavior for Finder opens, save prompts, menus/shortcuts, interactive ESS,
multiple R sessions, source-buffer targets/queues, editable history, local
output suppression, or native Quartz `plot(cars)`.

Before calling those behaviors verified, manually test on supported macOS:

1. Copy the app to `/Applications`, launch from Finder, Dock, and Spotlight,
   and confirm one Glassmacs identity and a working reopen.
2. Open `.R`, `.Rmd`, `.qmd`, and `.Rnw` files from Finder, including paths with
   spaces and Unicode; open several documents and confirm no unintended
   duplicate Emacs instance and that the configured frame/tab policy is used.
3. Edit an unsaved file and quit through Emacs; confirm the save prompt appears.
   Check that launching/opening another document does not terminate Emacs.
4. With R and ESS installed, start multiple sessions, verify explicit
   source-buffer execution targets and queued commands, edit command history,
   exercise output suppression, and evaluate `plot(cars)` using the installed
   R's native Quartz device.
5. Check native menus and keyboard shortcuts, plus app startup after moving the
   bundle to a different directory.

Known limitations: the app is not signed by default and is not notarized; LaunchServices may
not select it as the default document handler; package versions are not locked;
R and optional command-line programs are not bundled; and GUI behavior remains
unverified until the manual checks above are completed. This milestone does
not add remote ESS, PTY output protection, or a new R backend.

The pinned input is a third-party Cocoa build of GNU Emacs. The builder retains
its bundle resources and license notices, but this CI artifact is not a formal
release: before broader redistribution, audit that exact build's patches and
provide the corresponding source and notices required by its licenses.
