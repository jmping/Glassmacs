# Linked presentations — Phase 0 baseline and non-regression contract

Document ID: DOC-LINKED-PHASE0
Status: Baseline recorded; native GUI recheck pending
Last reviewed: 2026-11-06

## Baseline identity and limits

- Installed signed/notarized candidate reported at commit `2885efd`, not the documentation-updated `main` at `a8f3ec1`. The candidate was installed and passed signing, staple, Gatekeeper, dependency and isolated ESS/R checks.
- Reported bundled-Emacs automated baseline for that candidate: 412 expected, 0 unexpected, 18 skipped; Python/Swift passed. This is not a native GUI pass.
- PR #96 (`fix/r-console-window-placement`, reported commit `336498cc8c5b430cc7a1e0d7191bd58bfd2fe5d2`) is open and not merged as of the supplied evidence. Reported full bundled-Emacs suite: 433 tests, 415 passed, 18 skipped, 0 failed; real ESS/R subset 24/24; byte compilation and docs/acceptance checks passed. Its native GUI placement fix has **not** been verified.
- Evidence was reported from `files/gui-acceptance-2885efd/` and `files/gui-r-smoke/results.json`; these files have not been inspected as part of this baseline. Treat the observations below as reported, not independently reproduced.

## Behavior ledger

| Behavior | Observed on installed 2885efd | Required non-regression / next gate |
| --- | --- | --- |
| Separate document frames | PASS (scripted GUI) | Two documents remain distinct; refocus does not duplicate |
| Document tab policy | PASS (scripted GUI) | Tabs retain distinct document views |
| Source chooses R target | PASS (scripted GUI) | Selection routes to intended session |
| Two R processes registered | PASS (scripted GUI) | Both remain live and independently addressable |
| R console separate-frame placement | **FAIL** (scripted GUI) | Two consoles in independent frames; source unchanged |
| Console A remains visible after B | **FAIL** (scripted GUI) | B must not displace A |
| New console vs existing-buffer selection | **REPORTED ISSUE; command identity unclear** | Identify exact menu/toolbar command; new session and new view are distinct |
| Two R help buffers | PASS (scripted GUI) | Separate coexisting frames; no source replacement |
| R function index ignores comments | PASS (scripted GUI) | Commented-out functions remain excluded |
| Crash recovery documents | PASS (scripted GUI) | Each saved document restored once; no unintended console startup |
| Crash recovery consoles | NOT TESTED | Do not infer process restoration |
| Source toolbar visible | PASS (presence only) | Actual click actions not tested |
| Quartz device active | PASS (device only) | Plot rendering, focus, placement not tested |
| Native contextual menu | NOT TESTED | Inspect visually |
| Native close / Cmd-W / Cmd-Q | NOT REVERIFIED HERE | Test modified document cancellation and console hide behavior |
| Finder / Open With | NOT REVERIFIED HERE | Verify Cocoa event routing |

## Phase 0 freeze rules

- No source-code or startup behavior changes in the Phase 0 PR.
- No broad advice on Emacs display/close primitives; no new window registry.
- No merging PR #96 on the strength of ERT alone; actual GUI acceptance remains its separate gate.
- Keep the signed candidate as an identifiable baseline; test future changes in a separately identified build/profile.
- Do not modify the project-aware execution feature worktree.
- Any future behavior change must carry an explicit before/after row, relevant automated tests, and GUI steps where applicable.

## Reproducible native acceptance sequence

Record: app bundle path, commit SHA, macOS version, Emacs version, profile/preferences, test method (scripted vs visual), screenshot/log locations, and PASS/FAIL/UNVERIFIED for each step.

1. In a clean or isolated profile, select separate native windows. Open two distinct modified R documents; verify frames and unsaved content.
2. From a source document, start R session A, then independently start R session B. Record process IDs, process buffers, session IDs, frame IDs, and selected windows. Confirm neither console occupies an unintended source split and neither view is displaced.
3. Invoke **New R Console**, **Show R Console**, and **Switch R Console** separately; record the exact menu/toolbar/keyboard command and check whether process count changes. If a control is labeled only “New Buffer,” establish whether it is document creation rather than console creation before changing behavior.
4. Route distinct commands from source to A and B; confirm outputs and histories.
5. Re-select each console; ensure existing presentations are reused without duplicate frames. Explicitly create a second view and verify the underlying process remains the same.
6. Repeat the relevant document and console scenarios under tabs, then explicit split placement.
7. Open two distinct R help topics; verify coexistence and source preservation.
8. Exercise modified-document Cmd-W/Cmd-Q cancel paths, console-window close without process termination, recovery without duplicate documents, and preferences opening.
9. Visually inspect plot rendering/placement/focus, toolbar clicks, and contextual menu. Do not count device creation or toolbar presence as interaction success.

## Phase 0 exit criteria

- This baseline and architectural contract are reviewed.
- Existing test commands and coverage are inventoried in Phase 1.
- No runtime changes occur as part of Phase 0.
- Outstanding GUI failures remain explicit, not silently promoted to PASS.
- PR #96 is assessed and verified independently before relying on its fix as a baseline.
