# Linked presentations — Phase 1 source-call-path inventory

Document ID: DOC-LINKED-PHASE1
Status: Initial source audit; no runtime modifications
Last reviewed: 2026-11-06

## Scope and evidence

Read the current `main`-derived `docs/linked-presentations-phase0` branch at the time of this audit. This is a static source inspection, **not** a native GUI verification, exhaustive transitive call graph, or inspection of PR #96's unmerged diff. Existing Phase 0 evidence is recorded in [the baseline](linked-presentation-phase0.md). Design requirements are in [the architecture](linked-presentation-architecture.md).

## Confirmed central seams

| Entry point / function | Current route / decision | Risk and proposed test |
| --- | --- | --- |
| `glassmacs-present-buffer` (`glassmacs-frames.el` ~106) | `open` and `focus` immediately reuse any `get-buffer-window` result; otherwise may ensure frame, `switch-to-buffer`, `make-frame`, `tab-bar-new-tab`, or delegate explicit intents to placement helper | **High:** visibility is not suitability. Test existing view in wrong frame, appropriate frame, and explicit split; preserve old behavior until suitability logic is proven. |
| `glassmacs--open-file-with-policy` (~186) | `find-file-noselect` then document presenter for graphical interactive opens; direct `switch-to-buffer` fallback | **Low/medium:** test Finder, C-x C-f, already-open document, non-graphic and wildcard paths. |
| `glassmacs--ns-find-file` (~201) | Targeted advice around Cocoa open event; routes to file-open policy | **Medium:** native Finder events require local macOS acceptance. Do not remove targeted advice. |
| `glassmacs-new-document` / `glassmacs-new-buffer-in-mode` (~445/486) | Direct `switch-to-buffer` exists in creation paths | **Medium:** audit exact conditions; distinguish untitled document creation from new R process. |
| `glassmacs-focus-open-document` / window menu (~553/606) | Navigation via `glassmacs-present-buffer ... 'focus` or frame choice | **Low:** ensure focus does not create duplicates or replace unrelated document. |
| `glassmacs-open-preferences-group` (~64) | `make-frame` or reuse Customize frame; Customize can bypass display rules | **Medium:** verify repeat opening and source preservation. |
| `glassmacs--display-preferences` (~50) | Registered `display-buffer-alist` rule; reuse visible view or pop up frame | **Low:** check no impact on transient/internal buffers. |
| `glassmacs--close-view` / `glassmacs-close-document` (~327/343) | `delete-window` or `delete-frame` after lifecycle checks | **High:** protect modified buffers and live R processes; native Cmd-W/Q cancel behavior. |
| `glassmacs-buffer-placement--display` (~44) | Explicit `new-frame`, `new-tab`, split, replace; direct Emacs primitives | **Medium:** legitimate low-level adapter, not an automatic bypass; test source preservation and selected-frame side effects. |
| `glassmacs-move-buffer-to` (~159) | Creates destination, then removes source view, records undo | **High:** test inactive tabs, stale frames, source view changes, rollback and modified content. |
| `glassmacs-show-buffer-in` (~219) | Creates additional view without removing original | **Medium:** validate duplicate views are intentional; process identity unchanged. |
| `glassmacs-undo-last-buffer-move` (~112) | Restores source only if safe, may create split, removes destination | **High:** test unrelated destination protection, frame deletion, tab changes. |
| `glassmacs-r-display-console` (`glassmacs-sessions.el` ~585) | Any visible console is focused immediately; else frame/split/current-window based on `glassmacs-r-console-placement` | **P0:** same visibility shortcut as general presenter; known console placement failure on installed 2885efd. PR #96 addresses startup, GUI unverified. |
| `glassmacs-r-start-session` (~731) | `call-interactively 'R` synchronously starts ESS; registers process after; restores source if ESS replaced it; calls console display for separate-window preference | **P0:** must test ESS post-startup view, two sessions, source preservation and real frame placement; do not claim PR #96 fix in this branch. |
| `glassmacs-r-new-console` (~773) | Delegates to `glassmacs-r-start-and-target-session` | **High:** verify distinct process and session when invoked twice. |
| `glassmacs-r-start-or-switch-console` (~656) | **Reuses an existing session if one resolves**, starts only when none exists | **High UX ambiguity:** this is not a New R Console command. Source toolbar labels it “Start R / Console”; clicking it cannot guarantee another process. Confirm which GUI control the user used before changing semantics. |
| `glassmacs-r-switch-console` / `glassmacs-r-inspect-session` (~778/667) | Existing-session selection invokes `glassmacs-r-display-console` | **Medium:** focus must not create new process or extra frame. |
| `glassmacs-r-hide-console` (~610) | Deletes dedicated frame or replaces visible console with previous/scratch; preserves process | **High:** test multiple console views, last frame, close vs termination. |
| `glassmacs-r-move-console-to-new-frame` (~639) | Separate `make-frame` + source `switch-to-prev-buffer` | **Medium:** duplicate implementation path; classify for later consolidation, not immediate refactor. |
| `glassmacs-r--display-help` (~548) | Registered `display-buffer-alist` action; reuses visible help or opens native frame/side pane | **Medium:** help currently passed scripted GUI; retain behavior and test two topics. |
| `glassmacs-r-inspect-directories`, session list, queue views (~683/824/1116) | Direct `display-buffer` for diagnostic/utility buffers | **Low:** likely appropriate upstream semantics; classify before routing through policy. |
| `glassmacs-recovery--restore-window-layout` (`glassmacs-recovery.el` ~328) | Recreates frames and sets windows directly; fallback `display-buffer` | **High:** restoration is an intentional exception to default open policy; test idempotence, dirty content, stale layouts. |
| `glassmacs-recovery-restore` (~407) | Uses `glassmacs-present-buffer ... 'open 'new-frame` for interactive graphical restore | **High:** existing visibility shortcut and restore semantics need tests; no inference of R process restoration. |
| `glassmacs-r-ui-help` (`glassmacs-r-ui.el` ~154) | Calls ESS help with unified help rule installed | **Low:** preserve coexisting help frames. |
| R source toolbar (`glassmacs-r-ui.el` ~172) | “Start R / Console” binds to `glassmacs-r-start-or-switch-console`, not `glassmacs-r-new-console` | **High:** user expectation mismatch; consider explicit separate New and Show actions only after UX decision and GUI test. |

