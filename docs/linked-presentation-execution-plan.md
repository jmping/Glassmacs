# Linked window presentations — integration execution plan

> **Document ID:** DOC-LINKED-EXECUTION-PLAN  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-06  
> **Coverage:** Linked presentation architecture and implementation tracking  
> **Supersedes:** None


**Document ID:** DOC-LINKED-EXECUTION-PLAN  
**Status:** Active implementation plan  
**Updated:** 2026-11-06  
**Integration PR:** #98 (`integration/linked-window-presentations`)  
**Baseline:** `main` at `a8f3ec1`; PR #96 patch `336498cc` included, PR #97 architecture and Phase 0/1 documents imported. Neither #96 nor #97 is merged. **No native GUI acceptance claim.**

## Scope and non-regression contract

Deliver consistent macOS document frames, tabs, R console and R help presentation, source-to-console links, buffer movement, native close/reopen and recovery. Preserve current functional app behavior until a replacement has focused automated coverage. Keep Emacs authoritative for buffers/windows/frames. A buffer may have multiple views; a process is independent of its views. Never globally advise Emacs display/window primitives. Closing a console presentation must not kill its R process. Preserve native Command-W/close-button/Command-Q save/cancel distinctions, final hidden-frame behavior, explicit opening policy, session identity, project/remote safeguards and crash recovery. Do not touch the separate `feat/project-aware-execution` worktree.

## Approved R interaction contract

- Source toolbar **New R Console** always starts a *new* independent ESS/R process, regardless of existing sessions. This is a process-creation command, not Show/Switch.
- Source toolbar **Link Console…** chooses an *existing live* session, associates it with the current document and polymode indirect buffers, and starts no process. Cancel leaves existing link unchanged.
- **Show Console** brings an existing session view forward, without starting a process. Additional views are distinct from moving an existing one.
- On any user-initiated source execution (line, selection, paragraph, function, buffer, ESS region/function entry points), a valid explicit document link is authoritative. If unlinked, prompt for an existing live console **even when only one exists**, then persist the chosen link *before sending*. Cancel sends nothing and changes no link. No live sessions means a clear error and no implicit startup. A stale explicit link is an error, never silent fallback.
- Do not impose interactive prompts on background queues, console-local operations, deterministic noninteractive tests, or explicit one-off operations without separately specifying their semantics.
- Reuse existing `glassmacs-r-new-console`, `glassmacs-r-select-session`, `glassmacs-r--set-document-target` and session registry. Audit all execution paths before changing `glassmacs-sessions-resolve`; avoid a global resolver change.

## Ordered implementation stages and acceptance gates

### S0 — Integration baseline (incorporated; revalidation pending)

- PR #96 runtime patch and tests plus PR #97 documents imported to draft PR #98.
- Preserve PR #96's original report: bundled Emacs 433 total / 415 passed / 18 skipped / 0 failed; real ESS/R 24/24. **Not a test run on PR #98.**
- Run branch CI, `scripts/test`, documentation checks and byte compile; record actual integration SHA and results. If runner unavailable, mark unverified rather than passing.

### S1 — R console creation, linking, execution (next runtime work)

1. Change source toolbar Console command to `glassmacs-r-new-console`, label **New R Console**; add **Link Console…** command `glassmacs-r-select-session` (and distinct Show Console where appropriate). Update source R menu names, tooltips, icons and test assertions.
2. Introduce a **source-execution-only** target resolver that validates explicit document link or prompts and persists selection. Preserve session incarnation/stale-target protection and indirect buffer propagation. No process startup in resolver.
3. Route every source execution entry point (including ESS-adapted region/function) through it; audit queues and one-off commands before touching their target resolution.
4. ERT: two clicks produce two startup invocations/distinct process IDs; linking does not start R; zero/one/multiple consoles; cancel; stale link; no fallback; two source documents; R Markdown/Quarto/Sweave chunk association; real ESS concurrent integration.
5. Run automated suite before S2. Do not change window lifecycle in S1.

### S2 — Read-only presentation role classification

Create `lisp/glassmacs-presentation-model.el` with pure role classification (ordinary document, R source, R console, ESS help, preferences, utility, internal). No advice, hooks, frame creation, startup effects or implicit ownership. ERT for modes, names, stale buffers, indirect buffers and unclassified cases. Compare classification against existing special-buffer exclusions.

