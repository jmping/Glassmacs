# Standalone macOS application

## Integrated 0.1 development status — 2026-10-27

PRs [#18](https://github.com/jmping/Glassmacs/pull/18), [#19](https://github.com/jmping/Glassmacs/pull/19), [#20](https://github.com/jmping/Glassmacs/pull/20), [#21](https://github.com/jmping/Glassmacs/pull/21), and [#22](https://github.com/jmping/Glassmacs/pull/22) have merged into `main`. The most recent merge was #22 at `604e44e`. Their pull-request CI completed successfully (Emacs ERT, ESS/R integration, and macOS launcher build). These results establish code integration and automated validation, **not interactive Cocoa GUI acceptance**.

Implemented capabilities include native application/menu/window infrastructure; configurable new-frame/new-tab/reuse-current document opens; New Buffer in Mode and Change Buffer Mode; ESS-backed R source/console menus and contextual toolbar actions; explicit R session start, targeting, inspection and listing; execution-queue and output controls; Save Document As and non-destructive unsaved-document review; and keyboard/document/toolbar preferences. R Markdown, Quarto, Sweave, Shiny and remote workflows have preliminary integrations and still require separate end-to-end validation. Neither complete historical Aquamacs parity nor a production release is claimed.

**Still outstanding:** signed-app testing of Cocoa reopen/close, document safety and focus, R source-to-console execution, session targeting, native R/Quartz plotting, toolbar image/layout, persistent preferences, and optional rendering/Shiny workflows. A releasable 0.1 build also needs candidate-specific signing, notarization, Gatekeeper checks and license/source-distribution review. Earlier signed builds do not certify the current `main` tree.

**Next audit, separate from this documentation sync:** compare current Glassmacs menu commands against historical Aquamacs menu inventory and then triage historical Aquamacs issues, recording evidence, priority and disposition without treating proposed parity as implemented behavior.

> **Document ID:** DOC-MAC-LAUNCHER<br>
> **Status:** Informational<br>
> **Owner:** Glassmacs maintainers<br>
> **Effective date:** 2026-10-20<br>
> **Last reviewed:** 2026-10-28<br>
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
can end the process and remove the Dock application. Glassmacs intercepts
deletion of the final macOS graphical frame and makes that frame invisible
instead. It does not kill buffers or processes, and does not save or discard
buffer changes. The retained frame is restored by the native Cocoa
Dock-reopen callback. That callback is a small Emacs dynamic module,
compiled from `macos/GlassmacsLifecycle.m` against the bundled Emacs 31 module
header and AppKit. It adds `applicationShouldHandleReopen:hasVisibleWindows:`
to Emacs's existing `EmacsApp` delegate and asks Emacs's existing `newFrame:`
event path to reopen only when Cocoa reports no visible windows. Emacs Lisp
maps that native event to `glassmacs-reopen`, which restores the retained frame
or creates a frame when none was retained. For the no-window case, the
delegate returns `NO` after dispatching the Emacs event, suppressing AppKit's
default untitled-document creation; when a window is already visible it
returns `YES` to preserve normal activation and session-restoration behavior.
The module is a nested Mach-O resource and the existing signing script signs
it with the rest of the app.
When the module loads in the graphical app, it also reads
`Contents/Resources/Glassmacs.icns` from the main app bundle and explicitly
sets `NSApp.applicationIconImage`. This supplements the upstream Emacs image
fallback path: the bundle icon is used both by Finder and by the running Dock
application. Batch tests can verify the resource and bridge wiring, but only
the signed GUI integration test can establish which icon macOS actually shows.
No Emacs source, runtime library-validation policy, or process architecture is
changed. **⌘Q** and Cocoa Quit remain on Emacs's normal save-and-quit path.
Nonfinal frames still delete normally. `File → New Window` always requests a
new frame; `File → New Document` uses the persisted document-opening policy.
The Glassmacs menu exposes document-opening policy and the Hybrid/Traditional
keyboard profile. The File and Window menus add New Window without replacing
Emacs's standard entries. Cocoa's native application menu retains About,
Preferences, Hide, Services, and Quit; the native Preferences item opens the
same Glassmacs Customize group.

On a source checkout without a built bridge, closing the final frame still
keeps Emacs running, but Dock reopen is unavailable; Glassmacs emits a warning
that the native module is missing. Any other failure to load the bridge (an
Emacs built without module support, or the module's initialization failing,
for example because `Glassmacs.icns` is not in the main bundle) is also only a
warning: startup continues, so later modules, `custom.el` and the keyboard
profile still load. `scripts/validate-macos-app` rejects a
bundle missing the module.
Native callback registration, Dock activation, final-window close, and state
restoration still require interactive verification in the signed Glassmacs
application on macOS; ERT and bundle structure checks alone do not prove these
behaviors.

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

The result is `build/Glassmacs.app`. The build copies `init.el`, `lisp/`, the
package bootstrap, the compiled Cocoa-reopen module, and the committed
`assets/icon/Glassmacs.icns` into the bundle; it does not depend on the source
checkout at runtime. The Swift bootstrap is built for both arm64 and x86_64 and
combined into a universal executable, matching the architecture support of the
bundled Emacs executable and Cocoa lifecycle bridge. The validation
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

The signing script signs nested Mach-O files first, then bundled Emacs and the
outer app with Developer ID, hardened runtime, and a secure timestamp. It uses
no entitlements, so standard macOS library validation remains enabled, and
requires `codesign --verify --deep --strict --verbose=2`. Do not modify the
bundle after signing.

Inspect the signed Emacs executable with:

```sh
codesign -dv --verbose=4 build/Glassmacs.app/Contents/MacOS/Emacs
codesign --verify --deep --strict --verbose=2 build/Glassmacs.app
```

The nested bundled `.eln` files are signed by the same Developer ID as Emacs.
Glassmacs never signs runtime-generated libraries or distributes private keys.

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

### Document-opening preference

On macOS, interactive opens of ordinary documents use a new Emacs frame by
default; on other platforms they reuse the current frame. Run
`M-x glassmacs-set-document-opening-policy` to select and save one of:
`new-frame`, `new-tab`, or `reuse-current`. Emacs frames are macOS application
windows; the policy does not create a new frame for each buffer switch.
`new-tab` uses Emacs's built-in tab-bar support. The setting is saved through
Emacs Customize to `custom.el` in the Glassmacs data directory and restored on
the next launch. Special and interactive buffers, including help and ESS/R
process buffers, are not treated as documents by this policy.

### Native Lisp compilation

Glassmacs establishes its native-code policy twice: in the launcher's Emacs
`--eval` argument before loading `init.el`, and again at the beginning of
`init.el` before loading Glassmacs modules or initializing packages:

- `native-comp-jit-compilation` is set to nil, preventing asynchronous native
  compilation when `.elc` files load.
- `native-comp-enable-subr-trampolines` is set to nil. Emacs 31 defaults it to
  `t` independently of JIT; advice on a primitive could otherwise create a
  trampoline `.eln` under the first writable native load-path directory.
- `native-comp-eln-load-path` is replaced with only the running Emacs bundle's
  `Contents/Frameworks/native-lisp` directory, and only when the bundle's
  `Info.plist` and native-lisp directory are present. Outside the bundle
  (source checkouts run with another Emacs), only existing directories that
  the user cannot write are kept, such as a distribution's system
  `native-lisp` directory; user-writable caches such as `eln-cache` are
  dropped. The launcher's `--eval` policy and `init.el` implement this
  identically and must be kept in sync.

Consequently Glassmacs never loads user-writable `.eln` caches or `.eln` files
from its package directory. Ordinary `.el` and `.elc` packages still load via
the standard Emacs `load-path`. Explicit native compilation is not a supported
Glassmacs package-installation path; there is no environment-variable opt-in.
This policy changes only Glassmacs launches and does not modify ordinary GNU
Emacs configuration or behavior.

The bootstrap exports `MACOSX_DEPLOYMENT_TARGET=13.0` unless the launching
environment already supplies a recognized numeric macOS target at or above the
supported macOS 13 minimum. The selected value is inherited by Emacs and
native-compilation subprocesses. The SDK/compiler must still support an
explicitly selected version. This default avoids the observed invalid
`-mmacosx-version-min=18.0` generated by GCC 14.3 on the tested system; it does
not change the bundle's minimum OS.

The Developer ID signing script signs every nested Mach-O file, including
bundled `.eln` libraries, before signing Emacs and the outer app. It enables
the hardened runtime and passes no entitlements, leaving normal macOS library
validation enabled. Glassmacs does not modify signature verification, sign
runtime-generated libraries, or load generated user-cache artifacts. Whether
the signed Emacs process can load a bundled `.eln` under library validation
was verified in the Milestone 5 local record: one bundled native library loaded
from the signed app, and the isolated test home received no `.eln` cache files.
All bundled `.eln` signatures were also verified. This focused check does not
replace the interactive signed-app integration tests or prove every native
module is exercised.

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

## Signed-app integration test plan

Lifecycle, Dock artwork, native menus, and Cocoa keyboard delivery must be
tested in the Developer ID-signed, hardened-runtime app before these changes
are called complete. The plan intentionally does not weaken hardened runtime,
alter entitlements, or use a generated unsigned `.eln` as a workaround.

Build and verify the exact app under test, then sign and verify it with the
release signing script:

```sh
./scripts/build-macos-app
GLASSMACS_SKIP_EMACS_STARTUP=1 ./scripts/validate-macos-app build/Glassmacs.app
GLASSMACS_SIGN_IDENTITY="<Developer ID Application certificate SHA-1>" \
  ./scripts/sign-macos-app build/Glassmacs.app
./scripts/validate-macos-app build/Glassmacs.app
codesign --verify --deep --strict --verbose=2 build/Glassmacs.app
spctl --assess --type execute --verbose=2 build/Glassmacs.app
```

Use a dedicated macOS test account with fresh Glassmacs user data. Launch that
same signed bundle from Finder or LaunchServices (not a separately rebuilt
copy), and record macOS version, Emacs version, signing Team ID, bundle path,
and `codesign`/Gatekeeper results. For each lifecycle scenario, record visible
and hidden frame counts using `M-x list-frames`, Dock presence/artwork, and
relevant `*Messages*` or Console errors:

| Area | Integration steps | Pass condition |
| --- | --- | --- |
| Runtime icon | Launch from Finder; inspect the running Dock icon and app switcher. | Glassmacs artwork appears at runtime, not only in Finder's bundle listing. |
| Final-window lifecycle | Open two documents; close one, then close the final window; click the Dock icon. Repeat after a normal session restore. | Nonfinal close affects only its frame; the process and Dock item persist; reopen restores one usable frame without duplicates. |
| File/Window menus | Invoke New Document, Open, New Window, and document-opening choices from menus; verify their key equivalents; cancel a dirty-document close. | Commands follow their policy, Emacs menu items remain present, and canceled saves preserve edits. |
| Keyboard profiles | Switch Hybrid → Traditional → Hybrid from the menu; test Command-N/O/S/W/Q and Control/Meta prefixes in an ordinary buffer and ESS buffer. | Hybrid bindings work; Traditional restores prior bindings; profile indicator matches the selected setting after restart. |
| Cocoa quit | Quit from the native application menu and with ⌘Q, with clean and dirty buffers. | Both take the normal Emacs save/quit path, honor prompts, and terminate only after confirmation. |
| Signed native code | Open representative bundled Lisp modules and an allowed bundled `.eln`; inspect logs and the runtime-loaded library path. | No signature/library-validation failures and no unsigned generated cache `.eln` is loaded. |

Also repeat the keyboard checks with a non-US input source, verifying composed
characters and Option/Meta behavior. Record each result as **pass**, **fail**,
or **not run**; any failure in icon, reopen/frame counts, menu dispatch,
profile restoration, or bundled `.eln` validation blocks declaring macOS
runtime behavior complete. Do not change hardened-runtime policy to make this
test pass.

## Verification and limitations

The macOS CI job validates build inputs, bundle structure and metadata, direct
Mach-O dependencies, Swift tests, batch startup, existing ERT tests, and app
relocation. These are **build and batch checks, not interactive GUI tests**.
The signed app was launched through LaunchServices during Milestone 5, but no
interactive GUI behavior was verified. Therefore none of the following are
claimed as verified: one coherent Dock/application-switcher identity after
`execv`, reopening, LaunchServices document delivery, multiple document opens,
policy-aware new-frame/new-tab behavior for Finder opens, save prompts,
menus/shortcuts, interactive ESS, multiple R sessions, source-buffer
targets/queues, editable history, local output suppression, or native Quartz
`plot(cars)`.

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
