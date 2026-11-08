# Copilot handoff — build and validate the linked-presentation candidate

> **Document ID:** DOC-LINKED-CANDIDATE-HANDOFF  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Last reviewed:** 2026-11-08  
> **Coverage:** Local Mac candidate build, GUI acceptance, evidence and handback for PR #98  
> **Supersedes:** None

## Assignment to Copilot (local Mac)

**Your job is to produce and exercise an exact-SHA, locally runnable Glassmacs candidate from PR #98.** You have the Mac GUI, build environment and local terminal. Perform build, packaging, local automated GUI acceptance and hands-on macOS tests; collect reproducible evidence. **Do not implement architecture or make speculative source changes.** Report code defects and exact reproduction steps to the assistant/maintainer for GitHub-side fixes. Do not merge, push unrelated branches, sign/notarize as a public release, or overwrite an existing installed Glassmacs application without explicit permission.

Read [implementation record](linked-presentation-implementation-record.md), [execution plan](linked-presentation-execution-plan.md), [macOS launcher guide](macos-launcher.md), and [macOS acceptance checklist](macos-acceptance-checklist.md). Follow the project’s existing test harness rather than creating a competing one. This is a **development candidate**, not a release-certified binary.

## 0. Establish identity and protect the machine

1. In the existing `jmping/Glassmacs` checkout, verify a clean worktree. If dirty, **stop and report** rather than resetting, cleaning or overwriting changes. Preserve other worktrees and especially `feat/project-aware-execution`.
2. Fetch and check out `integration/linked-window-presentations`. Record `git rev-parse HEAD`, `git status --short`, `git branch --show-current`, `sw_vers`, `uname -m`, `xcodebuild -version`, `R --version` (if available), and the bundled Emacs version once built. Do not use a stale local branch. Recheck remote HEAD immediately before building.
3. Keep the candidate separate from any installed app. Use a dedicated local output directory (for example `build/candidate-pr98/Glassmacs.app`) and a unique `GLASSMACS_HOME` for test sessions. Back up any test documents before destructive close/crash cases; never use real unsaved user documents.
4. Native-compilation artifacts can be tied to signing identity or bundle path. Use a **fresh, isolated native compilation/cache environment** for this candidate. Do not copy native-compilation objects from another Team ID, installation or build; document any `libgccjit`/dylib/signing failure rather than disabling protections silently.
5. Record the GitHub CI run and SHA. The known green **runtime** checkpoint was `518d135b7f082598cdda23728b8593d3666055e5`, run [42499095457](https://github.com/jmping/Glassmacs/actions/runs/42499095457), four jobs passed. The current branch may have later documentation commits: **the tested candidate SHA must be the actual HEAD, not the historical checkpoint**.

Suggested inspection commands (adjust output paths for the machine):

```sh
git fetch origin
git switch integration/linked-window-presentations
git pull --ff-only origin integration/linked-window-presentations
git status --short
git rev-parse HEAD
sw_vers
uname -m
xcodebuild -version
command -v R && R --version | head -n 2
```

If switching or pulling would overwrite local work, stop and ask; do not `git reset --hard` or `git clean -fd`.

## 1. Produce the candidate bundle

From the verified checkout, follow `docs/macos-launcher.md` prerequisites and run:

```sh
mkdir -p build/candidate-pr98
./scripts/build-macos-app build/candidate-pr98/Glassmacs.app
./scripts/validate-macos-app build/candidate-pr98/Glassmacs.app
GLASSMACS_EMACS="$PWD/build/candidate-pr98/Glassmacs.app/Contents/MacOS/Emacs" \
  GLASSMACS_HOME="$PWD/build/candidate-pr98/test-home-batch" ./scripts/test
```

Use the actual build script options as documented by `--help` or source; do not assume a signing option exists. The default development build is **unsigned**; do not infer notarization, public redistribution, or Gatekeeper acceptance from local validation. Verify the app is a self-contained bundle, has the expected bootstrap, icon and lifecycle module, opens via LaunchServices, and can be relocated without missing dependencies. If a test requires permission for Accessibility, Automation or Finder, record the prompt and whether permission was granted; do not bypass security settings without approval.

**Candidate deliverable:** a local `Glassmacs.app` and a zip produced with:

```sh
ditto -c -k --sequesterRsrc --keepParent \
  build/candidate-pr98/Glassmacs.app \
  build/candidate-pr98/Glassmacs-PR98-candidate.zip
shasum -a 256 build/candidate-pr98/Glassmacs-PR98-candidate.zip
```

Record exact paths, SHA-256, branch HEAD, architecture, macOS version, Emacs version, build output and validation logs. Do **not** replace `/Applications/Glassmacs.app` or modify the user's ordinary Emacs/Aquamacs settings.

## 2. Run automated packaged-GUI acceptance

Use the existing Layer C harness:

```sh
./scripts/macos-gui-acceptance build/candidate-pr98/Glassmacs.app \
  build/candidate-pr98/gui-acceptance
```

Read `./scripts/macos-gui-acceptance --help` and `--list` if you need to select or rerun a failing scenario. Preserve `results.json`, `summary.md`, driver logs, `*Messages*`, `*Warnings*`, screenshots, crash reports and per-scenario diagnostics. The harness drives LaunchServices with an isolated home, checks live Emacs state, and can simulate SIGKILL. It does **not** prove real keyboard input unless Accessibility/System Events was used; the red close event may be simulated rather than a physical click. Label these differences explicitly. Run the separate [manual acceptance checklist](macos-acceptance-checklist.md) for Cocoa-native visual behavior.

If the GUI harness fails, do not edit the test or suppress the failure merely to obtain a green report. Record the exact scenario, expected/actual behavior, log, screenshot and reproduction. If it cannot run (permissions, missing R, display environment), report **UNVERIFIED** or **SKIP** with reason, not PASS.

## 3. Manual native GUI matrix — execute every row

Use at least two scratch `.R` files and one `.Rmd` or `.qmd` fixture with distinctive names. Make a dirty unsaved document and a clean document. For crash testing use only disposable fixtures and the isolated Glassmacs home. Record the exact menu action, keyboard shortcut or mouse gesture, expected and actual frame/tab/buffer/session state, and screenshot or short video. Record the underlying R process IDs when testing independence.

| ID | Procedure | Expected result |
| --- | --- | --- |
| GUI-01 | Launch candidate through Finder/`open -a`; open two source documents | App, Dock icon, menus and distinct document views are correct for configured document policy; no surprise buffer replacement |
| GUI-02 | Change document opening policy to native separate windows, then open a third document | Third document opens in a separate native frame; existing document views remain intact |
| GUI-03 | Change policy to tabs and create/open a document; use Window → Show Open Document… | Existing document in inactive tab is focused; no duplicate buffer, no unrelated document replacement |
| GUI-04 | Exercise New Window, New Document, New View, move/split/tab and undo where available | Operations have distinct semantics; new view does not start R or destroy original; move preserves content |
| GUI-05 | In one R source document click **New R Console** twice | Two independent live ESS/R processes, two session identities and accessible console views; no silent reuse |
| GUI-06 | In source A choose **Link Console…** and link to R1; link source B to R2 | No process created by linking; links are document-scoped and remain distinct; Show Console does not start R |
| GUI-07 | Execute source A and B and query R process IDs or distinct variable values | Each sends to its explicitly linked process, even when a different console has focus |
| GUI-08 | Create a fresh unlinked source with exactly one live console; execute; cancel first, then select | Selection prompt appears even with one console; cancel sends nothing; accepted selection persists |
| GUI-09 | Execute with no live R sessions; then with a deliberately stale link | Clear error/explicit reselection, never silent startup or fallback; no source sent on cancel |
| GUI-10 | Execute an R chunk from R Markdown/Quarto/Sweave source (if installed) | Indirect/polymode chunk uses document's explicit session link; no accidental independent link |
| GUI-11 | Configure R Help → separate window; request two distinct help topics | Help appears in native separate window(s) per policy; source remains visible; existing suitable help is reused only as intended; inspect whether different topics coexist |
| GUI-12 | Configure Help → bottom/right side and repeat | Help uses configured side, does not reuse a window on the wrong side or replace source unexpectedly |
| GUI-13 | Open Preferences/Customize, then return to source; repeat | Preferences presentation respects its policy and does not replace an unrelated document |
| GUI-14 | Put the same modified document in two tabs; close one tab with reviewed command | Remaining view and modified content survive; cancel keeps tab open |
| GUI-15 | Open multiple tabs with dirty documents and active R console; click **red close button** on native frame | All affected tabs reviewed; cancel vetoes close; saves/discards respected; R process remains alive if merely hidden |
| GUI-16 | Repeat with Cmd-W, **Close Current Tab Safely**, and Cmd-Q separately | Distinct close/quit semantics and prompts; no accidental process termination from view close; native close button is not assumed identical to Cmd-W |
| GUI-17 | Close last visible window; activate app via Dock/reopen | App process survives as designed; hidden final frame can be shown/recreated without unexpected new document |
| GUI-18 | With two frames and inactive tabs, close one frame containing a document also shown elsewhere | Shared document remains live and accessible in surviving frame/tab |
| GUI-19 | Create multiple document tabs, select a non-first tab, move cursor/scroll, create dirty snapshot, SIGKILL disposable app, restore | Restored document tabs and selected tab are correct; clean files not overwritten; dirty contents recovered separately; no R process auto-restarted |
| GUI-20 | Restore same manifest again; test missing file and malformed fixture where safe | No duplicate recovered documents, no code execution or unsafe data evaluation, graceful missing-file handling |
| GUI-21 | Inspect source/console toolbar, File/Window/R menus, shortcut labels and mode-line document chooser | New/Link/Show labels and targets are unambiguous; native Window navigation discoverable; utility buffers not presented as ordinary documents |
| GUI-22 | Check R object menu with commented-out R objects (known independent UX issue) | Report whether commented-out objects are still indexed; **do not silently claim this issue was fixed by PR #98** |

For GUI-11, distinguish **two topics coexist** from **a second request replaces the first**. The presentation refactor primarily changes suitability/reuse; separate persistent help-topic buffers may require additional work. A visual pass of one help topic does not establish this feature.

## 4. Failure protocol and handback

For each scenario report `PASS`, `FAIL`, `SKIP`, or `UNVERIFIED`—never use PASS based only on CI or source inspection. Provide: exact SHA, macOS/CPU/R/Emacs versions, settings, actions, expected/actual behavior, R process IDs when relevant, screenshot/video filename, console output, logs and whether the event was genuinely Cocoa GUI input or driver-simulated. When a scenario fails, minimize the reproduction, identify the likely source seam if possible, and hand it back for a GitHub code fix. Do not alter source files, commit, merge or force-push.

Save a single handback folder such as `build/candidate-pr98/evidence/` containing:

- `candidate-manifest.md`: git SHA, dirty/clean status, build commands, versions, zip path and SHA-256, codesign/notarization state.
- `build.log`, `validate.log`, `batch-tests.log` and GUI harness `results.json`/`summary.md`.
- `manual-matrix.md`: all GUI-01 through GUI-22 with outcomes and evidence pointers.
- `issues.md`: reproducible failures ordered by severity, plus explicit skips and environmental blockers.
- Screenshots/videos and any relevant app crash reports, with private document paths and credentials redacted.

**Completion criteria:** build/validation succeed; every required scenario is PASS or has an explicitly accepted waiver; no unresolved critical data-loss, unexpected R process termination, wrong-session execution, native close/reopen or crash-recovery issue; evidence matches the exact SHA. A CI-green bundle alone is **not** completion. Send the handback and wait for the maintainer's go/no-go decision on PR #98.

## Copy/paste task for Copilot

> Produce a local, isolated macOS Glassmacs candidate from `integration/linked-window-presentations` PR #98. Follow `docs/copilot-candidate-handoff.md` exactly, read the implementation record and macOS acceptance checklist, verify a clean checkout and exact HEAD SHA, build and validate `Glassmacs.app`, run bundled Emacs batch tests and the packaged GUI acceptance harness, then manually exercise GUI-01 through GUI-22 including two independent R consoles, document-scoped links, multiple R Help topics, Cmd-W/red close/Cmd-Q, inactive tabs and SIGKILL recovery. Preserve logs, screenshots, scenario status and SHA-256 candidate archive in an evidence folder. Do not modify source, overwrite installed apps, merge, or call a scenario PASS without observing it. Return the candidate path, exact SHA, concise results matrix and reproducible blockers for the maintainer to fix on GitHub.
