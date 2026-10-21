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

- [ ] Confirm signed bundled `.eln` files load without Team ID / library-validation errors; no unsigned cache `.eln` loads.
- [ ] Verify running Dock icon uses Glassmacs artwork.
- [ ] Verify closing the last document window leaves the application running and reopening works from Dock.
- [ ] Verify document opening, frame policy and persisted preferences.
- [ ] Verify native menus and Hybrid/Traditional shortcuts.
- [ ] Execute ERT and byte compilation with bundled Emacs 31.
- [ ] Rebuild, sign, notarize, staple and Gatekeeper-assess the finished app.

Native macOS tabs and full Settings UI remain deferred. This checkpoint alone does not implement any of these features.
