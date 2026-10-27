# Aquamacs → Glassmacs: menu parity and deliberate differences

> **Document ID:** DOC-AQUA-MENU-AUDIT  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-27  
> **Last reviewed:** 2026-10-27  
> **Coverage:** Source-oriented menu gap register, decisions, evidence and GUI acceptance tasks  
> **Supersedes:** None

This is the **first comparison pass**, not a claim of full Aquamacs parity. Historical Aquamacs menu behavior is described in [menu architecture](menu-architecture.md) and the [behavioral inventory](aquamacs-compatibility.md), which trace the `aquamacs3` source at `5a2833896341ea02b65ef7ca145a2de3b5f82f30`. Glassmacs command evidence comes from the merged Lisp implementation. The macOS application menu is partly Cocoa-owned, so source-level keymaps alone cannot prove what appears in the running application.

## Evidence and classification

- **Implemented (I):** a Glassmacs-specific command or menu binding exists in merged source; rendering and action dispatch may still need GUI testing.
- **Inherited (U):** an upstream GNU Emacs or package command is expected; not a claim of exact Aquamacs labeling or placement.
- **Partial (P):** some behavior exists, but the historical workflow is not fully represented.
- **Missing (M):** no equivalent Glassmacs-specific implementation established in this pass.
- **Intentional difference (D):** product policy deliberately differs from Aquamacs.
- **GUI unverified (G):** final menu visibility, enabled state, placement or window behavior still needs a physical Mac check.

## Menu-by-menu gap register

| Menu / historical Aquamacs affordance | Glassmacs evidence | Status | Decision / follow-up |
| --- | --- | --- | --- |
| Application: About, Preferences, Hide, Quit, reopen | `glassmacs-macos.el` installs Cocoa preferences event and frame lifecycle hooks; Cocoa owns native application menu | P/G | Verify native placement, Cmd-Q, reopen after last window and preference dispatch; do not duplicate Cocoa menu |
| File: New Buffer in Mode…, Change Buffer Mode… | `glassmacs-frames.el` installs both commands under File | I/G | Check availability, chosen mode, untitled buffer, window policy |
| File: New/Open with one-buffer-one-frame/tab behavior | `glassmacs-document-opening-policy` defaults to `new-frame` on macOS, with tab/reuse options | I/D/G | Intentional default: new **window**, not Aquamacs tabbar default; test existing-file focus and Finder opens |
| File: Open Directory, Open Recent | GNU Emacs base menus expected; no distinct Aquamacs recent-file presentation established | U/P/G | Audit effective menu, ordering and recent-list behavior; avoid duplicate upstream items |
| File: Save, Save As, dirty-document prompts | Native Emacs save/close commands; `glassmacs-save-document-as` uses `write-file`; unsaved review is read-only | I/U/G | Test overwrite, untitled save, cancel, close-last-window and quit |
| File: Reveal in Finder, Save/Restore Workspace | No Glassmacs-specific equivalents established | M | Assess upstream equivalents; prioritize safe workspace restoration separately from R process resurrection |
| File: Print, Page Setup, Copy Formatted/PDF | Upstream facilities may exist; Aquamacs-specific workflow not ported | U/P | Audit menu availability and macOS print integration before implementing adapters |
| Edit: Cut/Copy/Paste/Select All/Undo | `glassmacs-keys.el` hybrid Command bindings and Emacs edit primitives | I/U/G | Validate clipboard, selection and undo in Cocoa; audit Shift-Command-Z redo separately |
| Edit: Fill/Unfill, smart spacing, spelling, word count | Primarily upstream editing facilities; Aquamacs custom wrappers not ported | U/P | Test real keymaps; decide if a narrow unfill/smart-spacing adapter is worthwhile |
| Search / Go To | GNU Emacs incremental search and navigation plus hybrid Command-F | U/I/G | Compare search-repeat, selected-region search and Go To placement/shortcuts |
| Options / View: interface, wrapping, backup, Save Place | Upstream Customize and modes; Glassmacs opening and toolbar preferences | P/G | Build a prioritized, stateful menu inventory; distinguish hard wrap from visual wrap |
| Keyboard: Option/Meta and independent right modifiers | Hybrid / Traditional profile menu and `glassmacs-keyboard-profile` | P/G | No verified parity for Aquamacs independent right-Option/right-Command and international layouts |
| Window / Buffers: new window, split/join, zoom, scatter/tile, fullscreen | `glassmacs-new-window` and upstream frame/window commands | P/G | Audit actual Window and Buffers menus; distinguish frame, Emacs window, tab and buffer |
| General toolbar: New/Open/Save/Print/Undo/Edit/Search/Help | No complete Aquamacs general toolbar mapping established | P/G | Preserve upstream toolbar where possible; audit icons, mode switching and missing actions |
| R source menu and contextual toolbar | `glassmacs-r-ui.el`: source menu, ESS-backed evaluation and image-backed toolbar entries | I/G | New Glassmacs R-first workflow, not literal Aquamacs toolbar parity; verify Cocoa images/enablement |
| R console menu and sessions | `glassmacs-r-ui.el` and `glassmacs-sessions.el`: console actions, session start/target/list/interrupt | I/G | Verify correct session and no silent targeting across multiple processes |
| Tools: command-line tools, package-provided actions | Upstream/package menus; no Aquamacs installer equivalent established | U/P | Decide whether command-line helper installation is required; do not install implicitly |
| Help: Aquamacs manuals, tips, cards, glossary | GNU Emacs/ESS help remains; Glassmacs-specific help destinations not fully mapped | U/P | Replace obsolete Aquamacs destinations with current Glassmacs documentation only when available |

## Highest-priority comparison tests

1. **File and application lifecycle (P0):** create/open A.R and B.R, change opening policy, save modified untitled files, cancel close, Cmd-W and Cmd-Q, Dock reopen.
2. **R source/console (P0):** inspect visible R menus and toolbar, run line/selection/function/buffer, start/target multiple sessions, interrupt, verify no wrong-session dispatch.
3. **Edit/Search/Keyboard (P1):** compare effective shortcuts and visible menu labels against Aquamacs, including international Option-key input and redo.
4. **Window/View/Options (P1):** inspect check/radio state, frame vs tab operations, toolbar and wrap settings.
5. **Print/Help/Tools (P2):** assess whether upstream behavior suffices; avoid duplicating functionality merely to match menu text.

## Decisions to preserve

- Default new ordinary document → new graphical macOS window, **not** automatic Aquamacs-style tabbar.
- Use native Cocoa application menu and GNU Emacs command/keymap infrastructure, not a parallel menu renderer.
- ESS R consoles and transient Help/completion buffers must not be treated as ordinary document windows.
- Source/console R menus and toolbar share actual ESS/Glassmacs commands.
- User data safety and explicit R-session selection take precedence over superficial historical similarity.

## Next pass: historical Aquamacs issue audit

Review the historical issue tracker **after** confirming menu gaps against source and current GUI. For each issue record: historical URL and issue number, last known reproduction and version, affected menu/workflow, whether current upstream Emacs already fixed it, Glassmacs status (reproduced / not reproduced / untested / intentional difference), severity, proposed action, and an acceptance test. Do not label historical issues as Glassmacs bugs without a current reproduction. Prioritize data loss, window lifecycle, clipboard/keyboard, R/ESS, then cosmetic parity.