### S3 — Suitability and policy resolver

Implement a pure predicate evaluating whether an existing view suits an intent, role and configured policy. Visibility alone is insufficient. Distinguish `open`, `focus`, `new-view`, `move`, `split`, `tab`, `replace`. Pure policy decisions preserve current defaults; ERT matrix covers separate-frame vs side pane, same buffer in other frame/tab, hidden final frame, inactive tab and terminal fallback.

### S4 — Migrate presentation entry points incrementally

In order: general document presenter, ESS-startup console presenter (integrated #96 behavior), console show/hide, R help, preferences, manual placement and diagnostics as needed. One seam and tests per commit. Avoid global interception of `display-buffer`, `switch-to-buffer`, `set-window-buffer`, `delete-window` or `delete-frame`. Ensure multiple views do not create exclusive ownership.

### S5 — Window actions, tabs and menus

Consolidate New Window / New Document / New View / Move / Show / Switch R Console / Link Console actions and labels. Keep document opening preference and keyboard profile intact. Test Cmd-N, Cmd-W, tabs, move/undo, frame selection and menu command identity. Verify source and console toolbars are distinct.

### S6 — Lifecycle and recovery integration

Preserve separate Cocoa close button, Command-W, programmatic delete-frame, explicit Quit and Dock reopen paths. Confirm save/discard/cancel, multi-view console preservation and final hidden-frame semantics. Recovery recreates saved layouts without starting R or duplicating unintended views; workspace and recovery remain isolated. ERT plus native acceptance gates.

### S7 — Comprehensive macOS GUI acceptance (single major integrated run)

Build exact PR #98 head SHA with bundled Emacs, ESS and R, isolated native-compilation cache (no cross-Team-ID objects), and non-destructive recovery fixture. Verify: separate document frames/tabs; two independent consoles and retained source frames; explicit link and execution routing; R help independent frames; move/new-view/undo; Cmd-W/red close/Command-Q; hidden-frame Dock reopen; crash recovery and no unexpected R process restart; menus and toolbar semantics. Save screenshots, logs, result JSON and exact SHA; distinguish PASS/FAIL/SKIP/UNVERIFIED. No merge to main until required gates pass or explicitly waived.

## Change control and tracking

- Keep PR #98 draft while work proceeds; #96 and #97 remain open, unmerged and historically traceable until #98 is accepted.
- Commit each stage separately, with tests and documentation changes in the same stage where applicable. Run static/document checks before each stage closes.
- Record outcomes and blockers in this file and `docs/documentation-changelog.md`; update the acceptance matrix when GUI scenarios change.
- A GUI-only Mac action may be delegated to local testing; architecture, code, tests and review remain in the integration PR.
- Never claim a test passed unless executed on the named commit. No automatic merge.

## Progress ledger

| Stage | State | Evidence / blocker |
| --- | --- | --- |
| S0 | Integrated; branch CI/test rerun pending | PR #98 initial integration head `2395f485`; inherited #96 test report only |
| S1 | In progress; unverified | Source toolbar New/Link/Show split; source-only explicit resolver; Glassmacs source and ESS-advised entry points updated; initial ERT added. Full regression run, R/ESS integration and additional polymode/opt-out tests pending. |
| S2 | Planned | No classifier runtime file yet |
| S3 | Planned | No suitability resolver yet |
| S4 | Planned | Existing presenters inventoried in Phase 1 |
| S5 | Planned | Native menus and placement require regression tests |
| S6 | Planned | Existing lifecycle and recovery audit recorded |
| S7 | Pending | Native GUI test blocked previously by signed native-code cache mismatch |

## S1 implementation checkpoint — 2026-11-06

Implemented initial source-only link-on-first-execution resolver in `glassmacs-sessions.el` without altering the generic queue/session resolver. The `glassmacs-r.el` editor commands resolve a session explicitly before submitting; ESS-advised region/line/function/buffer routes resolve likewise. The source toolbar now separates New R Console, Link Console and Show Console. Added initial toolbar and resolver ERT. **No tests have been run against these commits; this is not a completed S1 gate.** Remaining: review all affected legacy ERT assumptions, run bundled Emacs suite and real ESS/R integration, confirm cancellation/indirect-buffer behavior and native presentation interactions. The older `glassmacs-r-start-or-switch-console` compatibility command remains available but is no longer used by the source toolbar.
