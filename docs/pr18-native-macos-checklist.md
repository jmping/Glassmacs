# PR #18: Native macOS experience — implementation and validation

This is an initial checkpoint for the draft PR. The Aquamacs-inspired macOS implementation has **not yet been restored or published**. PR #17 is merged into `main`.

## Planned scope

- Document-oriented frames with persistent open-in-new-window preferences.
- Glassmacs Dock icon and close-last-window/reopen lifecycle.
- Native application, File, Window and preferences menu foundations.
- Hybrid macOS/Emacs and Traditional Emacs keyboard profiles.
- Safe native Lisp loading exclusively from signed, bundled `.eln` files; disable native JIT and unsafe overrides.
- Emacs 31 compatibility, including `when-let*` migration.
- Regression tests and user-facing documentation.

## Physical Mac release gate

- [ ] Verify Cocoa reopen callback in the signed app restores the retained final
  frame from the Dock and does not create duplicate frames after session restore.
- [ ] Verify `File → New Document`, `File → New Window`, Cocoa Quit, and
  Command-Q retain their distinct expected behaviors.
- [ ] Verify closing the final window leaves Emacs/Glassmacs running and that
  closing nonfinal windows only closes the selected frame.
- [ ] Confirm signed bundled `.eln` files load without Team ID / library-validation errors; no unsigned cache `.eln` loads.
- [ ] Verify document opening, frame policy and persisted preferences.
- [ ] Verify the runtime Dock icon is Glassmacs artwork (not just the Finder bundle icon).
- [ ] Verify Glassmacs, File, and Window menus, native Cocoa Quit, and the
  document-opening and keyboard-profile preference controls.
- [ ] Verify Hybrid and Traditional profiles switch back and forth, preserve
  Control/Meta and ESS mode-local bindings, and persist across restart.
- [ ] Execute ERT and byte compilation with bundled Emacs 31.
- [ ] Rebuild, sign, notarize, staple and Gatekeeper-assess the finished app.

Before marking the lifecycle and menu work complete, execute the
[signed-app integration test plan](macos-launcher.md#signed-app-integration-test-plan)
on macOS with a Developer ID-signed hardened-runtime build. Record passes,
failures, and tests not run separately; do not treat ERT or unsigned bundle
validation as a substitute for Dock, Cocoa menu, or physical-key verification.

Native macOS tabs and full Settings UI remain deferred. This checkpoint alone does not implement any of these features.
