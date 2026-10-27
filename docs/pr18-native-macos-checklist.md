# PR #18: Native macOS experience — implementation and validation

Milestones 1–4 implemented the native macOS experience in PR #18, now merged into `main`. This checklist records its scope and release validation. PR #17 is
merged into `main`.

## Implemented scope

- Document-oriented frames with persistent open-in-new-window preferences.
- Glassmacs Dock icon and close-last-window/reopen lifecycle.
- Native application, File, Window and preferences menu foundations.
- Hybrid macOS/Emacs and Traditional Emacs keyboard profiles.
- Safe native Lisp loading exclusively from signed, bundled `.eln` files; disable native JIT and runtime trampolines.
- Emacs 31 compatibility, including `when-let*` migration and cache isolation.
- Regression tests and user-facing documentation.

## Physical Mac release gate

- [ ] Verify Cocoa reopen callback in the signed app restores the retained final
  frame from the Dock and does not create duplicate frames after session restore.
- [ ] Verify `File → New Document`, `File → New Window`, Cocoa Quit, and
  Command-Q retain their distinct expected behaviors.
- [ ] Verify closing the final window leaves Emacs/Glassmacs running and that
  closing nonfinal windows only closes the selected frame.
- [x] Confirm a signed bundled `.eln` loads with normal library validation and no user-cache `.eln` is generated or loaded in the isolated test.
- [ ] Verify document opening, frame policy and persisted preferences.
- [ ] Verify the runtime Dock icon is Glassmacs artwork (not just the Finder bundle icon).
- [ ] Verify Glassmacs, File, and Window menus, native Cocoa Quit, and the
  document-opening and keyboard-profile preference controls.
- [ ] Verify Hybrid and Traditional profiles switch back and forth, preserve
  Control/Meta and ESS mode-local bindings, and persist across restart.
- [x] Execute ERT and byte compilation with bundled Emacs 31.
- [ ] Rebuild, sign, notarize, staple and Gatekeeper-assess the finished app.

