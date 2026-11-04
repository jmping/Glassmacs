# Glassmacs Alpha development status

Updated: 2026-11-04. Source of truth: open GitHub issues, pull requests, workflow definitions, and run/job records.

## Recently integrated

PRs #73, #79, #84, and #85 are already merged to `main`. They provide explicit R session routing, native R console controls and Preferences placement, the initial unified buffer-presentation seam, and descriptive R session labels. Continue from those implementations and their remaining acceptance gaps; do not recreate them. PR #84 explicitly left the full packaged GUI matrix and remaining #83 requirements open.

## Integration queue

| PR | Base → head | State | Current validation | Remaining gate |
| --- | --- | --- | --- | --- |
| [#86 Native per-document quit review](https://github.com/jmping/Glassmacs/pull/86) | `main` → `fix/native-quit-review` | Draft; mergeable | ERT, real R/ESS, and macOS launcher passed on head `20675fd` in run [41858828131](https://github.com/jmping/Glassmacs/actions/runs/41858828131). | `macos-gui-acceptance` is queued. Exercise the actual AppKit checkbox and all quit entry points in the packaged app. PR contract says not to merge before this acceptance. |
| [#87 Lifecycle and recovery](https://github.com/jmping/Glassmacs/pull/87) | `fix/native-quit-review` → `feat/alpha4-p0-lifecycle-consolidation` | Draft; mergeable | ERT, real R/ESS, and macOS launcher passed on head `6540bbe` in run [41874524202](https://github.com/jmping/Glassmacs/actions/runs/41874524202). | GUI acceptance queued; dependent on #86. Reconcile base to `main` only after #86 is accepted and merged. |
| [#88 R toolbar polish](https://github.com/jmping/Glassmacs/pull/88) | `feat/alpha4-p0-lifecycle-consolidation` → `feat/alpha5-r-toolbar-polish` | Draft; mergeable | Run [41878335118](https://github.com/jmping/Glassmacs/actions/runs/41878335118) has queued jobs. | Requires toolbar artwork, behavior, accessibility, packaged rendering, and GUI acceptance; depends on #87/#86. |
| [#56 Bundled ESS detection](https://github.com/jmping/Glassmacs/pull/56) | `main` → `fix/bundled-ess-detection` | Open; not yet merged | Two ERT cases cover ESS availability through `load-path`; CI is pending. | This only prevents a false package-install prompt when ESS is present. It does not package ESS and does not complete #44. Reconcile with the full offline bundle planned in #87. |

A green Linux or launcher result is not macOS GUI acceptance. None of these PRs is ready to merge based on the evidence available in this audit. Do not treat queued jobs as passing.

## CI dependency map

The current workflow is `.github/workflows/ci.yml`. A `changes` job compares changed paths with the PR base and emits three gates:

- `lisp/*`, `init.el`, `tests/*`, acceptance scripts/docs, or the workflow run Emacs batch tests.
- R/ESS Lisp, ESS/R tests, bundle scripts, or the workflow run real R/ESS integration.
- `macos/*`, release/bundle scripts, Lisp, init, tests, acceptance scripts, or the workflow run the macOS launcher build and packaged GUI suite.
- Therefore most Lisp or test changes trigger all three suites; documentation-only edits outside the named acceptance paths run none.
- The GUI job depends on the app archive from `macos-launcher`. It uses macOS 15, has a 40-minute timeout, and publishes logs, screenshots, crash reports, and a summary artifact.
- The ERT job installs Emacs on Ubuntu and has a 20-minute timeout. ESS/R integration installs Emacs, R, ESS, AUCTeX, Hunspell, Shiny, R Markdown, and pinned polymode dependencies; timeout is 30 minutes. The packaged launcher job builds and validates the app and archives it; timeout is 30 minutes.

Current run records show completed batch, ESS/R, and launcher jobs for #86/#87, with GUI jobs queued at the time of review. The #88 jobs were queued. The workflow has no explicit concurrency group or dependency cache. Evaluate targeted cache/path improvements after examining real queue and install times; preserve all acceptance gates.

## Active bundles and issue coverage

| Bundle | Issues | Status / dependency |
| --- | --- | --- |
| Native quit safety | #86 | Implemented in draft; packaged native GUI checkbox and quit-path acceptance outstanding. |
| P0 document and console lifecycle | #87; #41, #44, #47, #52, #78; relevant #80 and #34 | Draft is currently an acceptance matrix only. Depends on #86. Offline ESS, scratch protection, console close, R Help/source protection, and Preferences/window behavior require implementation evidence. |
| Toolbar and command discoverability | #88; #45, #57 | Draft contains initial spacing change. Icons, grouping, labels, disabled states, and packaged light/dark/Retina checks remain. |
| Unified window presentation | #43, #74, #81, #82, #83; reconcile #78/#80/#87 | Initial presentation seam and audit are already in merged #84; #73 is also merged. Complete remaining call-site integration and acceptance without rebuilding the seam. Incorporate behavior from merged #79/#85. |
| R/ESS reliability | #3, #12, #16 | Separate from visual work; use deterministic real R/ESS integration and target/output routing checks. |
| Menus and preferences | #42, #48, #80 | Consolidate after window and toolbar commands are clear; preserve save/cancel data safety. |
| Text compatibility and performance | #13, #30 | Split diagnostics from measured performance/backend work if their tests differ. |
| Distribution and release | #34, #38, #39, #44, #66 and all remaining open P0s | Release gate includes supported macOS/Xcode builds, upstream crash fixes, offline dependencies, signing/notarization, and the current acceptance matrix. Manual signing and fresh-machine checks require the maintainer Mac. |

Other open backlog at audit: #3, #12, #13, #16, #30, #34, #38, #39, #41, #42, #43, #44, #45, #46, #47, #48, #52, #57, #66, #74, #78, #80, #81, #82, #83. PR #56 is a partial prerequisite for #44; keep #44 open until offline packaging and clean-home acceptance pass. Refresh issue states before each bundle because requirements overlap and may already be satisfied by merged work.

## Next actions

1. Complete #86's packaged GUI run and inspect its summary/artifact, including actual checkbox initialization, per-document choices, cancel/save failure/veto, and all native Quit entry points. Diagnose queue or workflow defects from job data and logs.
2. Keep #87 and #88 stacked while #86 is unaccepted. Once parent changes merge, retarget dependent PRs in order and verify each diff contains only its intended changes.
3. Reconcile the merged #79/#84/#85 work with #78/#80/#81/#82/#83, and inspect #56 against #44 without treating ESS detection as offline packaging.
4. Audit open issues against merged code and tests; close only issues whose acceptance is evidenced.
5. Continue the P0 lifecycle increment in #87; verify it implements rather than only tracks #41, #44, #47, #52, #78 and #80 before advancing.
6. Do not mark GUI, signing, notarization, fresh-machine, or hardware-dependent gates complete from batch results. Record exact remaining manual acceptance steps.
