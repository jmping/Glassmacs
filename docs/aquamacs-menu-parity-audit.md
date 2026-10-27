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

## Second pass — concrete command and menu-keymap crosswalk (2026-10-27)

The following entries are checked against the current merged Glassmacs Lisp, rather than inferred from the roadmap. Paths are source evidence; **they do not prove Cocoa displays the item**. The identifiers in square brackets are Emacs keymap event paths, not keyboard shortcuts.

| UI location | Menu-keymap entry or function | Implementation | Specific difference / verification |
| --- | --- | --- | --- |
| File → New Document | `[menu-bar file new-document]` → `glassmacs-new-document` | `lisp/glassmacs-frames.el` | New untitled buffer with policy-dependent frame/tab/reuse; compare Aquamacs New Buffer in New Frame/Tab |
| File → New Buffer in Mode… | `[menu-bar file glassmacs-new-in-mode]` → `glassmacs-new-buffer-in-mode` | `lisp/glassmacs-frames.el` | Choice list is filtered to available major modes; historical Aquamacs mode list may differ |
| File → Change Buffer Mode… | `[menu-bar file glassmacs-change-mode]` → `glassmacs-change-buffer-mode` | `lisp/glassmacs-frames.el` | Explicit mode change confirmation, rather than assuming Aquamacs's exact mode-list UI |
| File → Open File… | `[menu-bar file open-file]` → `glassmacs-open-file` | `lisp/glassmacs-frames.el` | Ordinary files follow `new-frame` default; already-visible buffers reuse their window |
| File → Visit New File… | `[menu-bar file new-file]` → `glassmacs-open-file` | `lisp/glassmacs-frames.el` | Shares open policy; test new-file creation and cancel |
| File → Save Document As… | `[menu-bar file glassmacs-save-document-as]` → `glassmacs-save-document-as` | `lisp/glassmacs-frames.el` | Delegates to `write-file`, retaining native Emacs overwrite checks |
| File → Review Unsaved Documents… | `[menu-bar file glassmacs-review-unsaved]` | `lisp/glassmacs-frames.el` | New read-only list; not historical Aquamacs Save/Load Session |
| File and Window → New Window | `glassmacs-new-window` | `lisp/glassmacs-macos.el` | Creates an Emacs graphical frame; verify native Window menu placement |
| Glassmacs → Document Opening… | `glassmacs-set-document-opening-policy` | `lisp/glassmacs-macos.el` | Persistent `new-frame` / `new-tab` / `reuse-current` choice, currently a command prompt, **not** a visible radio submenu |
| Glassmacs → Document Preferences… | `glassmacs-open-document-preferences` | `lisp/glassmacs-macos.el` | Customize group; no bespoke native preferences pane |
| Glassmacs → Keyboard Profile | `glassmacs-select-hybrid-keyboard-profile`, `glassmacs-select-traditional-keyboard-profile` | `lisp/glassmacs-macos.el` | Radio items reflect effective profile; no separate right-side modifier controls |
| Glassmacs → Review Unsaved Documents… | `glassmacs-review-unsaved-documents` | `lisp/glassmacs-macos.el` | Duplicate entry point to same command, not duplicate implementation |
| Cocoa Preferences event | `[ns-show-prefs]` → `glassmacs-open-preferences` | `lisp/glassmacs-macos.el` | Opens Glassmacs Customize; verify Cocoa event delivery |
| Cocoa reopen event | `[ns-new-frame]` → `glassmacs-reopen` | `lisp/glassmacs-macos.el` | Verify Dock reopen and final-frame reuse in actual signed app |
| R source → Run Line/Selection/Function/Buffer | `glassmacs-r-send-line`, `-region`, `-function`, `-buffer` | `lisp/glassmacs-r-ui.el` | Buffer-local R menu; dispatch through ESS and explicit session resolution |
| R source → Start R and Target This Buffer | `glassmacs-r-start-and-target-session` | `lisp/glassmacs-r-ui.el` | Glassmacs-specific convenience; must retain origin buffer when ESS opens console |
| R source → Start Another / Show Target / Clear Target / List Sessions | `glassmacs-r-start-session`, `glassmacs-r-show-target-session`, `glassmacs-r-clear-session-target`, `glassmacs-r-list-sessions` | `lisp/glassmacs-r-ui.el` | Session management beyond generic historical menu mapping |
| R console → Previous Command / Interrupt / Sessions | `comint-previous-input`, `glassmacs-r-interrupt`, session commands | `lisp/glassmacs-r-ui.el` | Console menu distinct from R source; check mode switching and menu visibility |
| R context menu → Queue / Output / Working Directories | `glassmacs-r-ui-context-menu` and related commands | `lisp/glassmacs-r-ui.el` | Context-menu-only affordances must not be mistakenly counted as top-level R menu parity |
| R toolbar | `glassmacs-r-ui--toolbar-map` and `glassmacs-r-show-toolbar` | `lisp/glassmacs-r-ui.el` | Image-backed `tool-bar-map` actions; Cocoa image support and placement remain unverified |

### More precise gaps exposed by the crosswalk

1. **Menu policy state:** The opening-policy command persists a choice, but unlike the keyboard-profile menu, it is not implemented as a three-item radio submenu. Aquamacs-style discoverability and checked state remain partial.
2. **General toolbar versus R toolbar:** The R toolbar is implemented separately; it does not establish historical Aquamacs general toolbar parity (Save, Print, Undo, clipboard, Search, Help).
3. **Top-level versus context menus:** Session queue, output and directory commands are in an R context menu. Their presence does not prove equivalent top-level menu access or discoverability.
4. **Native preferences versus Customize:** The Cocoa Preferences event is handled, but opens an Emacs Customize group, not a dedicated macOS Settings window.
5. **Document close versus frame close:** The current keyboard path uses frame-oriented semantics. Historical Aquamacs close-buffer/close-document behavior requires explicit GUI comparison, especially when the same buffer has multiple views.
6. **Keyboard modifier parity:** Hybrid/Traditional profiles do not establish independent left/right Option and Command modifier controls or international input parity.
7. **Missing historical conveniences:** Reveal in Finder, named workspace save/load, advanced tab detach/merge, smart word spacing and formatted/PDF clipboard actions have no Glassmacs-specific equivalents established by this inspection. Check upstream Emacs before creating replacements.

### Evidence limits and next verification

The historical menu taxonomy is already traced in `docs/menu-architecture.md`; this pass confirms **Glassmacs command names and keymap locations**, not the final appearance or behavior of either app. Before converting a gap into a feature issue, inspect GNU Emacs's effective menu in a current macOS build and the relevant historical Aquamacs source. Capture screenshots and command-resolution evidence for each discrepancy. Historical Aquamacs issue triage is the following pass, not part of this one.
