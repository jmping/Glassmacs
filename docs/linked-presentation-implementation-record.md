# Linked presentations integration — implementation and verification record

> **Document ID:** DOC-LINKED-IMPLEMENTATION-RECORD  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-08  
> **Coverage:** PR #98 implementation, behavior, limits, and release evidence  
> **Supersedes:** None

## Scope and evidence boundary

This is the implementation record for [integration PR #98](https://github.com/jmping/Glassmacs/pull/98), branch `integration/linked-window-presentations`. It supplements the [architecture](linked-presentation-architecture.md), [Phase 1 call-path audit](linked-presentation-phase1-audit.md), and [execution plan](linked-presentation-execution-plan.md). It records implemented code and automated verification, **not a completed interactive macOS acceptance**. Build the exact branch HEAD and record its SHA before interpreting any test result. Earlier documents contain historical proposed or pending states; use this record and the current PR/CI for the integration checkpoint.

**Last automated checkpoint:** commit `518d135b7f082598cdda23728b8593d3666055e5`, [GitHub Actions run 42499095457](https://github.com/jmping/Glassmacs/actions/runs/42499095457): `changes`, `emacs-batch`, `ess-r-integration`, and `macos-launcher` all **success**. The macOS job builds and validates a bundle and runs bundled-Emacs batch tests; it does **not** drive the native GUI. Documentation-only commits after this checkpoint require their own checks, and any subsequent runtime change invalidates the checkpoint for the new HEAD.

## Architecture delivered

Glassmacs retains upstream Cocoa GNU Emacs as the authority for frames, windows, tabs, buffers, and processes. The design separates **logical object**, **buffer**, **presentation/view**, **semantic link**, and **lifetime**. A buffer may appear in multiple views; a document-to-R-session link is not a frame association; hiding a console is not terminating R. No parallel frame registry or blanket advice on Emacs display primitives was introduced.

- `lisp/glassmacs-presentation-model.el`: read-only `glassmacs-presentation-buffer-role` classification for ordinary documents, R source, inferior R console, ESS R help, Customize/Preferences, utility, and internal buffers; `glassmacs-presentation-policy-action` resolves intent and placement; `glassmacs-presentation-view-suitable-p` and `glassmacs-presentation-find-suitable-view` evaluate candidate views. Current-tab identity and explicit destination matter. Explicit `new-view`, `move`, `split`, `tab`, and `replace` do not accidentally reuse an existing view.
- `lisp/glassmacs-frames.el`: `glassmacs-present-buffer` uses the common suitability seam; `new-view` can create an additional split rather than replacing the original. Explicit document navigation (`glassmacs-focus-open-document`) and tab-aware focus can locate existing presentations without conflating navigation with ordinary open policy. Existing user-selected document placement policies remain authoritative.
- `lisp/glassmacs-sessions.el`: R console and R help display use suitability checks. Separate-frame help, where configured and graphical, does not reuse an unsuitable side-pane view. Side-help reuse is limited to a matching side window. Showing an existing console is distinct from starting a new R process.
- Preferences/Customize presentation uses the shared lookup instead of treating the first visible buffer occurrence as necessarily suitable.

## R source execution and sessions

The source toolbar exposes distinct **New R Console**, **Link Console…**, and **Show Console** actions; corresponding source menus/tooltips are updated. New R Console invokes independent session/process creation on every request. Link Console selects an existing live session, without process creation, and associates the **document**, including supported indirect/polymode source buffers, with that session. Show Console navigates to an existing presentation without creating a process.

For interactive source execution, a valid explicit document link is authoritative. If unlinked, the user must select an existing live R console **even when only one exists**; selection is persisted before sending. If no console exists, the command errors and does not launch R. A stale link never silently falls back to another process. Cancel sends no source and leaves the link unchanged. Background/noninteractive paths retain deterministic behavior rather than unexpectedly prompting. Generic session-resolution and process ownership are not globally rewritten.

## Window/menu behavior

- Distinct document opening, focusing, new-view, moving, tabbing, and replacing intents. Automatic presentation does not silently select a hidden tab; explicit navigation may.
- Native Window menu includes **Show Open Document…**; document-centric navigation avoids relying solely on Emacs's mode-line/buffer switcher. Window navigation and reviewed tab close have explicit commands.
- Document, console, help, and preferences presentation each retain their own placement policy. Terminal/headless fallback remains separate from Cocoa frame policy.
- Native close semantics are deliberately not identical to `kill-buffer` or `kill-emacs`: closing a view should not terminate an R process. The final graphical frame can be hidden and later reopened by the existing native lifecycle bridge.

## Reviewed closing and safety

`lisp/glassmacs-frames.el` uses a shared `glassmacs--close-reviewed` coordinator for view, tab, and frame scopes. Command-W/document close, the explicit **Close Current Tab Safely** menu command, and native frame-close preflight converge on reviewed behavior. Frame close enumerates **all tabs**, reviews unique affected modified documents and live consoles, then allows the Cocoa close handler to delete/hide the frame. A canceled decision vetoes the close; an R console is hidden, **not killed**. The original tab is restored after temporary tab enumeration. The document view-close and frame-close paths now account for views in **inactive tabs**, including tabs in other frames, before deciding a buffer is exclusive.

**Limits:** this is not a general transactional filesystem rollback. A save may have completed before a later cancellation; `kill-buffer` hooks can veto after earlier buffers have closed. Tab selection during inspection can invoke tab hooks. Programmatic upstream `delete-frame` and arbitrary package-internal tab-close paths are not all equivalent to the reviewed user commands. These distinctions must be exercised and documented during native GUI testing.

## Crash recovery

`lisp/glassmacs-recovery.el` snapshots durable document IDs, visible frame geometry, tab order, selected tab, per-tab document IDs, selected document, and view point/scroll state. Restoration reconstructs recoverable document tabs and active selection when possible, with bounded geometry and data-only records. Legacy single-layout recovery records remain supported; malformed tab buffer lists are rejected. Missing files/documents are skipped. Dirty edits remain recovered in separate untitled buffers rather than overwriting originals.

**Limits:** recovery does not restore or launch R processes, replay commands, or promise pixel-identical layouts. Non-document tabs are not recreated as live R sessions. Recovery is not a substitute for saving files or external backups. Verify idempotence, source focus, active-tab restoration, and recovery after SIGKILL in the packaged GUI.

## Test and source map

| Area | Primary source | Automated coverage / remaining GUI gate |
| --- | --- | --- |
| Role, intent, suitability, hidden tabs | `lisp/glassmacs-presentation-model.el` | `tests/test-glassmacs.el`; confirm visible native frames and tabs |
| Document opening, navigation, view creation | `lisp/glassmacs-frames.el` | `tests/test-glassmacs.el`; Finder open, Cmd-N, Window menu |
| R console creation/link/execution | `lisp/glassmacs-sessions.el`, `lisp/glassmacs-r.el`, `lisp/glassmacs-r-ui.el` | ERT and real ESS/R CI; two simultaneous real processes and independent source links |
| R help and Preferences placement | `lisp/glassmacs-sessions.el`, `lisp/glassmacs-frames.el` | ERT; multiple help topics, frame/side policy, focus |
| Cocoa menu/close/reopen | `lisp/glassmacs-macos.el`, `lisp/glassmacs-frames.el`, `macos/GlassmacsLifecycle.m` | `tests/test-glassmacs-close.el`, Swift/bundle CI; real red button, Cmd-W, Cmd-Q, Dock |
| Crash snapshot and restore | `lisp/glassmacs-recovery.el` | `tests/test-glassmacs.el`; real crash, multiple tabs, dirty document safety |
| Packaged GUI | `scripts/macos-gui-acceptance` | Local Layer C automated driver and Layer D manual checklist |

## Implementation milestones

The branch incorporates the earlier PR #96 runtime seam and PR #97 architecture/audit work; neither should be described as independently merged solely because its work is included here. The integration proceeded through S1 source/console semantics; S2 role classification; S3 read-only suitability; S4 document/console/help/preferences presenter migrations; S5 explicit tab/window navigation and menus; and S6 reviewed close and multi-tab recovery. Representative later commits: `62a4dba` (early green model checkpoint), `ade1d1b` (reviewed close checkpoint), `f4424a7` and `73c7da9` (inactive-tab close protection), `62768e5` (tab snapshots), `980a689` (tab restoration), and `518d135` (syntax correction and final green runtime checkpoint). Commit history and PR diff are authoritative for exact individual patches.

## Remaining release gate

**Not yet done:** native macOS GUI acceptance on the exact candidate SHA; interactive keyboard/menu/Cocoa events; real R console/help multiwindow behavior; forced-crash recovery; accessibility and visual inspection; packaging provenance and candidate archive. Run the [Copilot candidate handoff](copilot-candidate-handoff.md), retain the resulting evidence bundle, fix failures in this integration branch, rerun CI and GUI acceptance, and only then consider PR #98 merge. The existing [acceptance matrix](acceptance-matrix.md) is generated from `acceptance/matrix.toml`; do not manually edit generated status files.