## Preliminary findings

1. **One repeated mechanism:** both the central presenter and R console presenter treat any visible buffer as sufficient. Role- and intent-aware suitability is the appropriate *future* correction, but must not be applied globally without tests.
2. **A concrete creation-versus-selection ambiguity:** `glassmacs-r-start-or-switch-console` deliberately reuses an existing process. The R source toolbar invokes it. This may explain the reported “new buffer” action selecting an existing console; the exact control was not confirmed.
3. **Multiple intentional direct Emacs calls:** low-level move/show operations, recovery layout reconstruction, diagnostic views, and lifecycle close paths cannot all be blindly routed through `glassmacs-present-buffer`.
4. **Separate policy variables already exist:** document, R console, R help, and preferences placement settings. Do not replace these with a new profile setting in Phase 1.
5. **Recovery and close are higher-risk than opening:** retain them as distinct audited lifecycle operations.

## Next audit work and coverage gaps

- Inspect remaining call sites in menu setup, native Cocoa lifecycle, document close, recovery, and tests with full surrounding control flow.
- Enumerate existing ERT test names and map them to the rows above; source inspection alone does not establish coverage.
- Verify exact startup command/menu invoked for the multiple-R-console complaint. Do not redefine ordinary File > New.
- Compare PR #96's proposed startup changes separately, then repeat GUI acceptance on a build identified by its SHA.
- Phase 2 may add **read-only** role classification with no startup effects. Do not start Phase 2 until Phase 1 coverage inventory and review are complete.

## Migration order (proposed, not authorized)

1. Read-only classifier and tests.
2. Read-only suitability diagnostics against existing view placement.
3. Focused console startup and New-vs-Show UI validation, with PR #96 coordinated separately.
4. Document opening/navigation integration.
5. Help/preferences and utility presentation classification.
6. Manual move/show and undo consolidation.
7. Recovery and native close only after dedicated GUI safety gates.

**No source behavior changes are made by this audit.**

## Phase 1 continuation: native lifecycle and test coverage

### Native close/reopen call graph (confirmed from source)

