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

### Dock icon and final-window lifecycle

Finder reads the bundle icon from `CFBundleIconFile`. Cocoa Emacs also has a
fallback initialization path that explicitly sets `NSApp.applicationIconImage`
from `icons/hicolor/128x128/apps/emacs.png` when the application activation
policy is prohibited (upstream `src/nsterm.m`). Emacs loads that image through
`src/nsimage.m`'s `image_find_image_file`, which searches
`data-directory/images` (upstream `src/image.c`). The observed GNU Emacs Dock
artwork indicates this fallback path is overriding Glassmacs's correct Finder
icon. The build now installs
`assets/icon/glass-gnu.png` at Emacs's expected data-image path,
`Contents/Resources/etc/images/icons/hicolor/128x128/apps/emacs.png`, before
any signing. This uses Emacs's existing image lookup rather than changing
Cocoa code or starting a second application.

Closing a Cocoa window deletes its Emacs frame; Emacs is also the process that
owns the application event loop. Deleting its final graphical frame therefore
can end the process and remove the Dock application. Glassmacs now intercepts
deletion of the final macOS graphical frame and makes that frame invisible
instead. It does not kill buffers or processes, and does not save or discard
buffer changes. Focus hooks restore and focus the retained frame when Emacs
receives focus; **⌘Q** remains bound to `save-buffers-kill-emacs`, preserving
Emacs's normal save and quit prompts. Nonfinal frames still delete normally.
`File → New Window` invokes Emacs's normal new-frame command.

The invisible-frame and focus-notification behavior is platform-specific and
has not yet been verified interactively on a physical Mac. If Dock activation
does not trigger the Emacs focus hooks on a supported macOS version, that
activation behavior requires a native Cocoa reopen callback; Glassmacs does
not add an AppKit helper process or patch the signed Emacs executable.

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
`.app` path; the build does not modify that source bundle. The supported minimum
is macOS 13.0 in SwiftPM, `LSMinimumSystemVersion`, and the bootstrap's default
native-compiler deployment target.

```sh
./scripts/build-macos-app
./scripts/validate-macos-app build/Glassmacs.app
```

The result is `build/Glassmacs.app`. The build copies only `init.el`, `lisp/`,
the package bootstrap, and the committed `assets/icon/Glassmacs.icns` into the
bundle; it does not depend on the source checkout at runtime. The validation
script checks bundle metadata and icon, document extensions, required files,
all bundled Mach-O dependencies and runtime search paths, and a batch startup
of the bundled Emacs. Use `GLASSMACS_SKIP_EMACS_STARTUP=1` to run structural
checks without launching an unsigned executable on a managed Mac; dependency
and startup-policy checks still run. CI additionally runs Swift tests and ERT,
tests the bundled configuration, relocates the app, and produces a downloadable
ZIP artifact.

Drag `Glassmacs.app` into `/Applications` (or another location) to install.
The ordinary build and validation do not require Developer ID credentials. To
sign a release, first validate the unsigned bundle, then select an installed
Developer ID Application identity by its certificate SHA-1:

```sh
./scripts/build-macos-app
GLASSMACS_SKIP_EMACS_STARTUP=1 ./scripts/validate-macos-app build/Glassmacs.app
GLASSMACS_SIGN_IDENTITY="<Developer ID Application certificate SHA-1>" \
  ./scripts/sign-macos-app build/Glassmacs.app
./scripts/validate-macos-app build/Glassmacs.app
```

The signing script signs nested Mach-O files first, signs bundled Emacs with
`macos/Glassmacs.entitlements.plist`, and signs the outer app with the same
entitlements. It uses Developer ID, hardened runtime, and a secure timestamp,
then requires `codesign --verify --deep --strict --verbose=2`. The only
entitlement is `com.apple.security.cs.disable-library-validation`; it is
included to reproduce the tested signing configuration, **not** because it
has been shown to fix runtime-generated `.eln` Team ID failures. It broadens
which libraries the signed process may load, so retain it only while needed by
this distribution. Do not modify the bundle after signing.

Inspect the signed Emacs executable with:

```sh
codesign -d --entitlements :- build/Glassmacs.app/Contents/MacOS/Emacs
codesign -dv --verbose=4 build/Glassmacs.app/Contents/MacOS/Emacs
codesign --verify --deep --strict --verbose=2 build/Glassmacs.app
```

The entitlements are not a substitute for signing runtime-generated native
libraries with the same Team ID. Glassmacs never signs generated `.eln` files
with a developer identity or distributes private keys.

## Notarization and distribution

Configure an Apple notarytool Keychain profile on the release Mac using Apple's
`xcrun notarytool store-credentials` workflow. Credentials stay in that
developer's Keychain; do not put Apple passwords, API keys, certificates, or
private keys in this repository or CI artifact. The profile name is an argument
and can be `Glassmacs` locally:

```sh
./scripts/notarize-macos-app build/Glassmacs.app Glassmacs
```

Optionally pass an output directory as the third argument. The script verifies
the Developer ID signature, creates `Glassmacs-notarization.zip` with `ditto`,
submits it with `notarytool --wait`, and requires an `Accepted` result and
submission ID before stapling. It then staples and validates the ticket,
requires Gatekeeper acceptance via `spctl --assess`, and only then writes the
final `Glassmacs-macOS.zip`, which contains the stapled app. The pre-notarization
archive and final distributable are separate. The app is not rebuilt or
re-signed between submission and stapling.