Before marking the lifecycle and menu work complete, execute the
[signed-app integration test plan](macos-launcher.md#signed-app-integration-test-plan)
on macOS with a Developer ID-signed hardened-runtime build. Record passes,
failures, and tests not run separately; do not treat ERT or unsigned bundle
validation as a substitute for Dock, Cocoa menu, or physical-key verification.

Native macOS tabs and full Settings UI remain deferred.

## Milestone 5 local verification — 2026-10-21

Automated build and signed-app checks were run on Apple Silicon with the
repository-pinned Cocoa GNU Emacs 31.1 archive. The built application is
`build/Glassmacs.app` (497 MiB) with bundle identifier
`org.glassmacs.Glassmacs`. Emacs 31.1, the Glassmacs bootstrap, and the Cocoa
lifecycle module contain both arm64 and x86_64 slices. The bundle contains its
Glassmacs icon, Lisp/runtime resources, and lifecycle module.

- **Build and bundle validation: pass.** The validator checked bundle metadata,
  546 unique Mach-O files, direct dependencies, runtime search paths, and
  bundled startup policy. The Swift bootstrap is now built for each supported
  architecture and combined as a universal executable.
- **Signing and local security validation: pass.** The outer app and bundled
  Emacs were signed with the same Developer ID Application team, with hardened
  runtime enabled. All 320 bundled `.eln` files passed strict signature
  verification. No entitlements were present and no library-validation bypass
  was found. `codesign --verify --deep --strict` and the full app validator
  succeeded. A bundled `.eln` was loaded through Emacs 31's native loader from
  the signed app without a library-validation error; the isolated test home
  received no `.eln` or cache directory.
- **ERT: 122 tests; 111 passed; 0 unexpected failures; 11 skipped.** Skips
  require ESS, which was not installed or discoverable. The Rscript evaluation
  and base-graphics PNG tests passed with R 4.6.1. ERT emitted one warning for a
  temporary test package lacking a `lexical-binding` file header.
- **Python release tests: 26 passed. Swift tests: 5 passed.** Shell syntax and
  `git diff --check` also passed. Byte compilation with the signed bundled
  Emacs produced 13 temporary `.elc` files without warnings.
- **R/ESS: partial.** R 4.6.1 is installed and its `aqua` capability is true;
  ESS is unavailable, so interactive ESS process and buffer checks were not run.
- **LaunchServices launch: started.** `open -a` accepted the signed app, its
  Glassmacs bundle identifier is registered, and an Emacs process started from
  the bundle. This establishes launch only, not interactive GUI behavior.
- **GUI integration: not verified.** Dock/application-switcher identity,
  window close/reopen, menu dispatch, session restoration, keyboard profiles,
  persistent preferences across restarts, save prompts, and explicit Quit still
  require hands-on GUI checks in the signed app. Launching the app or passing
  batch tests does not count as passing those checks.
- **Notarization/Gatekeeper: release blocked.** No notarytool profile was
  accessed and no submission was made. `spctl --assess --type execute` rejected
  this signed build as `source=Unnotarized Developer ID`; notarization was
  intentionally not attempted.

During this build, the previous host-only Swift build was found to produce an
arm64-only LaunchServices executable. The build script now assembles a
universal bootstrap; RPATH sanitization also deduplicates entries reported
once per architecture in universal binaries. These changes passed the release
script tests and the completed signed build.

## P0 fix — last window close quit Glassmacs

- Cause: Cocoa window close arrives as a `delete-frame` special event handled
  by `handle-delete-frame`, which calls `save-buffers-kill-emacs` when no
  other visible frame exists. It never reached the `delete-frame` advice.
  The Cocoa bridge and launcher were not involved.
- Fix: `glassmacs--handle-delete-frame-preserving-app` (`lisp/glassmacs-macos.el`)
  hides the final visible graphical frame instead. Explicit Quit
  (`save-buffers-kill-emacs`, Cmd-Q) is untouched; `glassmacs-reopen` and the
  Dock bridge restore the hidden frame.
- Automated: ERT 128 tests, 117 pass, 0 unexpected, 11 skipped (ESS).
- Requires physical verification in a re-signed build: close the last window
  (app stays in Dock/switcher), Dock click and File → New Window reopen,
  Cmd-Q quits with save prompts, restart restores without duplicate frames.

## New Window vs New Document, and scratch persistence

Semantics:
- **New Window** (File/Window menu, `glassmacs-new-window`): restores the
  hidden final frame if one exists, otherwise creates a separate frame. It
  may show an existing buffer such as `*scratch*`.
- **New Document** (File menu, `glassmacs-new-document`): creates a distinct
  `Untitled` buffer using the document-opening policy.
- **⌘N (Hybrid profile)**: `glassmacs-new-document`. Traditional profile keeps
  upstream `make-frame`.
- **Dock reopen** (`[ns-new-frame]` → `glassmacs-reopen`): same as New Window;
  restores the hidden frame and creates no buffers.

Root cause of ⌘N opening a window on `*scratch*`: hybrid bindings were written
as `[super-n]` symbols, but Cocoa delivers Command chords as integer events
(`?\s-n`), which `ns-win.el` binds to `make-frame`. The hybrid ⌘ bindings
(including ⌘W) were therefore never matched. They now use integer events.

Scratch persistence: closing or hiding a frame leaves the buffer alive in the
running process; Quit ends the process and discards unsaved non-file buffers
(Emacs prompts only for file-backed buffers); saving a file-backed buffer is
the only persistence today. Restoring scratch on restart is a recommended
opt-in (default off) follow-up issue, not a PR #18 blocker.

Automated: ERT 135 tests, 124 pass, 0 unexpected, 11 skipped (ESS).
Physical re-check needed after rebuild/re-sign: ⌘N yields a distinct Untitled
buffer; ⌘W closes the window (final window stays running); File → New Window
and Dock click restore the hidden window without new buffers.

## P0 fix — commands do nothing with zero visible windows

**Root cause.** Emacs Cocoa menu items use action `menuDown:` with a nil
target. Only `EmacsView` implements it, and Cocoa finds it through the
responder chain (key window, main window, `NSApp`, delegate). With every frame
hidden there is no key window and the delegate lacked `menuDown:`, so menu
actions were silently dropped while items still looked enabled. Probed with a
real Cocoa run: the action was never delivered when all frames were hidden.

**Fix.**
- `macos/GlassmacsLifecycle.m` adds `menuDown:` to the delegate (only when
  absent); with no key window it forwards to the hidden `EmacsView`. A local
  key-down monitor does the same for key events with no window.
- `lisp/glassmacs-macos.el`: a command that *starts* with no visible frame
  reveals the retained hidden frame afterwards (not for quit/hide/close
  commands). Activation alone never opens a window.
- `lisp/glassmacs-frames.el`: New Document and file opening reuse the hidden
  frame instead of creating a second one, for all three policies.

**Results (unsigned dev run).** ERT 145 run, 134 expected, 0 unexpected,
11 skipped (ESS absent); Python 27 pass; Swift 0 failures; lifecycle module
builds universally; `git diff --check` clean.

**Evidence level.** ERT tests are mocks. Synthetic Cocoa probe (menu item
performed via `performActionForItemAtIndex:`, ⌘N via `postEvent:`) passed.
Real-hardware ⌘N failure was *not* reproduced synthetically; the key monitor
is defensive and unverified.

**Physical-Mac steps (needs rebuild + sign).**
1. Close the last window; confirm no window reopens on activation.
2. File → New Document, File → New Window, and ⌘N (Hybrid) each work; check
   no duplicate frames/buffers.
3. Switch to Traditional; ⌘N creates a frame.
4. Reach `*scratch*` via Buffers menu or `C-x b`.
5. Dock click restores the hidden frame with no new buffers.
6. ⌘Q with zero windows quits.
7. Repeat opening a file under new-frame, new-tab and reuse-current.

Known limit: native side targets one hidden window (the last created).

**Key monitor scope.** The monitor acts only when there is no key and no main
window and the event has no window; it consumes the event after forwarding
(no double dispatch) and passes ⌘Q, ⌘W, ⌘H, ⌘M and ⌘, to the main menu. With a
normal key window, events are returned untouched. Static source test only;
verify on hardware.

**Remaining risk: multiple hidden frames.** The bridge targets the most
recently created hidden `EmacsWindow`. The final-frame policy keeps at most one
frame hidden, so this should not occur; if it does, the wrong frame could
receive the event. Not expanded unless physical testing shows a problem.

## Status summary for review

**Confirmed working on a physical Mac (signed build, before the ⌘W fix):**
- Dock icon shows Glassmacs identity.
- Closing the final window keeps the app running; Dock click reopens it;
  repeated close/reopen cycles work; scratch contents survive close/reopen.
- Hybrid ⌘N creates an Untitled document; File → New Window creates a
  separate frame.

**Corrected, automated coverage only (not retested in a rebuilt signed app):**
- ⌘W on the last window raised "Attempt to make invisible the sole visible or
  iconified frame" because `delete-frame` advice called `make-frame-invisible`
  without its NO-ERROR argument. Fixed in `lisp/glassmacs-macos.el`; the ERT
  mock now signals the same error unless the argument is passed.

**Remaining uncertainty:**
- Menu and ⌘N dispatch with zero visible frames. A Cocoa-level probe showed
  `menuDown:` has no target with no key window, and the bridge forwards it,
  but a user-reported failure after closing the last window was not
  reproduced end to end, and the key-event monitor is unverified on hardware.
  Not pursued further unless a reproducible release blocker appears.
- Multiple hidden frames (bridge targets the last created hidden window).
- Scratch persistence across restart is a separate optional enhancement.

**Not yet done:** ESS/R integration testing (11 ERT tests skip without ESS);
notarization (`spctl` rejects the unnotarized build).

**Automated (unsigned dev run):** ERT 145 run, 134 as expected, 0 unexpected,
11 skipped; Python release-script tests pass; Swift tests 0 failures;
affected Lisp byte-compiles without warnings; `git diff --check` clean.

## CI stabilization pass

Root causes (all test/CI-environment assumptions; no product defect found):

- `glassmacs-cocoa-file-open-event-uses-document-policy`: `ns-input-file` is
  only globally special in Cocoa Emacs, so the test's `let` was lexical on
  other builds. The test file now declares `(defvar ns-input-file)`.
- `glassmacs-macos-lifecycle-advises-cocoa-close-handler` and
  `glassmacs-windowless-hooks-are-installed`: the lifecycle installer is
  darwin-gated. Tests now run it under a simulated darwin system with native
  hooks stubbed, then restore advice and hooks.
- `glassmacs-windowless-command-n-follows-keyboard-profile`: only Cocoa's
  `ns-win.el` binds ⌘N to `make-frame`. The test emulates that binding.
- macOS build: `scripts/build-macos-app` hardcoded
  `.build/out/Products/Release`, which depends on the SwiftPM version. It now
  asks `swift build --triple … --show-bin-path` for the product directory.

Local results (Cocoa Emacs 31.1): ERT 145 run, 134 expected, 0 unexpected,
11 skipped (real-ESS tests; ESS is not installed locally and runs in CI);
Python 27 passed; Swift 5 tests, 0 failures; unsigned temp app build and
`validate-macos-app` passed with universal bootstrap. Byte-compile clean apart
from pre-existing free-variable warnings when compiled outside `init.el`.
Remaining limitations: Linux CI results await the next CI run; no signed
rebuild, notarization, or GUI retest in this pass.

## Integrated 0.1 development status — 2026-10-27

PRs [#18](https://github.com/jmping/Glassmacs/pull/18), [#19](https://github.com/jmping/Glassmacs/pull/19), [#20](https://github.com/jmping/Glassmacs/pull/20), [#21](https://github.com/jmping/Glassmacs/pull/21), and [#22](https://github.com/jmping/Glassmacs/pull/22) have merged into `main` (most recently #22 at `604e44e`). Their PR CI succeeded (Emacs ERT, ESS/R integration, macOS launcher), **not** interactive Cocoa GUI acceptance.

Implemented: native Cocoa application/menu/window infrastructure; configurable document opening; New Buffer in Mode; ESS-based R menus and contextual toolbar actions; R sessions, explicit targeting, queue/output controls; Save As and modified-document review; keyboard, toolbar and document preferences. R Markdown, Quarto, Sweave, Shiny and remote workflows have partial integrations, not fully verified end-to-end behavior.

Outstanding: real macOS testing for reopening, document safety, keyboard/menu dispatch, R execution/session targets, native Quartz plotting, toolbar image/layout and preference persistence; release candidate signing/notarization, Gatekeeper and licensing/source obligations. **The next separate audit** will compare current menus against Aquamacs historical source, followed by historical issue triage; do not equate design inventory with demonstrated parity.

