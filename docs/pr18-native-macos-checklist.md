# PR #18: Native macOS experience — implementation and validation

Milestones 1–4 implement the native macOS experience on the existing PR #18
branch. This checklist records its scope and release validation. PR #17 is
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