- Hybrid Command-W: `lisp/glassmacs-keys.el` maps `s-w` to `glassmacs-close-document`. This asks about hiding a last visible live R console, then saves/discards/cancels exclusive ordinary documents, then `glassmacs--close-view` deletes a split, tab, or frame.
- Cocoa red close button: `handle-delete-frame` has **targeted** around-advice `glassmacs--handle-delete-frame-preserving-app` installed in `glassmacs-macos.el`. It calls `glassmacs-close-frame-documents`; cancel prevents close. The last visible top-level graphical frame is hidden instead of quitting.
- Programmatic `delete-frame`: targeted around-advice `glassmacs--delete-frame-preserving-app` hides the sole remaining graphical frame. **Important nuance:** this wrapper does not itself run the document close confirmation sequence; do not assume every programmatic deletion is equivalent to Cmd-W.
- Dock reopen / new window: `glassmacs--show-hidden-final-frame`, `glassmacs-reopen`, and `glassmacs-new-window` reuse a retained hidden frame where possible. A post-command hook reveals it after commands that require a visible window.
- Explicit Quit: the native Cocoa close interception deliberately does not replace `save-buffers-kill-emacs`. Recovery has separate quit-review entry points and hooks; test the two paths independently.
- Recovery: `glassmacs-recovery--restore-window-layout` intentionally uses `make-frame`, `set-window-buffer`, splits and a fallback `display-buffer`; restoring layout is not ordinary opening. A second graphical restore path calls the central presenter.

### Existing ERT coverage mapped to behavior (test names inspected; tests not run)

| Area | Existing tests / evidence | Remaining coverage or GUI gate |
| --- | --- | --- |
| Cmd-W, save/discard/cancel, shared document view | `tests/test-glassmacs-close.el`: `glassmacs-close-cancel-keeps-modified-document-open`, `glassmacs-close-dont-save-discards-without-writing`, `glassmacs-close-save-writes-then-closes`, `glassmacs-close-keeps-document-shown-in-another-window` | Native sheet focus, tab interaction, multiple modified documents and real mouse click |
| Live console close confirmation | `glassmacs-console-close-dismissed-dialog-preserves-live-session`; `glassmacs-close-never-kills-console-or-special-buffers` | Real process survives last-view close, multiple console views, Cancel under Cocoa |
| Cocoa close and final frame | `tests/test-glassmacs.el`: `glassmacs-macos-cocoa-close-of-final-frame-does-not-quit`, `glassmacs-macos-closing-nonfinal-frame-deletes-only-that-frame`, `glassmacs-macos-reopen-restores-hidden-frame-without-duplicating-it`; `tests/test-glassmacs-close.el`: `glassmacs-close-button-cancel-keeps-frame-open` | Native event delivery and hidden/visible frame focus, programmatic deletion semantics |
| Quit routing | `glassmacs-native-and-emacs-quit-entry-points-are-intercepted`, `glassmacs-native-quit-command-routes-through-review`, `glassmacs-macos-explicit-quit-is-not-intercepted` | Full native Cmd-Q Save/Don't Save/Cancel across documents |
| New documents and opening | `glassmacs-new-document-uses-each-configured-policy`, `glassmacs-cocoa-file-open-event-uses-document-policy`, `glassmacs-visible-document-is-not-opened-in-an-extra-frame`, `glassmacs-new-buffer-in-mode-creates-distinct-mode-buffer` | Native Finder and new-buffer menu in second frame |
| Hidden final frame | `glassmacs-windowless-new-document-reuses-hidden-frame-per-policy`, `glassmacs-windowless-buffer-command-reveals-frame`, `glassmacs-windowless-dock-reopen-creates-no-buffers` | Actual Dock and menu activation |
| Manual placement | `glassmacs-buffer-placement-replace-preserves-buffer`, `glassmacs-buffer-placement-split-preserves-original-view` in `tests/test-glassmacs.el` | Stale frame, inactive tab, move/undo with unrelated buffer, new view vs move |
| Session identity | `tests/test-glassmacs-sessions.el`: `glassmacs-sessions-identity-and-registration`, `glassmacs-sessions-does-not-guess-among-several`, `glassmacs-r-explicit-source-targets-stay-on-process-incarnation`, concurrent real ESS integration tests | Real native two-console placement and post-ESS startup suitability; new vs show GUI command |
| R toolbar command | `glassmacs-r-toolbar-uses-shared-commands`, `glassmacs-r-console-launch-is-available-without-session` in `tests/test-glassmacs.el` | The existing tests explicitly expect start-or-switch; separate New/Show UX is a future decision |
| Recovery | `tests/test-glassmacs-recovery-home.el` covers isolation of recovery directory, not presentation restoration; other recovery tests need a full-name inventory | Duplicate-frame prevention, multiple dirty restored views, saved layout, no process relaunch |

### Native acceptance harness

`scripts/macos-gui-acceptance` contains explicit Cocoa close-button, Cmd-W and quit scenarios, plus broader GUI acceptance. Its presence does **not** establish that the installed candidate passed each scenario. Check recorded results against a named app SHA. Do not confuse mocked ERT lifecycle tests with real Cocoa event delivery.

### Specific safety hazards to track

