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
