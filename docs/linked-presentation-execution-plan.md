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
| S0 | CI verified | GitHub Actions run 42331782502 on 231546f: Emacs 407 passed / 33 skipped / 0 failed; real ESS/R 439 passed / 1 skipped / 0 failed; all four jobs green |
| S1 | Implemented; further verification ongoing | Toolbar New/Link/Show, explicit source-only target resolver, ESS-advised execution, multi-session and indirect-buffer tests; CI green on 231546f. Additional error-preservation fix and regression test after green commit require fresh CI. Native GUI remains pending. |
| S2 | CI verified at 62a4dba | Added read-only `glassmacs-presentation-buffer-role` in `lisp/glassmacs-presentation-model.el`, with initial document/R source/indirect/utility/dead-buffer ERT. No hooks, advice or window mutations. Expand role cases and verify CI before calling S2 complete. |
| S3 | CI verified at 62a4dba | Pure intent-to-placement resolver and read-only existing-view suitability predicate added; ERT covers intent, destination, frame suitability and no-reuse operations. Not yet wired into runtime presenters. |
| S4 | In progress; CI pending | Document and R console presenters now consult shared suitability; explicit new-view with reuse-current creates a separate split; focused ERT added. Other presenters and GUI acceptance pending. |
| S5 | Planned | Native menus and placement require regression tests |
| S6 | Planned | Existing lifecycle and recovery audit recorded |
| S7 | Pending | Native GUI test blocked previously by signed native-code cache mismatch |

## S1 implementation checkpoint — 2026-11-06

Implemented initial source-only link-on-first-execution resolver in `glassmacs-sessions.el` without altering the generic queue/session resolver. The `glassmacs-r.el` editor commands resolve a session explicitly before submitting; ESS-advised region/line/function/buffer routes resolve likewise. The source toolbar now separates New R Console, Link Console and Show Console. Added initial toolbar and resolver ERT. **No tests have been run against these commits; this is not a completed S1 gate.** Remaining: review all affected legacy ERT assumptions, run bundled Emacs suite and real ESS/R integration, confirm cancellation/indirect-buffer behavior and native presentation interactions. The older `glassmacs-r-start-or-switch-console` compatibility command remains available but is no longer used by the source toolbar.

## CI regression triage — 2026-11-06

GitHub Actions run `42329573798` on `3837214` reported `ess-r-integration` **success**, `macos-launcher` **success**, and `emacs-batch` **failure**. Emacs batch ran 438 tests: 395 expected results, 9 failures, 1 QUIT, 33 skips. Failures included seven source-editor tests using obsolete queue/target mocks, two toolbar tests expecting old actions, and a new cancellation test treating `quit` as a normal error. Documentation checker rejected four linked-presentation files lacking required blockquote metadata. Corrections have been committed to PR #98: metadata format, updated toolbar expectations, updated source-target test doubles, explicit quit handling, and multi-session/indirect-buffer coverage. **These corrections are not yet validated by a subsequent CI run.** Native GUI acceptance remains pending.

## CI green checkpoint and follow-up — 2026-11-06