1. The final-frame `delete-frame` wrapper and Cocoa close-button path are intentionally different; adding generic presentation hooks here could bypass save/cancel review.
2. `glassmacs--close-documents-in-windows` collects decisions before killing buffers, but saves may already have happened when a later document cancels. Preserve this documented non-atomic behavior until a separately designed change.
3. `glassmacs-r-hide-console` directly deletes a frame; do not introduce a new console-close confirmation cycle accidentally through generic lifecycle changes.
4. The recovery renderer may create new frames even when a buffer already has a view; any deduplication must account for saved layout intent rather than simply skipping visible buffers.
5. The R toolbar start-or-switch binding is asserted by existing tests; changing it is an intentional UX change requiring test updates and explicit acceptance, not a silent bug fix.

### Phase 1 disposition

Native lifecycle paths and representative ERT coverage have been mapped from source. **Outstanding:** exhaustive enumeration of recovery tests, all direct-display calls in remaining modules, CI/test execution, and native GUI evidence. No code changes authorized or performed.

## Approved UX decision and source-execution audit

The user clarified the previously ambiguous toolbar intent: **the console toolbar button must always create a new console**. The source must also offer a separate **Link Console** button. Running source code with no explicit live link must prompt to choose a console and link it before execution. This is an approved future behavior change; the currently shipped toolbar and resolver do not implement it.

Current code:
- `glassmacs-r-ui--toolbar-actions` binds “Start R / Console” to `glassmacs-r-start-or-switch-console`; this reuses a resolvable existing console. **Replace binding and label in a dedicated implementation PR**, and update tests that assert the old binding.
- `glassmacs-r-new-console` already delegates to independent startup and targeting. Confirm real ESS process identity and distinct frame placement (coordinate with PR #96).
- `glassmacs-r-select-session` already provides a session chooser; `glassmacs-r--set-document-target` propagates target across polymode indirect buffers. Reuse these for **Link Console** rather than introducing a second link registry.
- `glassmacs-sessions-resolve` currently falls back to the sole live session and may use ESS-local process affinity. This must be **narrowed for source execution**: prompt and establish explicit document link before sending. Do not globally change resolver semantics without auditing console controls, queued operations, batch tests, and one-off commands.
- `tests/test-glassmacs-r-ui.el` covers source target indicators, stale-target handling, polymode behavior, one-off sends, and ESS entry points; `tests/test-glassmacs-documents.el` covers R chunks and target propagation. Add tests for no link + one live session, no link + multiple sessions, no consoles, cancel, stale link, explicit linked execution, two source docs, and indirect chunk buffers.

### Remaining direct-display inventory (additional modules)

| Module | Direct display behavior | Classification / next action |
| --- | --- | --- |
| `glassmacs-core.el` | `display-buffer` for process/output buffers | Utility/diagnostic; no blanket native-frame policy |
| `glassmacs-remote.el` | `display-buffer` and `pop-to-buffer` for remote workflow buffers | Remote/utility; preserve remote safeguards |
| `glassmacs-diagnostics.el` | `display-buffer` for diagnostics | Utility; no document-window takeover without explicit request |
| `glassmacs-sessions.el` | `display-buffer` for R directory inspection, session list, queue views | Utility; classify separately from console and help |
| `glassmacs-recovery.el` | Direct frame construction and fallback display | Intentional restoration path, not ordinary opening |
| `glassmacs-frames.el` | Central presenter, preferences, document opening, close | Existing primary seam |
| `glassmacs-r-ui.el` | Uses ESS help and toolbar/menu dispatch; no direct `display-buffer` call in inspected file | Entry-point routing rather than low-level placement |

### Recovery test inventory

- `tests/test-glassmacs-recovery-home.el`: isolated recovery directory and external index isolation.
- `tests/test-glassmacs-workspace.el`: opt-in restore, single restore, batch prohibition, local-only files, no repeated reads, remote exclusion, workspace/recovery interaction, clean buffer sharing.
- `tests/test-glassmacs.el`: native frame lifecycle, document open, windowless reopen and buffer placement.
- **Gap:** no dedicated recovery presentation test file was found among the inspected paths. Search across all test sources for recovery-specific ERT names before declaring exact coverage. GUI recovery of splits, frame geometry, duplicate prevention and process non-restart remains an acceptance gate.

### Phase 1 closure

The primary call paths, native lifecycle boundaries, representative test coverage, and remaining direct-display modules are now recorded. No code was modified. The R toolbar/link/execution UX decision is approved for a *subsequent, isolated runtime PR* with regression tests. The Phase 1 source inventory is complete at module/entry-point level, **not** a proven exhaustive dynamic call graph; GUI tests and CI were not run for this documentation change.
