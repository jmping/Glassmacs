# PR #98 candidate validation — blockers and remediation ledger

> **Document ID:** DOC-LINKED-CANDIDATE-TRIAGE  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-08  
> **Coverage:** Local candidate at 6add723, failed ERT assertions, GUI evidence, follow-up gates  
> **Supersedes:** None

## Candidate 7cc8898 — local verification (2026-11-08)

**Acceptance decision: BLOCKED pending hands-on GUI acceptance.** This section records a new candidate; the 6add723 record below remains historical.

- Exact SHA: `7cc8898a9703dcb5dc23a0f072e8aa8c25fb01e1`, clean detached checkout of `integration/linked-window-presentations`.
- Environment: macOS 27.0.1 (26A434), arm64, Xcode 27.2, R 4.6.2, bundled Emacs 31.1 and ESS 26.5.0. Dedicated Glassmacs homes and XDG data/cache were used; runtime native compilation remained disabled by existing app policy. The installed app was not replaced.
- Built with `scripts/build-macos-app`, validated with `scripts/validate-macos-app`, and archived using `ditto`. The ad-hoc-signed development ZIP is **not notarized**. ZIP SHA-256: `b49db35c45256214f43d3b63fcf1483587066a69e9ba7dc66b784c6bf549442a`.
- Local bundled-Emacs ERT: **473 run, 455 expected, 0 unexpected, 18 skipped**, exit 0. CI [42555173713](https://github.com/jmping/Glassmacs/actions/runs/42555173713) logs report 0 unexpected in all three ERT jobs: Ubuntu batch 440 expected/33 skipped, ESS/R 472 expected/1 skipped, and macOS launcher 440 expected/33 skipped. The separate Cloudflare website check failed.
- Full packaged GUI harness, with the repository's compiled AX probe configured: **13 PASS, 1 FAIL, 2 NOT RUN**. The raw failure is `dynamic-menu-shortcut-labels`, because System Events could not find the menu bar. Direct Accessibility inspection did enumerate the File menu and observed labels including `New Document` (`s-n`) and `Close Document` (`s-w`); this partial inspection is **not** a full verification of all dynamic labels or profiles, and the raw harness result remains unchanged. NOT RUN: user Emacs-init isolation (existing init files were not replaced), and package-offer decline (ESS is bundled). No new crash reports were reported.
- The native quit-dialog scenario **passed** with the AX probe. Some keyboard scenarios used System Events; native close-button events in the harness were simulated as Cocoa delete-frame events. Driver-mode tests are not physical interaction.
- Additional GUI driver checks opened documents in separate frames and tabs, started distinct R processes in two separate frames with the source intact, selected a source target, displayed two distinct R help topics in separate frames, and found that a sample imenu index excluded a commented-out function. An R Quartz device was reported; visible rendering, focus and placement were not verified.
- The requested interrupt/resume sequence was exercised through the GUI **driver**, not actual menu clicks: `Sys.sleep(30)` ran, the old command was queued, interrupt held it, a new command ran before it, and the message reported `1 command(s) ... held`; resume then ran the old command. Physical R menu dispatch, actual typing and visual echo remain unverified.

### Hands-on matrix status

The following are **manual acceptance statuses**, not claims based on the automated results above. No GUI-01–GUI-22 row was completed by real end-to-end manual interaction in this run.

| Rows | Manual status | Partial automated evidence / outstanding work |
| --- | --- | --- |
| GUI-01–03 | UNVERIFIED | Launch, distinct document views and frame/tab policy exercised by harness/driver; inactive-tab chooser and full gestures remain. |
| GUI-04 | UNVERIFIED | New view, move, split and undo require manual exercise. |
| GUI-05–07 | UNVERIFIED | Two independent R processes and one explicit target verified via driver; toolbar clicks, two document links and cross-session execution remain. |
| GUI-08–10 | UNVERIFIED | Prompt/cancel, stale target and actual mixed-document chunk workflow remain. |
| GUI-11 | UNVERIFIED | Driver saw two distinct help buffers in separate frames; actual user interactions and visual presentation remain. |
| GUI-12–13 | UNVERIFIED | Help side placement and Preferences presentation need manual exercise. |
| GUI-14–16 | UNVERIFIED | Harness exercised Command-W and native quit prompt, but not the complete dirty-tab, red-button and close-versus-quit matrix. |
| GUI-17 | UNVERIFIED | Harness simulated close and used a Dock click; physical red-button close and full manual outcome remain. |
| GUI-18–20 | UNVERIFIED | Limited crash recovery passed; shared-document close, selected tab, dirty recovery content and malformed input remain. |
| GUI-21 | UNVERIFIED | Direct AX saw some File menu labels; physical toolbar and mode-line clicks and full menu inspection remain. |
| GUI-22 | UNVERIFIED | Driver's sample imenu omitted a commented function; actual contextual object-menu presentation remains. |

Neither the two interrupt menu interactions nor the mode-line document-name click was performed physically. They must not be considered manual passes. Preserve logs and `gui-acceptance/results.json` for the tested SHA; no source fix or merge is implied by these results.

## Historical candidate 6add723 — acceptance decision: BLOCKED

This record transcribes the local Mac findings from [PR #98 comment 6728988129](https://github.com/jmping/Glassmacs/pull/98#issuecomment-6728988129) into a versioned repository artifact. The detailed original evidence remains on the operator's Mac at `/tmp/glassmacs-pr98-6add723/build/candidate-pr98/evidence/` (`issues.md`, `manual-matrix.md`, logs and screenshots). **Those local files were not uploaded to GitHub by this commit**; the PR comment is the authoritative full reproduction report until the evidence bundle is attached.

### Candidate identity

- Branch: `integration/linked-window-presentations`, PR #98.
- Tested commit: `6add72319794d5e8ed008d6a6a66adeb7b632f89`.
- App: `/Users/jpasek/.copilot/session-state/93d78100-9186-45d0-ada8-6f700924f616/files/pr98-relocated/Glassmacs.app`.
- Archive: `/tmp/glassmacs-pr98-6add723/build/candidate-pr98/Glassmacs-PR98-candidate.zip`.
- ZIP SHA-256: `9b2b6feed5e544dd115f543cea6245d08a5a28bce6f6aeaec4674c0ae393e5b8`.
- Build validated and ad-hoc signed, **not notarized**. Installed app not replaced.
- Environment: macOS 27.0.1 arm64, Xcode 27.2, R 4.6.2, bundled Emacs 31.1, ESS 26.5.0.

### Critical blocker: ERT failures masked by exit status

Local `scripts/test`: **470 tests; 436 expected, 16 unexpected, 18 skipped; exit 0**. CI run [42525407252](https://github.com/jmping/Glassmacs/actions/runs/42525407252) also reported **16 unexpected** in *both* apparently green ERT jobs: Ubuntu batch 421 expected / 16 unexpected / 33 skipped; ESS/R 453 expected / 16 unexpected / 1 skipped. **Do not use green job status as evidence of passing assertions for this SHA.**

Minimal reproduction:

```sh
EMACS=/path/to/Glassmacs.app/Contents/MacOS/Emacs
"$EMACS" -Q --batch -l init.el --eval '(progn (require (quote ert)) (ert-deftest gm-proof-failure () (should nil)) (ert-run-tests-batch-and-exit (quote gm-proof-failure)))'
echo "exit=$?"
```

Observed with Glassmacs init: failing assertion but exit 0; without init: exit 1. Root cause: `glassmacs-recovery--reviewed-quit-advice` intercepted batch `kill-emacs` and discarded the requested exit code.

**Remediation pushed after candidate:** `lisp/glassmacs-recovery.el` now bypasses the interactive quit coordinator in `noninteractive` mode, forwarding original arguments; `scripts/test` now contains an intentionally failing isolated ERT exit-status probe, which rejects status 0. The exact new HEAD requires CI to establish that the fix works. Do not infer the remaining 16 failures are fixed by this change.

### Sixteen failed ERT tests on candidate SHA

```text
glassmacs-close-last-window-closes-frame-or-tab
glassmacs-close-scratch-modified-prompts-and-cancel-keeps-it
glassmacs-focus-open-document-delegates-to-focus-intent
glassmacs-focus-open-document-rejects-utility-buffers
glassmacs-macos-cocoa-close-of-final-frame-does-not-quit
glassmacs-macos-cocoa-close-of-nonfinal-frame-uses-original
glassmacs-macos-cocoa-close-with-only-hidden-others-hides
glassmacs-macos-reopen-after-cocoa-close-shows-hidden-frame
glassmacs-native-frame-close-reviews-hidden-tabs
glassmacs-present-buffer-obeys-unsuitable-existing-view
glassmacs-r-help-display-checks-view-suitability
glassmacs-r-selecting-console-reuses-existing-window
glassmacs-reviewed-tab-close-menu-command
glassmacs-visible-new-document-still-honors-new-frame-policy
glassmacs-windowless-new-document-reuses-hidden-frame-per-policy
glassmacs-windowless-open-file-shows-in-hidden-frame
```

**Confirmed separate source defect:** `glassmacs-focus-open-document` was defined twice in `lisp/glassmacs-frames.el`; the later zero-argument definition replaced the earlier `(buffer)` command and caused the two focus tests to fail with `wrong-number-of-arguments`. **Remediation pushed after candidate:** removed the shadowing duplicate. The other 14 failures were triaged individually below. They are not automatically classified as application defects; some may be test isolation or expectations.

### ERT triage after the exit-status fix (2026-11-08)

With the exit-status fix in place, `scripts/test` on bundled Emacs 31.1 exited **1** with 16 unexpected results: 14 of the original list plus `glassmacs-alpha3-document-chooser-focuses-existing` and `glassmacs-native-quit-command-routes-through-review`, which the two remediation commits above had newly exposed. Each was diagnosed individually:

| Cause | Tests | Classification and fix |
| --- | --- | --- |
| Removing the duplicate also removed the no-argument form of `glassmacs-focus-open-document`, which the mode-line document click still called | `alpha3-document-chooser-focuses-existing` | **Product defect** (`wrong-number-of-arguments` on a mode-line click). The buffer argument is now optional and the command prompts with path-labeled choices. |
| `glassmacs-presentation-find-suitable-view` asked the suitability predicate about every window, not only views of the buffer | `present-buffer-obeys-unsuitable-existing-view` | **Product defect** (no behavior change, since the predicate re-checks the buffer, but the contract was violated). Fixed: only views of the buffer are offered to the predicate. |
| Symbol stand-in frames (`a`, `hid`, `vis`) reach new `window-list` enumeration | 4 Cocoa close/reopen tests and 3 windowless/new-document tests | **Stale mocks.** The mock frames now get an empty window list. |
| Tabs mocked as symbols, or `tab-bar-tabs-function` rebound as a function rather than the variable the code calls | `close-last-window-closes-frame-or-tab`, `native-frame-close-reviews-hidden-tabs` | **Stale mocks.** Tabs are now alists, and the test binds the variable. |
| `lookup-key` strips the `menu-item` wrapper | `reviewed-tab-close-menu-command` | **Test defect.** The test now reads the raw keymap entry. |
| The batch quit bypass applies under ERT | `native-quit-command-routes-through-review` | **Expected.** The test now binds `noninteractive` to nil, and a new test asserts that batch `kill-emacs` forwards its exit status. |
| `*scratch*` was shown in both windows, so the close was correctly a view-only close | `close-scratch-modified-prompts-and-cancel-keeps-it` | **Test setup.** The other window now shows a different buffer. |
| Help reuse is deliberately side-only under side policies (f1cf970) | `r-help-display-checks-view-suitability` | **Stale expectation.** Reuse is now tested against a real right side window, with an added negative case. |
| Console display now uses the presentation lookup, not `get-buffer-window` | `r-selecting-console-reuses-existing-window` | **Stale mock.** The test now stubs the presentation lookup. |

Result: **473 tests, 455 expected, 0 unexpected, 18 skipped, exit 0** with bundled ESS 26.5.0 and real R 4.6.2. The 18 skips need AUCTeX, polymode, hunspell, rmarkdown or shiny, which the Ubuntu `ess-r-integration` job installs. Byte compilation, `check-docs`, `acceptance-matrix check`, the release-script unit tests and the TTY GUI-harness self-test pass locally. Native GUI acceptance (P1 items below) is still **not done**.

**Related queue fix:** an interrupt used to pause the whole session queue, so later submissions were neither dispatched nor echoed until a Resume that no menu offered. Now only the commands queued *before* the interrupt are held, new submissions run and echo, submitting to a paused or held queue reports why, and **R > Resume Queue** has been added.

### Packaged GUI and scripted driver results

- Full harness: **12 PASS, 2 FAIL, 2 NOT RUN** at initial run.
- Native quit dialog initially failed because `GLASSMACS_AX_PROBE` was unset; **passed on retry** with the compiled repository Accessibility probe.
- `dynamic-menu-shortcut-labels` failed because System Events could not find the `Emacs-arm64-11` menu bar. Direct AX data existed; **native menu enumeration is UNVERIFIED**, not an established product defect.
- Two NOT RUN: user Emacs-init isolation (existing init files intentionally not replaced) and package-offer decline (ESS bundled).
- Harness startup encountered a Documents permission prompt. Later process detection failed because `/tmp` and `/private/tmp` executable paths differed; relocating outside `/tmp` made the scenario pass. No security permissions were changed.
- Additional **scripted driver checks**, not manual GUI acceptance: two independently started R processes (`R-1`, `R-2`) in separate frames with source intact; source targeting; two simultaneous help-topic frames; document frame/tab policies; R-reported Quartz device; sample imenu excluded a commented-out function. They do not prove actual toolbar clicks, visual plot rendering, focus, menu behavior, or full manual scenarios.
- Crash-recovery harness passed its limited assertions: saved files restored once, recovery offered, no automatic console start. It did **not** establish selected-tab restoration or the complete GUI-19/20 cases.
- The complete GUI-01–GUI-22 hands-on matrix is **UNVERIFIED**. Some close-button tests simulate Cocoa delete-frame events, and some keyboard checks use real System Events; keep these methods distinct.

### Priority and next gates

1. **P0:** Verify failing ERT exits nonzero with `-l init.el` in both local bundled Emacs and Linux CI. This was a false-green CI integrity defect; never waive it.
2. **P0:** Re-run full batch and real ESS/R suites on the patched SHA, inspect **individual failure logs** and repair the remaining failures with focused tests. No merge with unexpected ERT failures.
3. **P1:** Rebuild exact HEAD in isolated home/native cache; rerun the packaged GUI harness with `GLASSMACS_AX_PROBE` configured, outside `/tmp` path aliases.
4. **P1:** Resolve menu enumeration via direct Accessibility inspection or manual observation; verify native labels, bindings and menu actions rather than equating System Events lookup failure with application failure.
5. **P1:** Complete the 22-row native hands-on matrix, particularly modified-document close/cancel, red close vs Cmd-W vs Cmd-Q, selected-tab crash restoration, help coexistence, real R process identity and toolbar clicks.
6. Preserve disposable test files and isolated Glassmacs home; do not overwrite the installed app. Record exact build SHA, logs, statuses and archive hash. No PR merge or release-ready claim until blockers are resolved.

See [implementation record](linked-presentation-implementation-record.md), [candidate handoff](copilot-candidate-handoff.md) and [execution plan](linked-presentation-execution-plan.md).