On a rejected submission, the script prints the submission ID and command
needed to retrieve Apple's diagnostics. Set `GLASSMACS_NOTARY_FETCH_LOG=1` to
request the log automatically:

```sh
xcrun notarytool log SUBMISSION_ID --keychain-profile Glassmacs
```

The release script and its mocked-tool regression tests do not contact Apple.
An actual notarization still requires a valid local Developer ID-signed app,
network access, and a configured Keychain profile.

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

### Native Lisp compilation

The bundled Emacs retains native-compilation support and can load compatible,
properly signed precompiled `.eln` files. By default Glassmacs disables
automatic native JIT compilation at the beginning of its `init.el`, before it
loads Glassmacs modules or initializes packages. Ordinary interpreted and
byte-compiled Emacs Lisp continue to work; this does not remove GCC JIT or
disable byte compilation.

The bootstrap exports `MACOSX_DEPLOYMENT_TARGET=13.0` unless the launching
environment already supplies a recognized numeric macOS target at or above the
supported macOS 13 minimum. The selected value is inherited by Emacs and
native-compilation subprocesses. The SDK/compiler must still support an
explicitly selected version. This default avoids the observed invalid
`-mmacosx-version-min=18.0` generated by GCC 14.3 on the tested system; it does
not change the bundle's minimum OS.

The bootstrap also sets the JIT policy with a command-line `--eval` before
loading the bundled init file; the init file repeats it before requiring any
Glassmacs module. To explicitly enable JIT while diagnosing a compatible setup,
launch with:

```sh
GLASSMACS_NATIVE_COMP=1 \
  "/Applications/Glassmacs.app/Contents/MacOS/GlassmacsBootstrap"
```

The setting is read before Glassmacs' package initialization. This mode is for
controlled developer testing, not a recommended end-user setting.

The separate `.eln` issue is a code-signing library-validation failure:
the tested Developer ID Emacs rejected a GCC-JIT-generated `.eln` without the
same Team ID, while signing that library with the same Developer ID allowed it
to load. Re-signing it ad hoc failed again. Disabling library validation on
Emacs and removing hardened runtime were also insufficient on the tested
machine. The cause is not conclusively known; organizational device policy is
only a possibility, not an established explanation. Glassmacs does not suppress
native-compilation errors, automatically sign generated libraries, require
end-user certificates, or claim that the entitlement resolves this failure.
JIT remains available for systems where both the compiler and generated
libraries are permitted.

Maintainer-reported local verification: setting the deployment target to 15.0
allowed GCC 14.3 native compilation on an Apple Silicon macOS 27.0.1 test
machine. A `.eln` signed with the same Developer ID Team ID as Emacs loaded on
that machine, while an ad-hoc `.eln` did not. This change does not reproduce
those macOS experiments in Linux CI; the 13.0 default follows the declared app
minimum and must be exercised with the packaged toolchain. If an older
development run left incompatible generated files, inspect and manually clear
only the Glassmacs cache after quitting Emacs:

```sh
find "$HOME/Library/Application Support/Glassmacs/eln-cache" \
  -type f -name '*.eln' -delete
```

Do not clear the bundled Emacs native Lisp directories: properly signed
precompiled libraries remain eligible to load.

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

1. Copy the app to `/Applications` and confirm Finder displays the Glassmacs
   icon.
2. Launch Glassmacs and confirm exactly one Dock icon displays Glassmacs
   artwork, not the GNU Emacs icon.
3. Close the final window and confirm the application remains in the Dock and
   menu bar without a visible window.
4. Click the Dock icon and confirm the existing editing frame returns. Create a
   new frame through `File → New Window`, close multiple frames in turn, and
   verify closing a nonfinal frame affects only that frame.
5. Press **⌘Q** and confirm Emacs quits normally, including any applicable
   unsaved-buffer prompts.
6. Open a file, edit it, save it, and confirm the saved contents are correct.
7. Open `.R`, `.Rmd`, `.qmd`, and `.Rnw` files from Finder, including paths with
   spaces and Unicode; open several documents and confirm no unintended
   duplicate Emacs instance and that the configured frame/tab policy is used.
8. With R and ESS installed, start multiple sessions, verify explicit
   source-buffer execution targets and queued commands, edit command history,
   exercise output suppression, and evaluate `plot(cars)` using the installed
   R's native Quartz device.
9. Check native menus and keyboard shortcuts, plus app startup after moving the
   bundle to a different directory.

Known limitations: local builds are unsigned by default; notarization requires
the developer's credentials and is not performed in CI; LaunchServices may
not select the app as default document handler; package versions are not locked;
R and optional command-line programs are not bundled; and GUI behavior remains
unverified until the manual checks above are completed. This milestone does
not add remote ESS, PTY output protection, or a new R backend.

Maintainers report a successful local Developer ID signing, notarization
acceptance, staple validation, and Gatekeeper assessment of the current
Apple-Silicon Emacs 31.1 app. This is a prior local result, not a result of the
mocked release tests or a promise that every future build is accepted.

The pinned input is a third-party Cocoa build of GNU Emacs. The builder retains
its bundle resources and license notices, but this CI artifact is not a formal
release: before broader redistribution, audit that exact build's patches and
provide the corresponding source and notices required by its licenses.
