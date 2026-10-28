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