CI run [42331782502](https://github.com/jmping/Glassmacs/actions/runs/42331782502) at `231546f`: all four jobs successful. `emacs-batch` ran 440 tests, 407 expected, 0 unexpected, 33 skipped; `ess-r-integration` ran 440 tests, 439 expected, 0 unexpected, 1 skipped. This verifies the S1 regression remediation at that SHA, **not** later changes or native GUI behavior. Subsequent source review found that ESS function-evaluation advice caught errors thrown by console selection and replaced them with a misleading 'No R function' message. Fixed error-handler scope and added a focused regression test; fresh CI required. Next: S2 read-only role classification and S3 suitability policy, maintaining stage gates.

## S2 initial checkpoint — 2026-11-06

Created the isolated, read-only buffer role classifier and initial ERT coverage. It is intentionally not wired into existing presentation policy; there are no new startup hooks, global advice, frame operations, or changes to user-visible placement. This follows the staged migration constraint. Tests on this new commit remain pending; the last verified green SHA is `231546f`.

## S2–S3 implementation checkpoint — 2026-11-06

Added role coverage for R consoles, R help and preferences, plus a pure `glassmacs-presentation-policy-action` and read-only `glassmacs-presentation-view-suitable-p` in `lisp/glassmacs-presentation-model.el`. The predicate rejects reuse for explicit new-view/move/split/tab/replace intents, enforces destination-frame identity and requires a sole ordinary frame window for `new-frame` reuse. Added focused ERT. **These changes are not yet CI-validated and do not change user-facing presentation behavior.** The integration run for the earlier S2 checkpoint is still in progress at last check. Next gate: verify tests, then migrate one presenter seam at a time; defer native GUI acceptance to the integrated macOS run.

## S4 initial runtime integration — 2026-11-07

GitHub Actions run `42338680974` completed successfully on `62a4dba`: `changes`, `emacs-batch`, `ess-r-integration`, and `macos-launcher` all green. This verifies the S2/S3 checkpoint only. Subsequently, `glassmacs-present-buffer` began consulting `glassmacs-presentation-view-suitable-p` before focusing an existing view; the explicit `new-view` intent now creates a separate split under `reuse-current` instead of replacing the original. `glassmacs-r-display-console` now consults the same predicate and loads the model explicitly. Added focused document/console presenter ERT. **These S4 commits are not yet CI-validated and no native GUI checks have been run.** Next: inspect CI for regressions, then migrate help/preferences and explicit placement seams individually.

## S4 second migration checkpoint — 2026-11-07

Migrated ESS R help and Customize/Preferences display presenters to consult the shared existing-view suitability predicate, in addition to document and R console presenters. Added focused ERT for each seam. This is deliberately scoped to the reuse decision; display-buffer action semantics and native lifecycle behavior are otherwise unchanged. The previous S4 CI run `42392830255` was **cancelled**, not successful. New run `42393333377` was **pending** at last check for commit `06247e1`. No GUI verification or S4 completion claim yet. Follow-up: check CI, audit tab identity and multi-view selection, then S5/S6 native actions and recovery.

## S4 multi-view and tab-identity checkpoint — 2026-11-07

Added `glassmacs-presentation-find-suitable-view`, which searches all ordinary windows in each frame's currently selected tab, prioritizes the selected frame (or an explicit destination), and checks each candidate with the shared read-only suitability predicate. Document, R console, R help and Preferences presenters now use this common lookup rather than blindly using `get-buffer-window`'s first result. Added multi-view ERT for unsuitable views and explicit non-reuse intents. **No automatic cross-tab switching** is attempted: tab identity is not inferred from buffer identity, and hidden-tab restoration is reserved for a later explicit tab-aware action. Earlier S4 workflow `42393354336` was cancelled as superseded, not passed. The new commits require CI verification and native GUI acceptance remains outstanding.

## S4 syntax regression and tab identity correction — 2026-11-07

CI run [42393581549](https://github.com/jmping/Glassmacs/actions/runs/42393581549) **failed** at startup due to an unmatched closing parenthesis in the new multi-view finder; Emacs batch and ESS/R could not load the presentation model. Fixed in `5a8907a`. Subsequently hardened the suitability predicate with an explicit current-tab view check and added ERT coverage. CI for the corrected head remains pending. This is a blocking gate: do not mark S4 green, merge, or request GUI acceptance until the current branch passes batch and ESS/R checks. Native tab navigation, close/recovery work remain outstanding.

## S6 native frame close guard — 2026-11-07

Added `glassmacs--frame-has-hidden-tabs-p` and a fail-closed guard in `glassmacs-close-frame-documents`: native close-button requests are vetoed when multiple tabs exist because the existing close-review logic only enumerates the selected tab's windows and would otherwise bypass save/console review for hidden tabs. Added ERT for the veto and for single-tab review continuity. This is a **conservative interim safety behavior**, not a completed multi-tab close transaction: users must close tabs individually before closing their frame. It does not kill R processes. CI for this change remains pending; native Cocoa close-button acceptance remains outstanding. Next implementation should enumerate per-tab document/console views and review them transactionally before allowing a multi-tab frame close.

## S6 reviewed tab-close cut — 2026-11-07

CI run `42397583982` failed while reading `tests/test-glassmacs.el` (`invalid-read-syntax` at line 3023). Corrected the extra parenthesis in the new-view test at `30256a2`; test execution had not started in that failed run. Added `glassmacs-close-current-tab` as an explicit reviewed tab-close operation: it checks live R-console visibility and exclusive document save/discard/cancel decisions before invoking `tab-bar-close-tab`, and delegates to regular document close if there is only one tab. Added cancel and successful-review ERT. This does **not** yet replace Emacs' built-in tab close bindings or the conservative native multi-tab frame-close veto. Current CI and native GUI validation are still required; full multi-tab transactional frame close remains pending.

## S5/S6 user-facing reviewed close checkpoint — 2026-11-07

CI [42398426947](https://github.com/jmping/Glassmacs/actions/runs/42398426947) completed **successfully** on `ade1d1b`, validating the S4 model and initial S6 reviewed-tab command. Added an explicit native Window menu item, **Close Current Tab Safely**, wired to `glassmacs-close-current-tab` with ERT asserting the menu target. No global advice to `tab-bar-close-tab` was introduced, preserving package-internal behavior; default upstream tab-close shortcuts are not yet rerouted. The native close-button multi-tab veto remains in place pending a fully reviewed all-tabs transaction. Latest menu changes need their own CI run and GUI testing.

## S6 all-tabs native frame-close transaction — 2026-11-07

Replaced the conservative native multi-tab frame-close veto with an all-tabs review path. `glassmacs--frame-tab-buffers` temporarily selects each tab, collects its displayed buffers, and restores the original tab with `unwind-protect`. The frame-close path reviews unique live R consoles and modified documents across all tabs before killing exclusive ordinary document buffers. R console buffers/processes are never killed; the console confirmation preference is honored. A canceled prompt leaves all document buffers alive and modified (prior successful saves may have written to disk, as with the existing close policy). Added tests for all-tab routing and cancellation. **Limitations:** killing buffers can be vetoed by hooks after earlier buffers have been killed; complete rollback of such hooks is not supported. Tab selection may run tab hooks. This is not yet native GUI-validated and the current head needs CI. The all-tab review only covers buffers currently displayed in tabs, not unshown buffers. Follow up: CI failure triage, Cocoa close-button smoke, tab-bar integration and recovery.

## S6.2 shared close coordinator — 2026-11-08

Introduced `glassmacs--close-reviewed` with explicit `view`, `tab`, and `frame` scopes. Command-W/document close, the reviewed Window-menu tab close, and native frame-close preflight now use this common entry point. The frame scope still reviews all tabs and leaves actual frame deletion to Cocoa; the tab scope invokes tab-bar closing only after review; the view scope delegates to the existing view/frame fallback. Added ERT for canceled view close and all-tab frame dispatch. This is an incremental lifecycle consolidation, not yet a replacement for every upstream tab-bar entry point. Tab-aware navigation and crash-recovery restoration remain next, and macOS GUI acceptance is outstanding. CI for this head is pending.
