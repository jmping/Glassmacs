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
