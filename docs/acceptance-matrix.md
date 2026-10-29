# Glassmacs acceptance matrix

> **Document ID:** DOC-ACCEPT  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-29  
> **Last reviewed:** 2026-10-29  
> **Coverage:** Every acceptance risk with its evidence, tests, automation and verification status  
> **Supersedes:** None

<!-- Generated from acceptance/matrix.toml by scripts/acceptance-matrix render; edit the matrix, not this file. -->


Statuses are kept apart on purpose. **Implemented** means the behavior exists; **automated** means tests check it; **packaged app** says whether those checks run against the built Glassmacs.app in CI (`ci`) or not at all (`NOT RUN`); **clean machine** records a dated manual run on a fresh Mac, and is `NOT RUN` until someone records one. A green batch run is never GUI acceptance.

Layers: **A** batch tests (`./scripts/test`), **B** static checks of the packaged app (`scripts/validate-macos-app`), **C** GUI scenarios on the packaged app in CI (`scripts/macos-gui-acceptance`), **D** manual ([checklist](macos-acceptance-checklist.md)). In a running Glassmacs, `M-x glassmacs-self-check` runs the in-app subset.

The latest GUI outcomes are in the `macos-gui-acceptance` job summary and its `Glassmacs-GUI-acceptance` artifact; `scripts/acceptance-matrix outcomes results.json` maps them onto these IDs.

