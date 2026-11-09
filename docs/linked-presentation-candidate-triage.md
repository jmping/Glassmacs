# PR #98 candidate validation — blockers and remediation ledger

> **Document ID:** DOC-LINKED-CANDIDATE-TRIAGE  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-08  
> **Coverage:** Local candidate at 6add723, failed ERT assertions, GUI evidence, follow-up gates  
> **Supersedes:** None

## Acceptance decision: BLOCKED

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

**Confirmed separate source defect:** `glassmacs-focus-open-document` was defined twice in `lisp/glassmacs-frames.el`; the later zero-argument definition replaced the earlier `(buffer)` command and caused the two focus tests to fail with `wrong-number-of-arguments`. **Remediation pushed after candidate:** removed the shadowing duplicate. The other 14 failures remain **untriaged/unresolved** until fresh logs identify individual causes. They are not automatically classified as application defects; some may be test isolation or expectations.

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
