# Historical Aquamacs issues: Glassmacs regression and compatibility audit

> **Document ID:** DOC-AQUA-ISSUES  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-27  
> **Last reviewed:** 2026-10-27  
> **Coverage:** Source-linked historical issue triage, not a claim of reproduced Glassmacs bugs  
> **Supersedes:** None

This follows the [menu parity audit](aquamacs-menu-parity-audit.md). Sources are **individual issues in the actual upstream [Aquamacs issue tracker](https://github.com/aquamacs-emacs/aquamacs-emacs/issues)**, rather than the historical code mirror. Issue states reflect GitHub on 2026-10-27. An open Aquamacs issue is **not** evidence of a Glassmacs defect; a closed Aquamacs issue is **not** evidence Glassmacs is safe. Each entry needs reproduction on current Glassmacs `main` before filing a product bug.

## Priority register

| Priority | Aquamacs report | Reported behavior and relevance | Glassmacs state / action |
| --- | --- | --- | --- |
| P0 | [#270](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/270) (open) | Finder / `open -a` file opens while application has no frames: file loads but is invisible; Dock reopen creates unrelated blank frame | **Untested.** Test no-frame Finder open and buffer visibility; inspect `glassmacs-reopen` and file-open event routing |
| P0 | [#219](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/219) (open) | File → New Buffer in New Frame fails after last frame closed | **Untested.** Test menu and Dock reopen with zero visible frames |
| P0 | [#255](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/255) (open) | Intermittent native Open/Recent dialog hangs on macOS 15.6; reporter suspected Rosetta | **Untested.** Test repeated Open/Recent on native arm64 and Intel where available; do not attribute cause to Rosetta without evidence |
| P0 | [#241](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/241) (open) | Hangs opening LaTeX documents from external apps on macOS 14 | **Untested.** External Finder/editor open with source and LaTeX files, focus, reentrancy and UI responsiveness |
| P0 | [#247](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/247) (open) | `emacsclient` fails with wrong type argument `windowp` receiving a frame | **Untested.** Test `emacsclient -c` and existing-frame client opens; verify included client matches bundle |
| P1 | [#233](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/233) (open) | Cannot configure left Option as Meta and right Option as ordinary Option | **Partial feature gap.** Hybrid/Traditional profile exists; independent modifier settings and international text input require explicit design |
| P1 | [#263](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/263) (open) | Automatic response to macOS light/dark theme change requested | **Unestablished.** Test appearance changes and decide whether system-following is an optional preference |
| P1 | [#262](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/262) (open) | Finder Open With association missing for common file types, e.g. Markdown | **Unestablished.** Audit bundle `CFBundleDocumentTypes`, Launch Services and Finder registration for R, Rmd, qmd, md, tex, el |
| P1 | [#236](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/236) (open) | Toolbar separators misrender in LaTeX mode | **Untested.** Inspect image-backed R toolbar and non-R toolbar under Cocoa, Retina and appearance changes |
| P1 | [#198](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/198) (open) | Aquamacs-specific automated regression suite requested | **Partially addressed architecturally.** Glassmacs has ERT, ESS/R and macOS launcher CI; physical GUI acceptance remains absent |
| P1 | [#184](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/184) (closed) | Bundled ESS path wrong | **Historical warning.** Verify bundled ESS load path, `ess-r-mode`, and R startup from installed app rather than assuming closure upstream proves parity |
| P2 | [#260](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/260) (open) | PostScript print command fails because modern macOS no longer supports that workflow | **Avoid reproducing obsolete feature.** Prefer system Print/PDF; inspect File menu for misleading PostScript actions |

## Concrete acceptance scenarios

### A. Last-window and Finder reopen (P0)
1. Launch current Glassmacs app, open an ordinary R file and close all graphical frames **without quitting**.
2. From Terminal, use `open -a /path/to/Glassmacs.app /tmp/glassmacs-reopen-test.R` (or Finder Open With).
3. Assert the file is shown in a visible frame, not merely loaded into an invisible buffer; Dock activation must not replace it with a blank document.
4. Repeat File → New Document, New Buffer in Mode and Cmd-N from the no-frame state. Record active frame, selected buffer and file path.

### B. Dialog, external-open and client stability (P0)
1. Repeatedly invoke File → Open and Open Recent, cancel and select files, including spaces and non-ASCII paths.
2. Open `.R`, `.Rmd`, `.qmd` and `.tex` from Finder and another application; watch for hangs, unexpected mode, wrong frame focus and duplicated buffers.
3. Invoke the **bundled** `emacsclient` in both create-frame and existing-frame modes; record whether client/server configuration is enabled.
4. Repeat while ESS has an active R process and while one document is modified.

### C. Modifiers, toolbar and appearance (P1)
1. Test left/right Option with ordinary accented input and Emacs Meta chords in Hybrid and Traditional profiles; do not presume hardware keyboard layouts behave identically.
2. Toggle macOS dark/light appearance; inspect text contrast, R toolbar icons, selection and modeline.
3. Inspect File, Edit, Options and Window menus in source, console, text and LaTeX modes; verify toolbar separator rendering and menu enablement.

## Evidence protocol and dispositions

For each candidate, capture: upstream issue URL/state and exact reported version, Glassmacs commit, app build architecture, macOS version, reproduction steps, expected/actual behavior, screenshot/log, whether upstream GNU Emacs already fixes the behavior, classification (**reproduced**, **not reproduced on tested build**, **not tested**, **intentional difference**, **obsolete upstream behavior**), owner, severity and follow-up PR or test. A negative test is scoped to its actual environment and does not close the question universally.

## Scope of subsequent passes

This first issue pass emphasizes safety and native lifecycle, followed by menu/keyboard/toolbar and ESS packaging. Subsequent passes should paginate older tracker issues and cover printing, clipboard, tabbar, scrolling, Retina/HiDPI, TRAMP, package installation, LaTeX, and performance. Do not automatically import every Aquamacs issue into Glassmacs; prioritize reproductions and desired workflows.

## Second draft — older issue families and implementation backlog (2026-10-27)

This extension samples older upstream tracker entries (including closed issues) and identifies **regression risks**, not reproduced Glassmacs defects. Links point to original reports; closed means historical upstream status only.

| Priority | Historical issue | Risk / difference to test | Proposed Glassmacs disposition |
| --- | --- | --- | --- |
| P0 | [#161](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/161) (open) | Confusing unsaved-document quit prompt | Exercise modified file, multiple dirty buffers, cancel and quit; compare Glassmacs review list with actual Emacs quit prompt |
| P0 | [#160](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/160) (closed) | Crash on Cmd-W of full-screen frame | Full-screen close/reopen regression; verify no orphaned unsaved buffers |
| P0 | [#168](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/168) (closed) | Arrow keys crash Save Buffer As dialog | Test native Save As navigation, overwrite, Unicode filenames and cancel |
| P0 | [#165](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/165) (closed) | Dired copy operation crashes | Test Dired file copy and confirm it is not misclassified as a document buffer |
| P1 | [#81](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/81) (open) | Desktop restoration duplicates frames/buffers | Workspace restore is currently a gap; require idempotent restore before introducing it |
| P1 | [#102](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/102) (closed) | emacsclient opens unwanted frame across macOS workspaces | Verify current policy when client request arrives from another Space |
| P1 | [#103](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/103) (closed) | TRAMP hangs when remote file is first document | Test SSH/TRAMP open from fresh app and remote file while ESS is active |
| P1 | [#98](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/98) (open) | Native pixel scrolling requested | Check modern Cocoa pixel scrolling and trackpad behavior; avoid reviving obsolete workaround |
| P1 | [#76](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/76) (closed) | Cut/Copy/Paste menu advertises incorrect shortcuts | Compare menu display with effective hybrid/traditional keymap in source and console buffers |
| P1 | [#153](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/153) (closed) | `recentf-exclude` ignored | Verify exclusions persist and Recent menu does not leak unwanted paths |
| P1 | [#87](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/87) (closed) | New frames appear on wrong monitor | Test multiple monitors and last-used frame placement; distinguish macOS Spaces behavior |
| P1 | [#95](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/95) (closed) | Toolbar flickers during frame creation | Stress new-frame creation with R toolbar enabled and disabled |
| P1 | [#70](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/70) (closed) | Scrolling triggers backtrace | Exercise trackpad/scroll wheel in large R scripts and ESS output |
| P1 | [#107](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/107) (closed) | Excessive CPU in HTML/Markdown editing | Profile large Markdown/R Markdown files; assess font-lock and parsing, not just ESS execution |
| P2 | [#137](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/137) (open) | Discoverability of default font / font panel | Audit Options/Appearance and persistence; decide whether dedicated menu action is warranted |
| P2 | [#151](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/151) (closed) | Delays opening HTML from a process inside Aquamacs | Test R-generated HTML previews and browser handoff without blocking the editor |
| P2 | [#138](https://github.com/aquamacs-emacs/aquamacs-emacs/issues/138) (closed) | License provenance of bundled toolbar icons | Verify icon licensing and source obligations before shipping a signed distribution |

### Consolidated implementation backlog (provisional)

| Rank | Workstream | Definition of done | Candidate historical evidence |
| --- | --- | --- | --- |
| 1 | Native document lifecycle | Finder/client opens after zero frames show the requested file; close/quit/save are non-destructive; full-screen close stable | #270, #219, #161, #160, #168, #247 |
| 2 | Cocoa file dialogs and external opens | Open, Save As, Recent, external app opens and Unicode paths do not hang; correct buffer/frame focus | #255, #241, #168, #153 |
| 3 | Keyboard and menu correctness | Visible shortcuts equal effective commands; independent modifier requirements explicitly decided | #233, #76 |
| 4 | R/ESS installed-bundle integrity | Bundled ESS loads and dispatches correctly; R-generated previews do not block GUI | #184, #151 |
| 5 | Multi-frame / display behavior | Predictable multiple monitors, Spaces, toolbar layout and frame creation | #87, #95, #102, #236 |
| 6 | Remote and large-file resilience | First-file TRAMP works, Markdown/R Markdown responsiveness and scroll behavior acceptable | #103, #107, #70, #98 |
| 7 | Workspace restoration design | Restore is explicit, idempotent, avoids duplicate frames, and never blindly revives R processes | #81 |
| 8 | Distribution and licensing | File associations, icons, signed/notarized release and licensing verified | #262, #138 |

### Triage policy

Each backlog item is a **candidate workstream** pending current-GUI reproduction. Record one acceptance result per tested macOS version/architecture and link it to the appropriate source issue. Do not open one Glassmacs issue per historical Aquamacs issue by default; group by underlying behavior and prioritize confirmed defects. Avoid porting obsolete implementation mechanisms (for example old tabbar, native PostScript printing or pre-pixel-scroll workarounds) solely for compatibility.

## Executable manual acceptance matrix — release-candidate GUI pass

**Scope:** These tests must run in a freshly built **graphical macOS Glassmacs.app**, not only in Emacs batch CI. Start from a clean disposable test directory and record exact Glassmacs commit, `emacs-version`, R/ESS versions, macOS build, architecture, keyboard layout and app signing state. Preserve a separate run for each tested architecture. Use a fresh Glassmacs profile or back up existing preferences; do not delete user configuration.

### Test data and setup

Build and validate using `./scripts/build-macos-app` and `./scripts/validate-macos-app build/Glassmacs.app`. Start the app from Finder or `open -a "$PWD/build/Glassmacs.app"` from the repository root. Install R and bootstrap optional ESS dependencies as documented in README. Create disposable `A.R` with `x <- 1 + 1\nprint(x)\n`, `B.R` with `print(42)\n`, `notes.md` with `# Smoke test\n`, `report.Rmd` with a minimal R chunk, and a `space name ü.R` file. Record full paths. Keep a second app launch available for a clean no-frame test; never use valuable documents for overwrite/cancel scenarios.

**Outcome notation:** PASS = observed expected behavior; FAIL = reproducible deviation with evidence; BLOCKED = dependency unavailable; NOT RUN = not attempted. **Do not prefill outcomes.** Each FAIL needs exact reproduction, log or screenshot, affected commit, severity, and a linked Glassmacs issue. Every test starts from the precondition stated; do not assume a prior test left the app in a usable state.

| ID | Priority | Precondition and actions | Expected result / acceptance criterion | Historical linkage |
| --- | --- | --- | --- | --- |
| GUI-01 | P0 | Launch app, open `A.R`, close final frame with Cmd-W; without quitting use `open -a "$PWD/build/Glassmacs.app" --args` only for a fresh launch, **or** `open -a "$PWD/build/Glassmacs.app" "/absolute/path/B.R"` to send a file event to the running app | `B.R` is visibly selected in a frame, not just a hidden buffer; Dock activation does not show an unrelated blank frame | #270, #219 |
| GUI-02 | P0 | Close final frame, click Dock icon, then invoke File → New Document / New Buffer in Mode | At least one responsive frame appears; new buffer is visible and uses selected major mode; no crash or silent no-op | #219, #270 |
| GUI-03 | P0 | With `A.R` modified, Cmd-W; choose Cancel when prompted. Repeat with Save, then Discard on disposable data | Cancel retains edits and frame; Save writes exactly once; Discard never changes on-disk file; no accidental silent loss | #161, #160 |
| GUI-04 | P0 | Two modified files plus an ESS console; invoke Review Unsaved Documents, then Cmd-Q and Cancel | Review lists ordinary modified documents, excludes console; cancel quit retains running app and edits; no duplicate or misleading save prompt | #161 |
| GUI-05 | P0 | Enter native fullscreen with modified `A.R`; Cmd-W then cancel/save as appropriate; reopen | No crash, hanging process, lost modifications or inaccessible window; fullscreen state is not corrupted | #160, #218 |
| GUI-06 | P0 | Save As `space name ü.R`, navigate dialog using arrows, cancel, then repeat and save; test existing target overwrite with Cancel | No crash; cancel leaves original buffer/path unchanged; confirmed save writes intended filename; overwrite cancellation preserves target | #168, #222 |
| GUI-07 | P0 | Repeat Open File and Open Recent at least 10 times, selecting/canceling; include spaces and Unicode paths | No hang, beachball or duplicate unexpected buffers; menu stays responsive and file focus correct | #255, #241 |
| GUI-08 | P0 | Finder Open With on `A.R`, `notes.md`, `report.Rmd`; repeat with no frames and with unsaved buffer | Each supported associated type opens visibly with appropriate mode and correct focus; unsupported associations recorded separately rather than assumed | #262, #270, #241 |
| GUI-09 | P0 | From `A.R`, start R, run line, selection, function and buffer; inspect output in ESS console | Correct code executes exactly once in intended session; source buffer remains accessible; no runaway output or UI freeze | #184 and Glassmacs R menu audit |
| GUI-10 | P0 | Start two R sessions; explicitly target one, execute from source, clear target, then execute again | Commands reach selected session only; ambiguous multiple sessions produce a prompt/error rather than silently choosing wrong process | Glassmacs session safety contract |
| GUI-11 | P1 | From fresh app, test bundled `emacsclient` with and without `-c` and when app is on another Space | No frame/window type error; client behavior respects documented policy; if server/client not configured, record BLOCKED rather than passing | #247, #102 |
| GUI-12 | P1 | Switch Hybrid/Traditional keyboard profiles; inspect File/Edit menus; exercise Cmd-C/V/X/Z, Shift-Cmd-Z and Option-key accents | Actual actions match displayed shortcuts; text input works; independent right-Option parity is recorded as gap where unavailable | #233, #76 |
| GUI-13 | P1 | Open source, ESS console, text and LaTeX buffer; inspect R menu and toolbars; toggle toolbar | R controls appear only where appropriate, images and separators render, disabled actions reflect context, no flicker | #236, #95 |
| GUI-14 | P1 | Open `A.R` then `B.R` under each opening policy: new-frame, new-tab, reuse-current | Each policy behaves as described, existing visible files are reused, transient ESS buffers do not become ordinary documents | #87, menu parity audit |
| GUI-15 | P1 | Change macOS appearance light→dark→light with Glassmacs running; check text, selection and R toolbar | No unreadable UI or missing toolbar images; record whether system-following is implemented or intentionally manual | #263 |
| GUI-16 | P1 | On two monitors/Spaces, open new frame and use fullscreen, then return to original display | No offscreen/inaccessible frame; focus and geometry usable; document deviations from macOS-managed placement | #87, #220 |
| GUI-17 | P1 | Open TRAMP SSH file as first document on a configured test host, then with ESS active | No indefinite UI hang; cancellation works; remote path not treated as local document | #103, #196 |
| GUI-18 | P1 | Open large `.Rmd` and large R console output; scroll via trackpad and edit | No unexpected backtrace, prolonged UI stall or unbounded output growth; record sample size and timing | #98, #70, #107 |
| GUI-19 | P1 | Dired copy disposable file; inspect Recent Files exclusions and save preferences, restart app | No Dired crash; recent exclusions and relevant settings persist where configured | #165, #153 |
| GUI-20 | P2 | Open File → Print and available page setup/PDF options | No obsolete PostScript command misrepresented as supported; native PDF/print path works or limitation recorded | #260 |

### Run sheet (copy per machine/build)

| Field | Value |
| --- | --- |
| Date / tester | NOT RUN |
| Glassmacs commit / app bundle | NOT RUN |
| macOS / CPU architecture / signing state | NOT RUN |
| Emacs / R / ESS versions | NOT RUN |
| Keyboard layout / external monitors | NOT RUN |
| GUI-01 … GUI-20 results | NOT RUN — fill one result per test ID |
| P0 failures / blocker issues | None evaluated |
| Screenshots, logs and reproducer links | None yet |

### Release gates and triage

- **Gate A — no P0 regressions:** GUI-01 through GUI-10 pass on the target release machine; BLOCKED is not PASS. Any data-loss, hang or wrong-session execution is release-blocking.
- **Gate B — compatibility disclosure:** P1 results are recorded and known gaps have deliberate dispositions; no claim of complete Aquamacs menu or modifier parity.
- **Gate C — distribution:** after GUI gates, test the *signed and notarized release candidate* separately under Gatekeeper, with Finder file associations and license/source notices. A development app does not satisfy this gate.
- **CI is necessary but insufficient:** Emacs batch, ESS/R integration and macOS launcher checks must pass on the exact candidate commit; they cannot certify interactive menus, dialogs, toolbar, Finder events or Quartz graphics.

Do not merge a functional fix on the strength of this checklist alone; add an automated regression test when feasible and rerun affected GUI cases.