| ID | Check | Sev. | Evidence | Layers | Implemented | Automated | Packaged app | Clean machine |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [DIST-001](#dist-001) | Bundled native libraries resolve inside the app | P0 | [Aquamacs #243](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/243) | B | yes | yes | ci | NOT RUN |
| [DIST-002](#dist-002) | Apple Silicon and Intel architectures | P0 | [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), [Aquamacs #268](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/268) | B D | yes | partial | ci | NOT RUN |
| [DIST-003](#dist-003) | No build-machine paths in the app | P0 | [Aquamacs #243](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/243) | B | yes | yes | ci | NOT RUN |
| [DIST-004](#dist-004) | Code signature, permissions and executables | P0 | [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), [Aquamacs #268](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/268) | B | yes | yes | ci | NOT RUN |
| [DIST-005](#dist-005) | Builds with the supported Xcode and macOS versions | P0 | [Aquamacs #258](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/258), [Aquamacs #266](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/266) | B D | yes | partial | ci | NOT RUN |
| [LAUNCH-001](#launch-001) | Packaged app launches from LaunchServices in a clean home | P0 | [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), [Aquamacs #268](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/268) | C D | yes | yes | ci | NOT RUN |
| [LAUNCH-002](#launch-002) | The app ignores the user's own Emacs init files | P0 | `glassmacs:launcher-argv0`, [Aquamacs #251](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/251) | A B C | yes | yes | ci | NOT RUN |
| [LIFE-001](#life-001) | Closing the last window keeps the app running; the Dock reopens it | P0 | [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270) | A C D | yes | partial | ci | NOT RUN |
| [LIFE-002](#life-002) | Menus and shortcuts work with no window open | P0 | [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270) | A C D | yes | partial | ci | NOT RUN |
| [FINDER-001](#finder-001) | Opening a file from Finder with no window shows it | P0 | [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270) | A C D | yes | yes | ci | NOT RUN |
| [FINDER-002](#finder-002) | Repeated and duplicate opens do not duplicate buffers or windows | P1 | [Aquamacs #247](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/247), [Aquamacs #249](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/249), [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270) | A C | yes | yes | ci | NOT RUN |
| [FINDER-003](#finder-003) | A Finder open during startup restore is shown in front | P0 | [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270), `glassmacs:issue-34-scenario-1` | A C | yes | yes | ci | NOT RUN |
| [CLIENT-001](#client-001) | emacsclient and server opens use the right window | P2 | [Aquamacs #247](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/247), [Aquamacs #249](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/249) | D | no | no | NOT RUN | NOT RUN |
| [MENU-001](#menu-001) | Menu items evaluate without errors in key modes | P1 | [Aquamacs #256](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/256), [Aquamacs #180](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/180) | A C | yes | yes | ci | NOT RUN |
| [MENU-002](#menu-002) | Menu presentation: shortcuts, About and Preferences items | P1 | [Aquamacs #256](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/256), [Aquamacs #248](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/248) | A D | yes | partial | NOT RUN | NOT RUN |
| [MODE-001](#mode-001) | Mode menus with ESS, polymode and TRAMP do not break | P2 | [Aquamacs #180](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/180) | A C | yes | partial | ci | NOT RUN |
| [PREF-001](#pref-001) | Preferences persist across relaunch | P1 | [Aquamacs #246](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/246), `glassmacs:customize-under-q` | A C | yes | yes | ci | NOT RUN |
| [PREF-002](#pref-002) | State stays in the Glassmacs home | P1 | [Aquamacs #251](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/251) | A C | yes | yes | ci | NOT RUN |
| [PREF-003](#pref-003) | Safe local variables and upgrades keep the user's choices | P1 | [Aquamacs #251](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/251) | A C D | yes | partial | ci | NOT RUN |
| [SPELL-001](#spell-001) | Spell checker discovery and absence | P1 | [Aquamacs #265](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/265) | A C | yes | yes | ci | NOT RUN |
| [SPELL-002](#spell-002) | Interactive spelling suggestions | P1 | [Aquamacs #235](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/235) | A D | yes | partial | NOT RUN | NOT RUN |
| [SPELL-003](#spell-003) | Native spelling never corrects or substitutes | P0 | `policy:literal-text-entry` | A D | yes | partial | NOT RUN | NOT RUN |
| [REVERT-001](#revert-001) | Files changed by other programs update; unsaved edits are kept | P1 | [Aquamacs #245](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/245) | A C | yes | yes | ci | NOT RUN |
| [NATIVE-001](#native-001) | Bundled native code loads without a compiler; no user cache | P1 | [Aquamacs #253](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/253) | A B C D | yes | yes | ci | NOT RUN |
| [NATIVE-002](#native-002) | Packages work when native compilation is unavailable | P1 | [Aquamacs #253](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/253) | A | yes | yes | NOT RUN | NOT RUN |
| [DIALOG-001](#dialog-001) | Open and recent-file dialogs do not hang | P1 | [Aquamacs #255](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/255), [Aquamacs #241](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/241) | A D | yes | partial | NOT RUN | NOT RUN |
| [FULL-001](#full-001) | Closing full-screen windows | P1 | [Aquamacs #218](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/218), [Aquamacs #160](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/160) | C D | yes | partial | ci | NOT RUN |
| [CLOSE-001](#close-001) | Command-W never loses unsaved changes | P0 | [Aquamacs #218](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/218), `glassmacs:issue-34-scenario-6` | A C | yes | yes | ci | NOT RUN |
| [CLOSE-002](#close-002) | Quitting with unsaved documents asks first | P0 | `glassmacs:issue-34-scenario-6` | A C D | yes | partial | ci | NOT RUN |
| [RESTORE-001](#restore-001) | Workspace restore reopens files once and starts no processes | P1 | `glassmacs:issue-34-scenario-2` | A C D | yes | partial | ci | NOT RUN |
| [RECOVER-001](#recover-001) | Crash recovery is offered and never overwrites data | P0 | `glassmacs:issue-34-scenario-2` | A C | yes | yes | ci | NOT RUN |
| [TEXT-001](#text-001) | Typed text stays literal in code, consoles and mixed documents | P0 | `policy:literal-text-entry` | A C D | yes | partial | ci | NOT RUN |
| [KEY-001](#key-001) | International keyboards, input methods and Option keys | P1 | `policy:literal-text-entry` | A D | yes | partial | NOT RUN | NOT RUN |
| [CLIP-001](#clip-001) | Clipboard round trip with other apps | P1 | `policy:literal-text-entry` | C | yes | yes | ci | NOT RUN |
| [ENC-001](#enc-001) | File encodings and line endings round trip | P2 | `glassmacs:issue-34-other-risks` | A | yes | yes | NOT RUN | NOT RUN |
| [PATH-001](#path-001) | Finder launches find tools on the login-shell PATH | P1 | `glassmacs:issue-34-other-risks` | A C | yes | yes | ci | NOT RUN |
| [ASSOC-001](#assoc-001) | Finder document types are declared | P1 | `glassmacs:issue-34-other-risks` | B | yes | yes | ci | NOT RUN |
| [ASSOC-002](#assoc-002) | Documents open by type through LaunchServices | P1 | `glassmacs:issue-34-other-risks` | C D | yes | partial | ci | NOT RUN |
| [PKG-001](#pkg-001) | Optional packages are offered once; declining installs nothing | P1 | `glassmacs:issue-34-other-risks` | A C | yes | yes | ci | NOT RUN |
| [MIX-001](#mix-001) | Mixed documents: modes, shared R target, chunks, literal typing, spelling | P1 | `glassmacs:mixed-documents` | A | yes | yes | NOT RUN | NOT RUN |
| [MIX-GUI-001](#mix-gui-001) | Mixed documents in the app: document menu and Command shortcuts | P1 | `glassmacs:mixed-documents` | C D | yes | partial | ci | NOT RUN |
| [MIX-002](#mix-002) | Rendering and Shiny previews open their output | P1 | `glassmacs:mixed-documents` | A D | yes | partial | NOT RUN | NOT RUN |
| [R-001](#r-001) | ESS, R and Quarto run from the app | P1 | `glassmacs:issue-34-other-risks` | A D | yes | partial | NOT RUN | NOT RUN |
| [SYNC-001](#sync-001) | Skim SyncTeX forward and inverse search | P2 | `glassmacs:issue-34-other-risks` | A D | yes | partial | NOT RUN | NOT RUN |
| [DISPLAY-001](#display-001) | Multiple displays, Spaces, Stage Manager and scaling | P2 | `glassmacs:issue-34-other-risks` | D | yes | no | NOT RUN | NOT RUN |
| [APPEAR-001](#appear-001) | Light and dark appearance changes | P2 | `glassmacs:issue-34-other-risks` | D | no | no | NOT RUN | NOT RUN |
| [SEC-001](#sec-001) | Developer ID signing, notarization and Gatekeeper | P0 | [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), `glassmacs:issue-34-other-risks` | A D | yes | partial | NOT RUN | NOT RUN |
| [PERM-001](#perm-001) | No privacy permission prompts at launch | P2 | `glassmacs:issue-34-other-risks` | D | yes | no | NOT RUN | NOT RUN |
| [UPSTREAM-001](#upstream-001) | NS scroll crash fixed after Emacs 31.1 (bug#81585) | P1 | `glassmacs:emacs-31-1-missing-ns-fixes` | D | no | no | NOT RUN | NOT RUN |
| [UPSTREAM-002](#upstream-002) | NS freeze from events sent to a closed window, fixed after Emacs 31.1 (bug#72496) | P1 | `glassmacs:emacs-31-1-missing-ns-fixes` | C D | no | partial | ci | NOT RUN |

## DIST-001

**Bundled native libraries resolve inside the app** (P0). The pinned upstream Cocoa Emacs links libgccjit and friends from /nix/store; the build relocates them into the bundle.

- Evidence: [Aquamacs #243](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/243)
- Layers: B (packaged app, static)
- Tests: `py:test_validator_shell_entrypoint_runs_with_literal_python_heredoc`, `py:test_dependency_relocator_targets_the_unique_arch_compatible_bundle_library`, `py:test_dependency_relocator_requires_a_library_for_every_binary_architecture`, `py:test_rpath_sanitizer_cleans_all_binaries_but_preserves_relocatable_entries`, `ci:Build standalone app bundle`, `ci:Verify relocation`
- Manual: see [checklist](macos-acceptance-checklist.md#dist-001)

## DIST-002

**Apple Silicon and Intel architectures** (P0). A missing slice crashes at launch on that architecture.

- Evidence: [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), [Aquamacs #268](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/268)
- Layers: B (packaged app, static), D (manual)
- Tests: `py:test_validator_shell_entrypoint_runs_with_literal_python_heredoc`, `ci:Build standalone app bundle`
- Not fully automated because: CI runs on Apple Silicon only; the Intel slice is checked statically.
- Manual: see [checklist](macos-acceptance-checklist.md#dist-002)

## DIST-003

**No build-machine paths in the app** (P0). Glassmacs-compiled binaries could embed the checkout or temporary build paths; any binary could embed the app's own location.

- Evidence: [Aquamacs #243](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/243)
- Layers: B (packaged app, static)
- Tests: `py:test_validator_shell_entrypoint_runs_with_literal_python_heredoc`, `ci:Verify relocation`
- Not fully automated because: Upstream /nix/store, Homebrew and /usr/local strings are counted, not failed: runtime linkage outside the bundle is rejected separately and libgccjit's embedded paths serve only the disabled JIT compiler.

## DIST-004

**Code signature, permissions and executables** (P0). Editing Mach-O files invalidates signatures, which arm64 macOS enforces with SIGKILL at exec.

- Evidence: [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), [Aquamacs #268](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/268)
- Layers: B (packaged app, static)
- Tests: `py:test_validator_shell_entrypoint_runs_with_literal_python_heredoc`, `py:test_build_sanitizes_before_strict_bundle_validation`, `ci:Build standalone app bundle`

## DIST-005

**Builds with the supported Xcode and macOS versions** (P0). Glassmacs compiles only the Swift launcher and the Objective-C lifecycle module; Emacs itself is the pinned upstream universal build, so toolchain exposure is much smaller than Aquamacs's.

- Evidence: [Aquamacs #258](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/258), [Aquamacs #266](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/266)
- Layers: B (packaged app, static), D (manual)
- Tests: `ci:Test Glassmacs bootstrap package`, `ci:Build standalone app bundle`
- Not fully automated because: CI builds on the macos-15 runner image only; other macOS/Xcode versions are a follow-up runner matrix.
- Manual: see [checklist](macos-acceptance-checklist.md#dist-005)

## LAUNCH-001

**Packaged app launches from LaunchServices in a clean home** (P0). Launch via Finder/Dock uses launchd's environment, not a developer shell.

- Evidence: [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), [Aquamacs #268](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/268)
- Layers: C (GUI in CI), D (manual)
- Tests: `gui:launch-clean-home`, `ci:Verify bootstrap with bundled configuration`, `swift:testBundlePathsAndArgumentsUseTheBundledEmacsAndConfiguration`
- Manual: see [checklist](macos-acceptance-checklist.md#launch-001)

## LAUNCH-002

**The app ignores the user's own Emacs init files** (P0). Found by this audit: the launcher passed -Q as argv[0], so Emacs ignored it and loaded ~/.emacs.d init files and packages.

- Evidence: `glassmacs:launcher-argv0`, [Aquamacs #251](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/251)
- Layers: A (batch), B (packaged app, static), C (GUI in CI)
- Tests: `swift:testProcessArgumentsStartWithTheProgramSoQuickStartIsAnOption`, `ci:Verify the app does not load the user's Emacs init files`, `gui:user-emacs-init-is-not-loaded`, `ert:glassmacs-startup-does-not-touch-ordinary-emacs-home`

## LIFE-001

**Closing the last window keeps the app running; the Dock reopens it** (P0). Cocoa sends handle-delete-frame for the close button; Glassmacs hides the final frame and its lifecycle module answers reopen.

- Evidence: [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270)
- Layers: A (batch), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-macos-cocoa-close-of-final-frame-does-not-quit`, `ert:glassmacs-macos-reopen-after-cocoa-close-shows-hidden-frame`, `ert:glassmacs-windowless-dock-reopen-creates-no-buffers`, `gui:last-window-close-and-dock-reopen`
- Not fully automated because: CI delivers the close as Cocoa's delete-frame event and reopens with open -a; a real click and Dock click need a person.
- Manual: see [checklist](macos-acceptance-checklist.md#life-001)

## LIFE-002

**Menus and shortcuts work with no window open** (P0). Cocoa routes menu actions and key equivalents through the key window, which does not exist; the lifecycle module forwards them.

- Evidence: [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270)
- Layers: A (batch), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-windowless-command-n-follows-keyboard-profile`, `ert:glassmacs-windowless-buffer-command-reveals-frame`, `py:test_lifecycle_bridge_routes_windowless_menu_and_key_events`, `gui:windowless-menu-and-shortcuts`
- Not fully automated because: The GUI scenario needs Accessibility for System Events; without it the scenario is NOT RUN.
- Manual: see [checklist](macos-acceptance-checklist.md#life-002)

## FINDER-001

**Opening a file from Finder with no window shows it** (P0). A Finder open arrives as an Apple Event while the only frame is hidden.

- Evidence: [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270)
- Layers: A (batch), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-windowless-open-file-shows-in-hidden-frame`, `ert:glassmacs-cocoa-file-open-event-uses-document-policy`, `gui:finder-open-while-windowless`
- Manual: see [checklist](macos-acceptance-checklist.md#finder-001)

## FINDER-002

**Repeated and duplicate opens do not duplicate buffers or windows** (P1). LaunchServices may deliver the same document again; paths can contain spaces and non-ASCII characters.

- Evidence: [Aquamacs #247](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/247), [Aquamacs #249](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/249), [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270)
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-visible-document-is-not-opened-in-an-extra-frame`, `gui:finder-repeat-and-mixed-documents`, `gui:finder-open-while-windowless`

## FINDER-003

**A Finder open during startup restore is shown in front** (P0). Workspace restore reuses the startup frame while LaunchServices delivers the document.

- Evidence: [Aquamacs #270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270), `glassmacs:issue-34-scenario-1`
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-workspace-restores-before-recovery-is-offered`, `gui:crash-restore-recovery-and-finder-open`

## CLIENT-001

**emacsclient and server opens use the right window** (P2). Not exposed by default: Glassmacs starts no server and ships no client wrapper; documents arrive as Apple Events (FINDER-*).

- Evidence: [Aquamacs #247](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/247), [Aquamacs #249](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/249)
- Layers: D (manual)
- Not fully automated because: No server is started by Glassmacs; revisit if a command-line opener is added.
- Manual: see [checklist](macos-acceptance-checklist.md#client-001)

## MENU-001

**Menu items evaluate without errors in key modes** (P1). Emacs evaluates every item's :enable/:visible/:button/:filter when it updates the Cocoa menu.

- Evidence: [Aquamacs #256](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/256), [Aquamacs #180](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/180)
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-menu-check-reports-broken-items`, `ert:glassmacs-menus-evaluate-cleanly-in-key-modes`, `gui:menus-in-key-modes`

## MENU-002

**Menu presentation: shortcuts, About and Preferences items** (P1). Shortcut annotations and the application menu are drawn by Cocoa.

- Evidence: [Aquamacs #256](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/256), [Aquamacs #248](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/248)
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-macos-menus-install-without-duplicating-cocoa-items`, `ert:glassmacs-native-preferences-menu-opens-glassmacs-settings`, `ert:glassmacs-hybrid-bindings-use-cocoa-integer-events`
- Not fully automated because: How Cocoa draws menus can only be judged by looking.
- Manual: see [checklist](macos-acceptance-checklist.md#menu-002)

## MODE-001

**Mode menus with ESS, polymode and TRAMP do not break** (P2). Third-party mode menus are evaluated in Glassmacs's menu bar.

- Evidence: [Aquamacs #180](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/180)
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-polymode-menus-evaluate-in-prose-and-chunks`, `ert:glassmacs-menus-evaluate-cleanly-in-key-modes`, `ert:glassmacs-r-source-and-console-menus-have-distinct-actions`, `gui:menus-in-key-modes`
- Not fully automated because: ESS and polymode menus run in the integration CI job; TRAMP buffers need a host.
- Manual: see [checklist](macos-acceptance-checklist.md#mode-001)

## PREF-001

**Preferences persist across relaunch** (P1). Found by this audit: under -Q Emacs refused to save customizations, so several preference toggles changed the session only.

- Evidence: [Aquamacs #246](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/246), `glassmacs:customize-under-q`
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-preference-toggles-are-saved-in-glassmacs-home`, `ert:glassmacs-document-opening-policy-is-persisted`, `ert:glassmacs-keyboard-profile-is-persisted`, `gui:preferences-persist-across-relaunch`

## PREF-002

**State stays in the Glassmacs home** (P1). Glassmacs must not read or write ~/.emacs.d or its eln-cache, or the directory it started in.

- Evidence: [Aquamacs #251](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/251)
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-startup-does-not-touch-ordinary-emacs-home`, `ert:glassmacs-package-state-is-isolated`, `ert:glassmacs-empty-home-variable-means-the-default-home`, `ert:glassmacs-native-compilation-does-not-use-user-cache`, `gui:launch-clean-home`

## PREF-003

**Safe local variables and upgrades keep the user's choices** (P1). Answers to file-local variable questions are customizations; an upgraded app must read the existing home.

- Evidence: [Aquamacs #251](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/251)
- Layers: A (batch), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-safe-local-variables-are-saved-in-glassmacs-home`, `gui:user-emacs-init-is-not-loaded`, `gui:preferences-persist-across-relaunch`
- Manual: see [checklist](macos-acceptance-checklist.md#pref-003)

## SPELL-001

**Spell checker discovery and absence** (P1). Glassmacs uses enchant-2, hunspell or aspell when present and must keep editing working without any.

- Evidence: [Aquamacs #265](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/265)
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-spelling-prefers-enchant-then-hunspell-then-aspell`, `ert:glassmacs-spelling-missing-checker-explains-installation`, `ert:glassmacs-spelling-real-checker-flags-only-prose-misspellings`, `gui:launch-clean-home`

## SPELL-002

**Interactive spelling suggestions** (P1). Correction choices are shown by ispell/flyspell menus, drawn by Cocoa.

- Evidence: [Aquamacs #235](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/235)
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-spelling-highlights-but-never-changes-typed-text`, `ert:glassmacs-spelling-document-check-accepts-skipped-words-for-session-only`
- Manual: see [checklist](macos-acceptance-checklist.md#spell-002)

## SPELL-003

**Native spelling never corrects or substitutes** (P0). macOS spelling (AppleSpell via enchant) must only check, never correct, quote or replace.

- Evidence: `policy:literal-text-entry`
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-spelling-never-corrects-on-its-own`, `ert:glassmacs-spelling-while-typing-is-prose-only-and-opt-in`
- Manual: see [checklist](macos-acceptance-checklist.md#spell-003)

## REVERT-001

**Files changed by other programs update; unsaved edits are kept** (P1). Found by this audit: Glassmacs had no auto-revert; added (glassmacs-follow-file-changes). On macOS it polls, as Aquamacs 4 settled on: kqueue notifications need a descriptor per file and miss files replaced by rename.

- Evidence: [Aquamacs #245](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/245)
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-editing-follows-external-file-changes`, `ert:glassmacs-editing-external-change-never-discards-unsaved-edits`, `ert:glassmacs-editing-file-following-is-interactive-and-optional`, `ert:glassmacs-editing-file-following-polls-on-macos`, `gui:external-file-changes`

## NATIVE-001

**Bundled native code loads without a compiler; no user cache** (P1). Only the bundle's signed .eln files are loaded; JIT compilation and trampolines are off.

- Evidence: [Aquamacs #253](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/253)
- Layers: A (batch), B (packaged app, static), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-native-jit-is-disabled-by-default-before-packages`, `ert:glassmacs-native-compilation-does-not-use-user-cache`, `py:test_native_compilation_is_configured_before_package_loading`, `gui:launch-clean-home`
- Manual: see [checklist](macos-acceptance-checklist.md#native-001)

## NATIVE-002

**Packages work when native compilation is unavailable** (P1). Packages load as byte code because Glassmacs never compiles native code at run time.

- Evidence: [Aquamacs #253](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/253)
- Layers: A (batch)
- Tests: `ert:glassmacs-ordinary-elisp-and-bytecode-remain-loadable`, `ert:glassmacs-native-jit-is-disabled-by-default-before-packages`

## DIALOG-001

**Open and recent-file dialogs do not hang** (P1). File > Open uses the Cocoa open panel when invoked from the menu.

- Evidence: [Aquamacs #255](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/255), [Aquamacs #241](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/241)
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-recent-files-respects-document-policy`, `ert:glassmacs-recent-files-rejects-missing-path`
- Not fully automated because: The Cocoa open panel needs a person; elsewhere, every GUI scenario has deadlines, so a hang fails CI rather than stalling it.
- Manual: see [checklist](macos-acceptance-checklist.md#dialog-001)

## FULL-001

**Closing full-screen windows** (P1). Full-screen windows live in their own Space; closing the last one must hide it, not quit.

- Evidence: [Aquamacs #218](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/218), [Aquamacs #160](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/160)
- Layers: C (GUI in CI), D (manual)
- Tests: `gui:fullscreen-close-and-reopen`
- Not fully automated because: CI uses toggle-frame-fullscreen; the green button and Spaces animation need a person.
- Manual: see [checklist](macos-acceptance-checklist.md#full-001)

## CLOSE-001

**Command-W never loses unsaved changes** (P0). Command-W closes the document and window; Save / Don't Save / Cancel must protect edits.

- Evidence: [Aquamacs #218](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/218), `glassmacs:issue-34-scenario-6`
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-close-cancel-keeps-modified-document-open`, `ert:glassmacs-close-dont-save-discards-without-writing`, `ert:glassmacs-close-save-writes-then-closes`, `ert:glassmacs-close-button-cancel-keeps-frame-open`, `gui:command-w-never-loses-changes`

## CLOSE-002

**Quitting with unsaved documents asks first** (P0). Command-Q and other quit paths must not discard edits silently.

- Evidence: `glassmacs:issue-34-scenario-6`
- Layers: A (batch), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-recovery-direct-kill-guard-blocks-unsaved-documents`, `ert:glassmacs-macos-explicit-quit-is-not-intercepted`, `gui:quit-with-unsaved-document-asks`
- Manual: see [checklist](macos-acceptance-checklist.md#close-002)

## RESTORE-001

**Workspace restore reopens files once and starts no processes** (P1). Opt-in desktop.el restore after normal quit or crash.

- Evidence: `glassmacs:issue-34-scenario-2`
- Layers: A (batch), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-workspace-round-trip-reopens-local-files-only`, `ert:glassmacs-workspace-restores-once-from-glassmacs-home`, `ert:glassmacs-workspace-and-recovery-after-abnormal-shutdown`, `gui:crash-restore-recovery-and-finder-open`
- Manual: see [checklist](macos-acceptance-checklist.md#restore-001)

## RECOVER-001

**Crash recovery is offered and never overwrites data** (P0). Snapshots of unsaved edits must survive a crash and the next startup.

- Evidence: `glassmacs:issue-34-scenario-2`
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-recovery-crash-restore-does-not-replace-quit-index`, `ert:glassmacs-workspace-and-recovery-share-a-clean-file-buffer`, `gui:crash-restore-recovery-and-finder-open`

## TEXT-001

**Typed text stays literal in code, consoles and mixed documents** (P0). No autocorrect, smart quotes, dashes or substitutions unless explicitly enabled, and never in source code.

- Evidence: `policy:literal-text-entry`
- Layers: A (batch), C (GUI in CI), D (manual)
- Tests: `ert:glassmacs-editing-literal-text-entry`, `ert:glassmacs-latex-typing-is-literal`, `ert:glassmacs-editing-markdown-typing-is-literal`, `ert:glassmacs-polymode-typing-is-literal-in-prose-and-chunks`, `gui:command-w-never-loses-changes`
- Not fully automated because: CI types through System Events only when Accessibility is granted; otherwise keys are Emacs events.
- Manual: see [checklist](macos-acceptance-checklist.md#text-001)

## KEY-001

**International keyboards, input methods and Option keys** (P1). The right Option key types characters; input methods compose text through Cocoa.

- Evidence: `policy:literal-text-entry`
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-editing-right-option-types-characters-on-macos`
- Manual: see [checklist](macos-acceptance-checklist.md#key-001)

## CLIP-001

**Clipboard round trip with other apps** (P1). Copy and paste must keep quotes, dashes and non-ASCII text unchanged.

- Evidence: `policy:literal-text-entry`
- Layers: C (GUI in CI)
- Tests: `gui:clipboard-round-trip`

## ENC-001

**File encodings and line endings round trip** (P2). Editing must not convert byte-order marks, Latin-1 or CRLF files.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: A (batch)
- Tests: `ert:glassmacs-files-round-trip-encodings-and-line-endings`, `ert:glassmacs-plain-text-files-open-and-save-without-research-tools`

## PATH-001

**Finder launches find tools on the login-shell PATH** (P1). launchd gives apps a minimal PATH; Glassmacs imports the login shell's.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-environment-imports-variables-from-login-shell`, `ert:glassmacs-environment-times-out-without-blocking-startup`, `gui:launch-clean-home`

## ASSOC-001

**Finder document types are declared** (P1). Merging Info.plist must keep upstream and Glassmacs document types.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: B (packaged app, static)
- Tests: `py:test_info_plist_merge_keeps_upstream_document_types`, `py:test_validator_shell_entrypoint_runs_with_literal_python_heredoc`

## ASSOC-002

**Documents open by type through LaunchServices** (P1). open -a delivers R, R Markdown, Quarto and Sweave documents; Finder's default app is the user's choice.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: C (GUI in CI), D (manual)
- Tests: `gui:finder-open-while-windowless`, `gui:finder-repeat-and-mixed-documents`
- Manual: see [checklist](macos-acceptance-checklist.md#assoc-002)

## PKG-001

**Optional packages are offered once; declining installs nothing** (P1). Startup must not reach the network; the offer comes after the document is visible.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: A (batch), C (GUI in CI)
- Tests: `ert:glassmacs-packages-decline-installs-nothing`, `ert:glassmacs-packages-offer-is-asked-once-per-session`, `gui:package-offer-declined-installs-nothing`

## MIX-001

**Mixed documents: modes, shared R target, chunks, literal typing, spelling** (P1). R Markdown, Quarto and Sweave with polymode's indirect chunk buffers.

- Evidence: `glassmacs:mixed-documents`
- Layers: A (batch)
- Tests: `ert:glassmacs-polymode-r-markdown-uses-poly-r`, `ert:glassmacs-polymode-sweave-uses-poly-noweb`, `ert:glassmacs-polymode-target-chosen-in-a-chunk-survives-switching`, `ert:glassmacs-polymode-run-chunk-from-inside-the-chunk`, `ert:glassmacs-polymode-spelling-skips-chunk-code`, `ert:glassmacs-chunks-run-in-a-real-r-session`, `ert:glassmacs-chunks-spelling-skips-chunk-and-inline-code`

## MIX-GUI-001

**Mixed documents in the app: document menu and Command shortcuts** (P1). Command chords arrive from Cocoa as integer and symbol events that the document keymap must match.

- Evidence: `glassmacs:mixed-documents`
- Layers: C (GUI in CI), D (manual)
- Tests: `gui:finder-repeat-and-mixed-documents`, `ert:glassmacs-chunks-shortcuts-and-menu`
- Manual: see [checklist](macos-acceptance-checklist.md#mix-gui-001)

## MIX-002

**Rendering and Shiny previews open their output** (P1). Rendered HTML opens in the browser, PDF in Skim or Preview; Shiny opens once listening on 127.0.0.1.

- Evidence: `glassmacs:mixed-documents`
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-documents-real-rmarkdown-render-opens-html`, `ert:glassmacs-documents-real-shiny-app-serves-at-its-reported-address`, `ert:glassmacs-documents-shiny-opens-the-app-once-it-is-listening`
- Manual: see [checklist](macos-acceptance-checklist.md#mix-002)

## R-001

**ESS, R and Quarto run from the app** (P1). Subprocesses need the imported PATH and the R installation's Quartz device.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-ess-starts-r-and-evaluates-when-available`, `ert:glassmacs-chunks-run-in-a-real-r-session`
- Not fully automated because: R is not installed on the macOS runner; ESS/R runs in the Linux integration job.
- Manual: see [checklist](macos-acceptance-checklist.md#r-001)

## SYNC-001

**Skim SyncTeX forward and inverse search** (P2). Skim's displayline and its inverse-search command.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: A (batch), D (manual)
- Tests: `ert:glassmacs-latex-prefers-skim-for-synctex-on-macos`
- Manual: see [checklist](macos-acceptance-checklist.md#sync-001)

## DISPLAY-001

**Multiple displays, Spaces, Stage Manager and scaling** (P2). Frame placement and redisplay are Cocoa's.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: D (manual)
- Manual: see [checklist](macos-acceptance-checklist.md#display-001)

## APPEAR-001

**Light and dark appearance changes** (P2). Glassmacs does not yet follow the system appearance (deferred).

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: D (manual)
- Manual: see [checklist](macos-acceptance-checklist.md#appear-001)

## SEC-001

**Developer ID signing, notarization and Gatekeeper** (P0). Release builds must pass notarization and Gatekeeper on a fresh Mac.

- Evidence: [Aquamacs #264](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/264), `glassmacs:issue-34-other-risks`
- Layers: A (batch), D (manual)
- Tests: `py:test_hardened_signing_preserves_library_validation_and_signing_order`, `py:test_accepted_release_staples_then_validates_before_final_archive`, `py:test_missing_submission_id_and_gatekeeper_failure_prevent_final_archive`
- Not fully automated because: Needs the maintainer's Developer ID; maintainers reported a successful run for an earlier build, which does not certify the current tree.
- Manual: see [checklist](macos-acceptance-checklist.md#sec-001)

## PERM-001

**No privacy permission prompts at launch** (P2). Glassmacs should not ask for Files, Automation or Accessibility access until a user action needs it.

- Evidence: `glassmacs:issue-34-other-risks`
- Layers: D (manual)
- Manual: see [checklist](macos-acceptance-checklist.md#perm-001)

## UPSTREAM-001

**NS scroll crash fixed after Emacs 31.1 (bug#81585)** (P1). Upstream b59a6ea35 (master only) fixes negative destinations reaching ns_scroll_run; Aquamacs 4 carries it (b52cca9aa9), the bundled Emacs 31.1 does not.

- Evidence: `glassmacs:emacs-31-1-missing-ns-fixes`
- Layers: D (manual)
- Not fully automated because: Glassmacs bundles the released Emacs binary and carries no C patches; the fix arrives with the pin.
- Manual: see [checklist](macos-acceptance-checklist.md#upstream-001)

## UPSTREAM-002

**NS freeze from events sent to a closed window, fixed after Emacs 31.1 (bug#72496)** (P1). Upstream ef448d2ca (master only) addresses app-defined events to a window that exists; Glassmacs hides and restores frames, the path this concerns.

- Evidence: `glassmacs:emacs-31-1-missing-ns-fixes`
- Layers: C (GUI in CI), D (manual)
- Tests: `gui:last-window-close-and-dock-reopen`, `gui:fullscreen-close-and-reopen`
- Not fully automated because: The GUI scenarios close and reopen windows under deadlines, so a freeze fails them, but the race is not reliably reproducible.
- Manual: see [checklist](macos-acceptance-checklist.md#upstream-002)
