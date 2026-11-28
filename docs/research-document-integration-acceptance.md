# Integrated research-document acceptance

> **Document ID:** DOC-RESEARCH-ACCEPT  
> **Status:** Informational acceptance protocol (draft PR #123)  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-11-24  
> **Last reviewed:** 2026-11-24  
> **Coverage:** Real research-document CI and packaged macOS/SSH acceptance procedures  
> **Supersedes:** None

> **Scope:** The opt-in research-document campaign in draft PR #112, coordinated with [issue #122](https://github.com/jmping/Glassmacs/issues/122).  
> **Evidence rule:** Linux ERT, macOS packaged-app static validation, and physical macOS GUI observations are **different gates**. Passing one never certifies another.  
> **Status:** Native GUI and trusted-SSH acceptance remain **NOT RUN** until evidenced for the exact candidate.

## Candidate identification

Record before testing: Glassmacs source commit SHA; build/installer SHA-256; app location; date; macOS release; Intel/Apple Silicon architecture; Emacs, R, ESS, Quarto, Pandoc, knitr, rmarkdown and Shiny versions; whether Skim or Preview is installed; test operator; profile directory; screen configuration. Do not reuse evidence from an earlier candidate.

## Automated local functional gate

Run `./scripts/test` on the PR head. The file `tests/test-glassmacs-document-acceptance.el` adds:

- **Real integration:** Two simultaneous opt-in `.Rmd` builds in distinct directories but with the same source basename. The test verifies separate processes, separate log buffers, terminal success, source-correct HTML outputs, private remembered-output lookup, explicit reopening and no automatic output opening. It requires Rscript, `rmarkdown` and Pandoc, and **skips** explicitly when unavailable. The Linux `ess-r-integration` job installs all three.
- **Lifecycle isolation:** Two real local shell processes, one cancelled while the other completes, retain independent job states/logs and do not modify the legacy global process reference. The cancelled job cannot be restarted.

The standard GitHub CI must be green for **changes**, **emacs-batch**, **ess-r-integration**, and **macos-launcher** on the exact candidate SHA. Observe test skips in the job logs; a green workflow with a skipped dependency-driven test is not proof that the tool was exercised. **CI's macOS job is a bundle/static check, not a Cocoa GUI session.**

The existing renderer remains the default; enable `glassmacs-document-use-job-adapter` only during experimental tests. Never launch remote execution through this local adapter.

## Packaged macOS execution protocol (human witness required)

First run the existing GUI smoke scenarios against the exact candidate application:

```sh
./scripts/macos-gui-acceptance /Applications/Glassmacs.app build/phase2-gui \
  --only finder-repeat-and-mixed-documents \
  --only research-document-concurrent-real-render
```

The first scenario checks the bundle's Finder document menus, shortcuts and duplicate-open behavior. The second runs **two real concurrent R Markdown HTML builds** inside the packaged Cocoa application, with source-correct job/log/output/history assertions; it reports **NOT RUN** rather than PASS if Rscript, rmarkdown or Pandoc is unavailable in the app's actual environment. It deliberately disables automatic browser opening, so native focus, PDF/HTML viewer presentation, Quarto, cancellation, Shiny and long-run restoration still require the manual steps below. Preserve `build/phase2-gui/results.json`, the summary and any diagnostic screenshots. Then perform the following on the packaged app itself; use an isolated macOS account/profile and real local R/ESS/document dependencies.

1. **Baseline behavior:** With `glassmacs-document-use-job-adapter` disabled, render a saved `.Rmd` using the Document menu. Confirm the legacy process buffer, browser output, original document window and ESS console still work. Never mark this passed from batch CI alone.
2. **Opt-in parallelism:** Enable `glassmacs-document-use-job-adapter` (for example through `M-: (setq glassmacs-document-use-job-adapter t)`). Open two different saved `.Rmd` files, each containing an R chunk with `Sys.sleep(10)`, and start both builds before either finishes. Confirm both jobs are independently running; inspect **Document → Show Build Status** and **Show Last Build Log** from each source. Verify unique log/job identities and source-correct HTML outputs. Check window focus and browser behavior.
3. **Quarto:** If the CLI is installed, build a local `.qmd` alongside an `.Rmd` and verify the renderer is `quarto`, the reported output is correct, and source/output associations are not crossed. If Quarto is unavailable, mark **NOT RUN** with the missing dependency; never treat an R Markdown test as Quarto acceptance.
4. **Cancellation/failure:** Cancel one of two running local builds from its source. Confirm its state remains cancelled, the other build finishes, no cancelled job silently restarts, and an unrelated ESS session remains responsive. Render a deliberately invalid document and verify its failure log and status. Repeat with a missing executable in an isolated test profile, then restore the executable path.
5. **Output persistence:** With `glassmacs-document-remember-build-outputs` enabled, successfully build a document, close/reopen its source, then use **Document → Open Remembered Build Output**. Repeat after restarting the app. Confirm no renderer, browser viewer or SSH connection is automatically started during restoration; missing/moved output must be reported rather than fabricated. A renamed source must not claim the old source's job.
6. **Polymode and ESS:** From prose and R chunk sub-buffers, verify document menus/status resolve to the base source. Select two different ESS R targets and confirm chunks route to the selected console while document renders remain independent. Check R Help, source window focus and native close safeguards.
7. **Sweave/PDF:** Run a saved `.Rnw` document through the opt-in Sweave PDF path, inspect its distinct job/log/output, and confirm PDF presentation in Skim or Preview. Record existing SyncTeX generated-TeX limitations; do not claim full inverse mapping to the original Sweave chunks.
8. **Shiny:** Start, preview, reload, stop, and restart a local `app.R`. Confirm the preview only opens after a `127.0.0.1` listening address is reported and the job-status record does not replace Shiny's single-app process owner. Do not open a public interface or set up remote tunnels.
9. **Close/reopen:** Close source and output windows while another job is running; use Command-W and the red close button and verify expected unsaved-change prompts. Quit/relaunch with remembered output enabled. No R session or unfinished render must be replayed automatically.
10. **Environment coverage:** Repeat feasible scenarios on an Intel Mac and a clean Apple Silicon account. Record every omitted architecture, macOS version or viewer as **NOT RUN**, not success.

## Remote acceptance — separate gate

Draft PR #102 must be tested with a **trusted explicitly configured SSH alias**, real ESS host selection, disconnect during in-flight work (classify as uncertain, never replay), restoration of an explicitly chosen session, durable Rscript log/status/cancel, and bounded artifact retrieval. Test path/host mismatches and symlink/traversal and overwrite refusals. No production credentials in CI, no implicit local-to-remote path mapping, and no remote Shiny tunnel. Confirm that a local document render never changes remote execution provenance.

## Evidence record format

Append one row per **scenario and exact candidate**, or attach a dated results JSON/Markdown file to issue #122:

| Field | Example format |
| --- | --- |
| Candidate | Full git SHA; binary SHA-256, if packaged |
| Environment | macOS version, architecture, R/Quarto, profile |
| Scenario | e.g. `parallel-real-rmarkdown` |
| Outcome | `PASS`, `FAIL`, or `NOT RUN` |
| Evidence | CI job URL, GUI harness results, logs/screenshots |
| Observation | Expected versus observed and any workaround |
| Defect link | GitHub issue/PR if reproducible |

Do not edit `docs/acceptance-matrix.md` or `docs/macos-acceptance-checklist.md` directly; both are generated from `acceptance/matrix.toml`. Once scenario evidence exists, update the matrix source and regenerate with `./scripts/acceptance-matrix render`, preserving the distinction between automated and manually witnessed results.

## Release and merge decision

PR #112 remains draft until the real packaged-macOS document workflow passes and any regressions are triaged. PR #102 has its own trusted-host gates. PR #106 also has outstanding corresponding-source/license verification; a signed/notarized DMG cannot be published solely because its packaging CI passed. **Never auto-merge either campaign to `main` or publish a DMG on the basis of the tests introduced here.**
