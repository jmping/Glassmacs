# Glassmacs Alpha development status

Updated: 2026-11-04. Source of truth: merged code, open GitHub issues/PRs, CI workflow and run/job records, plus the Glassmacs Aquamacs comparability audit dated 2026-11-04. This map reconciles recommendations with the current stack; refresh states before closing issues or advancing release gates.

## Integrated baseline

PRs #73, #79, #84 and #85 are merged. They provide explicit R session routing, native R console controls and Preferences placement, the initial shared buffer-presentation seam, and descriptive R session labels. Continue from these implementations and their remaining acceptance gaps. Do not rebuild them. PR #84 explicitly left full packaged-GUI acceptance and remaining #83 call-site requirements open.

The report found no basis for a second buffer-presentation architecture: complete the #83 call-chain work by reconciling #87 changes with the merged seam. Preserve deliberate differences from Aquamacs (separate native frames as the default, and no automatic smart spacing/text transformations). Do not create duplicate tickets for printing/export or other low-confidence gaps before establishing native upstream behavior.

## Integration queue

| PR | Base → head | Current validation | Remaining gate |
| --- | --- | --- | --- |
| [#86 Native per-document quit review](https://github.com/jmping/Glassmacs/pull/86) | `main` → `fix/native-quit-review` | Updated head `b8e15a7` adds System Events automation for the actual AppKit checkbox and multiple-document choices. Run [41881340254](https://github.com/jmping/Glassmacs/actions/runs/41881340254) has passed ERT and real ESS/R; the macOS launcher is queued, so its GUI job has not started. The earlier full pass [41858828131](https://github.com/jmping/Glassmacs/actions/runs/41858828131) is on old head `20675fd`; its scenario injected Cancel and did not exercise the checkbox. | Inspect the packaged GUI result from run 41881340254. Verify actual native unchecked initialization, apply-to-all scope, save/discard/cancel, reset after cancel, save failure/veto, and other Quit entry points. Do not merge until the real checkbox path passes. |
| [#87 P0 lifecycle](https://github.com/jmping/Glassmacs/pull/87) | `fix/native-quit-review` → `feat/alpha4-p0-lifecycle-consolidation` | Draft implementation, stacked on #86. Run [41874524202](https://github.com/jmping/Glassmacs/actions/runs/41874524202) passed ERT, real ESS/R, macOS launcher and packaged GUI scenarios on this head. That suite pass does not cover every issue-specific or physical-Mac acceptance item in #34. | Keep stacked until #86 is accepted; then retarget to `main` and review for clean scope. Continue implementing and accepting #41/#47/#52/#44/#78/#80 lifecycle requirements and #34 release-level gates against merged #84's presentation seam. |
| [#88 R toolbar polish](https://github.com/jmping/Glassmacs/pull/88) | `feat/alpha4-p0-lifecycle-consolidation` → `feat/alpha5-r-toolbar-polish` | Draft, stacked on #87. Run [41878335118](https://github.com/jmping/Glassmacs/actions/runs/41878335118) failed the same toolbar ERT in batch and ESS/R: `plist-put` received `(image :type svg)`. Head `684f0c6` fixes the image-spec property tail and adds a regression assertion; ERT and ESS/R passed in [41882671626](https://github.com/jmping/Glassmacs/actions/runs/41882671626), while its macOS launcher is queued. | After the queued Mac gates, verify assets/license, native light/dark/Retina rendering, tooltips and action dispatch. Integrate after lifecycle ancestors. |
| [#89 Alpha integration status](https://github.com/jmping/Glassmacs/pull/89) | `main` → `docs/alpha-backlog-status` | Documentation-only. Its run [41879543588](https://github.com/jmping/Glassmacs/actions/runs/41879543588) passed the path-classification job; ERT, ESS/R and Mac jobs correctly skipped. | Keep this map current with verified runs and dependency order. |
| [#56 Bundled ESS detection](https://github.com/jmping/Glassmacs/pull/56) | `main` → `fix/bundled-ess-detection` | Separate open PR; two ERT cases cover discovery through `load-path`. | This prevents a false install prompt when ESS is already present. It does not bundle ESS or complete #44. Reconcile with #87’s offline package and clean-home checks. |

A green batch, launcher or old GUI run is not evidence for untested native behavior. CI results must be tied to the exact current head; queued or skipped jobs are not passes. The earlier #86 GUI result is explicitly superseded for checkbox acceptance by the updated scenario.

## CI and native GUI acceptance

The path-filtered workflow is `.github/workflows/ci.yml`. Emacs/Lisp/tests and acceptance harness changes should trigger batch tests; R/ESS changes additionally trigger real R/ESS integration; app/Lisp/tests/harness changes trigger macOS launcher and packaged GUI jobs. Docs-only backlog changes outside acceptance paths need only the path-classification job.

The GUI job downloads the packaged app produced by the macOS launcher job, runs bounded native scenarios, and uploads logs, screenshots, crash reports and a summary. This remains the main integration risk identified by the report. Prioritize a fresh run on #86’s changed head and debug scheduling, accessibility permissions, process identity, dialog discovery, timeouts and uploaded diagnostics from actual run/job evidence. Do not add a second GUI framework before completing the existing #34/#49/#87 path. Keep explicit physical-Mac checks for behavior CI cannot demonstrate: Dock/logout quit routes, Finder/repeated open events, appearance/Retina visuals, Quartz windows, clean-machine launch, and candidate signing/notarization.

Workflow queues/install times may justify targeted caching or path improvements only after measured evidence; preserve all distinct acceptance gates.

## Dependency-aware bundles

| Bundle | Scope and reconciliation | Order and acceptance |
| --- | --- | --- |
| A. Native quit contract | #86; existing #41/#47 and #34 scenario 6. | First in the active lifecycle chain. ERT plus packaged GUI tests must exercise the real AppKit checkbox on every prompt, apply-to-all only within one quit attempt, per-document choices, cancel/save failure/veto and all native Quit entry points. |
| B. P0 document/R lifecycle | #87; #41, #44, #47, #52, #78, #80 and release-level #34. | After A. One coherent integration pass for scratch safety, ESS offline packaging, console close, Help/Preferences/source isolation, Finder/windowless behavior, and workspace recovery. Run ERT, ESS/R only for affected session/process behavior, packaged GUI, and clean-home/offline acceptance. |
| C. Toolbar usability | #88; coordinate #45/#46 and provenance #57/#66. | Keep its current ancestry after B. Check actionable hierarchy, enablement/accessibility, asset licensing, command behavior, and native light/dark/Retina rendering and tooltips. |
| D. Unified window presentation | #83, #74, #81/#82 and related #42/#43; reconcile #78/#80/#87. | Continue the call-chain audit and central seam already begun in #84; do not create another seam or overwrite #87 work. ERT for routing/state and native GUI for frame/tab/split/focus/windowless/recovery behavior. Can audit alongside B; implementation needs surface review. |
| E. Menus and release acceptance | #90 assigned to the **Keyboard and menu discoverability** bundle; #34, #42, #48, #57, #66. | #90 is independent of #86–#88 and must not expand or block that stack. Implement dynamic accelerator labels only for Glassmacs-owned menu entries using effective keymaps; test profile/mode changes, overrides and unbound commands in ERT, then rendered-label refresh in packaged macOS GUI. Run ESS/R only if R/ESS maps change. Reuse #34’s existing GUI gate. Keep release acceptance after the lifecycle baseline. |
| F. R/document reliability and extended workflows | #3, #12, #13, #16 and existing #30 text compatibility. | Preserve merged bounded-output/session-routing work; follow ESS prompt/readiness contracts and distinguish local ESS from remote execution. Use batch/real ESS-R tests; schedule remote-host and performance matrices only for scoped work. |
| G. Distribution and release readiness | #38/#39, #44, #57, #65/#66 and remaining P0 gates. | Resolve upstream Cocoa/toolchain risks, validate offline dependencies and relocatable bundle on clean machines, then candidate signing/notarization/Gatekeeper and license/source review. Manual signing and hardware/OS matrix checks require the maintainer Mac. |

Other open issues are tracked in their existing bundles; create no duplicate issue for audit observations already covered by #34, #42–#48, #52, #57, #66, #74, #78–#83 or #3/#12/#13/#16/#30. Keep #44 open until ESS is packaged and clean-home/offline behavior passes; #56 is only detection.

## Next actions

1. Inspect #86 run 41881340254 after the queued macOS launcher and packaged GUI jobs complete. The old run does not validate the checkbox; troubleshoot the native accessibility scenario from the uploaded logs/artifacts.
2. Follow #88 run 41882671626 through its queued macOS launcher and GUI jobs; ERT and ESS/R are already green on `684f0c6`.
3. Keep #87/#88 stacked until #86 is accepted; then retarget and review each diff in dependency order.
4. Continue #87 implementation against the merged #79/#84/#85 baseline and reconcile remaining #83 placement call sites.
5. Start the independent #90 menu-label implementation in the Keyboard and menu discoverability bundle, reusing #34 acceptance; avoid unrelated menu or upstream behavior changes.
6. Close issues only when their acceptance evidence exists. Never infer native GUI, clean-machine, signing, notarization or hardware acceptance from batch results.
