# Glassmacs menu and command architecture

> **Document ID:** DOC-MENU  
> **Status:** Proposed  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-20
> **Coverage:** Mac/Emacs menu taxonomy, Aquamacs menu inventory, command/capability mapping, context/state/shortcut contracts  
> **Supersedes:** None

This proposal complements the [behavioral inventory](aquamacs-compatibility.md), which owns parity requirements, the [keybinding specification](keybindings.md), and [architecture](architecture.md). It is a specification, **not implemented UI**.

## Design principles

1. **Commands first; UI second.** Keybindings, menu items, toolbar actions and optional Swift controls invoke shared interactive Emacs commands. Emacs keymaps, `menu-item` / `:enable` / `:visible` / `:button`, and `easy-menu` are the initial implementation substrate; do not implement a redundant command framework.
2. **Document-first Mac behavior.** New/Open creates a **new graphical frame by default** for an ordinary new document; tab creation is explicit or a selected setting. Source: [Aquamacs menu](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/macosx/aquamacs-menu.el), [frame management](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/one-buffer-one-frame.el). Exception: transient Help, ESS console, completions, diagnostic and internal buffers use dedicated routing.
3. **Contextual availability.** Menus report actual buffer major mode, selection, document dirty state, local/remote execution host, active project, ESS session, render tool availability, Shiny process and platform support. Disabled commands explain requirements where sensible; never offer actions that silently execute unknown project code.
4. **True stateful controls.** Toggles and radio groups read the same persistent settings as the command handlers; no independently cached Swift state. Do not hardcode displayed shortcuts when minor modes or modifier profiles alter effective bindings.
5. **Preserve Emacs extensibility.** Native major modes and packages remain able to contribute their own menus; avoid rewriting ESS/AUCTeX maps. Plain text does not require research packages.
6. **Mac conventions without duplication.** Cocoa owns OS-standard application menu placement, Services and window operations where supported; Glassmacs owns editing commands and policy. No parallel Swift text renderer.

## Command metadata contract

Stable command ID; existing command or minimal wrapper; label/description; category/location/order; keyboard binding/profile; context and enablement predicate; visible predicate; checked/radio state; requirement/capability (package/platform/executable); failure message; persistence owner if stateful; test ID. Keep capability evaluation side-effect-free (no SSH/network connection or R invocation merely to display a menu). User customizations and mode maps override defaults. Validate readback and menu state following each setting change.

## Menu-by-menu historical audit and modern destination

Historical source: [`aquamacs-menu.el`](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/macosx/aquamacs-menu.el) (`aquamacs3`), [`aquamacs-tool-bar.el`](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/aquamacs-tool-bar.el), [`osx_defaults.el`](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/macosx/osx_defaults.el), [`emulate-mac-keyboard-mode.el`](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/macosx/emulate-mac-keyboard-mode.el), and [`one-buffer-one-frame.el`](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/one-buffer-one-frame.el). The source line ranges below inventory the user-visible entries and stateful/dynamic contributions inspected. GNU Emacs and major-mode/package maps may contribute additional items at runtime; those are extension content rather than Aquamacs-owned commands.

| Historical menu / source range | Source-verified user commands and behavior | Glassmacs destination |
| --- | --- | --- |
| Application/Aquamacs: `aquamacs-menu.el` L1050–1156; `osx_defaults.el` reopen handler | About/quit/manual entries are customized around Cocoa; reopen-application restores a visible frame; customization and updates are surfaced where supported | **Glassmacs:** native app-menu placement for About, Settings, Services, Hide/Show and Quit; expose Glassmacs help/update only when implemented. Do not build a second app-menu renderer |
| File—creation/open: L55–225, L230–278 | Dynamic New Buffer in Mode and Change Buffer Mode; New Buffer in New Frame/Tab; Open; recent files; active command enablement; mode chooser uses known/recent modes and suppresses unavailable commands | **File:** New Document (new frame by default), New in Mode, explicit New in Window/Tab, Open, Open Recent. Use Emacs completion and mode commands |
| File—save/close/session: L278–288, L484–530, L495–503, L508–530 | Close Window (sometimes “and Buffer”), Reveal in Finder, Save/Load Session, Save Buffer, Save Buffer As; menu state varies with live frame/buffer | **File:** Save/Save As/Close Document, Reveal, Save/Restore Workspace. Keep view, buffer and document close semantics distinct; preserve unsaved prompts |
| File—print/export: L297–310, L535–610 | Copy Formatted, Copy as PDF, Page Setup, Print Region/Buffer; some export declarations are commented/disabled in this source | **File:** maintained export and native print commands; distinguish implemented from commented historical proposals and unavailable dependencies |
| Edit: L290–355, L459–477, L748–766, L946–1031 | Copy/Cut/Paste, Undo/Redo, Select All, Fill/Unfill, Smart Word Spacing, Spelling and Count Words; some labels are modified to display macOS shortcuts | **Edit:** existing Emacs commands and keymaps for editing, fill, spell and count; use one command dispatch path |
| Search and Go To: L356–375, L777–785, L929–945 | Forward/repeat-forward/repeat-backward search, use region for search, case-insensitive option, Go to Line | **Search/Navigate:** Emacs incremental search, use selection, effective case-fold setting, Go to Line; project/symbol actions are Glassmacs extensions |
| Options/View: L640–925, especially L748–925 | Smart spacing; tabbar and one-buffer-one-frame toggles; user-interface visibility and display options; fringe widths; backups; Save Place; Customize and Save Options. Menu checks/options refer to actual variables | **View + Settings:** accessible toggles/radios backed by existing Emacs modes or Glassmacs preferences. Document opening policy stays explicit and separate from auxiliary buffer routing |
| Keyboard submenu: `emulate-mac-keyboard-mode.el`; added under Options | Option as Meta or system/composed-character input; right Option and right Command independently set to Meta; language layout emulation modes; menu toggle/check state | **Settings > Keyboard:** preserve text input by default; expose left/right modifier choices and international input behavior through current Emacs APIs, not old translation tables |
| Buffers/Window/Extras: `aquamacs-menu.el` L1161–1300 | Font zoom; Join Windows; Split Window; Show Buffer in New Frame; Scatter; Tile vertically/horizontally; Full Screen Editing; generated buffer menu entries, switching and frame placement | **Window:** frame/tab/document/window operations with actual capability predicates; **Navigate:** buffer switch and document navigation |
| Toolbar: `aquamacs-tool-bar.el` | New/Open/Recent/Close/Revert/Save/Save As/Print/Undo/Redo/Cut/Copy/Paste/Search/Spelling/New Window/Preferences/Help; buttons inherit visibility, enablement and command behavior from menu/map | Shared commands on optional standard Emacs toolbar. Preserve user configurability where supported; don't port Aquamacs toolbar conversion internals |
| Tools: `aquamacs-menu.el` L447–454, L946–990 | Install Command Line Tools; spelling is moved from Tools to Edit; upstream/package tool entries may remain | **Tools/Research:** show optional tools only when available and avoid installer side effects. Native mode/package maps remain authoritative |
| Help: L1050–1156, L1420–1515 | Aquamacs Manual, Tips Wiki, Homepage, Emacs Manual, Lisp Intro/Reference, glossary, manuals, man page, package manuals, lookup all manuals, printable language reference cards | **Help:** Glassmacs manual and keyboard reference, Emacs/package Info manuals, Search All Help and optional support link; no obsolete Aquamacs-specific copy |
| Dynamic language/package menus | Major-mode maps and package menus supplied by ESS, AUCTeX, Org and other modes; recent/common mode list is generated by Aquamacs, not a static mode inventory | **Research / mode maps:** use active mode's keymaps and existing interactive commands. Add only Glassmacs workflows not already provided upstream |

This is a substantive command inventory, not a dump of every translated reference-card entry or every upstream Emacs menu item. For source-verified completeness, check the cited ranges and the effective runtime maps; a commented-out historical menu declaration is not an enabled feature. The compatibility matrix records implementation status and per-feature acceptance tests.

### Dynamic menu coverage

- **New Buffer in Mode / Change Buffer Mode:** built from known and recently used major modes (`aquamacs-menu.el` approx. 55–225). Never require installing a package to list its mode; unavailable mode disabled or omitted.
- **Next/Previous Tab or Buffer:** label and handler follow effective document display policy. `Move Tab to New Frame`, `Hide Tab`, `Merge All Frames` act on identifiable document/tab objects, not whichever frame happens to be selected after asynchronous work.
- **Open/Save/Close:** label, disabled state and keyboard presentation depend on active ordinary document. Separate close tab/frame/buffer actions and use consistent unsaved-work prompts.
- **Research:** `.R` offers ESS source evaluation and session selection; R console offers console actions; `.Rmd` knitting/rendering and chunk evaluation; `.qmd` Quarto render/preview; `.Rnw` Sweave/knitr and TeX; `app.R` / Shiny project run/stop/preview; `.tex` AUCTeX build/synctex; model files surface appropriate optional profiles. No false enablement when CLI missing or remote host unknown.
- **Toggles/radios:** document opening policy: New Window (default), New Tab, Reuse Current; presentation: tabs visible, toolbar, font/theme, line highlight, fringes, word wrap; modifier mappings and user-configured research backend. On change, update commands and effective menu state immediately, then persist safely.
- **Menu refresh:** Aquamacs checks modifier state in `aquamacs-update-menu`; Glassmacs should read actual keymaps and settings without rebuilding expensive entire menu trees on every redisplay.

## Proposed menu structure

**Glassmacs:** About, Settings…, Keyboard Profile, Check for Updates, Services, Hide/Quit.

**File:** New Document (new window by default), New in Mode…, New in New Window, New in New Tab, Open…, Open Recent, Save, Save As…, Reveal in Finder, Close Document, Save Workspace…, Restore Workspace…, Export/Print/Page Setup.

**Edit:** Undo/Redo, Cut/Copy/Paste, Copy Formatted/As PDF, Select All, Find/Replace/Find Next/Use Selection, Fill/Unfill, Smart Spacing, Spelling, Count Words.

**View:** Appearance, Per-Mode Fonts, Show Tabs, Toolbar, Line Numbers/Highlight, Fringes, Show Formatting Characters, Soft/Hard Wrap, Zoom, Full Screen.

**Navigate:** Go to Line, Switch Buffer, Recent Locations, Next/Previous Tab/Document, Change Mode, Project Files, Definitions.

**Research:** Start/Select R Session, Evaluate Region/Function/Buffer, Documentation, Render R Markdown, Quarto Render/Preview, Sweave/knitr, LaTeX Build/PDF Preview, Run/Stop/Preview Shiny, Choose Execution Host, Research Profiles, Queue/Logs. Only show appropriate, supported capabilities by context.

**Window:** New Window, Open Current Document in New Window/Tab, Move Tab to Window, Hide Tab, Merge Frames/Tabs, Join/Split Editor, Tile/Scatter, Switch Window, Restore Layout, Close Window.

**Help:** Glassmacs manual, keyboard shortcuts, Emacs/ESS and research package manuals, Search All Help, reference cards, report problem.

These headings are conceptual; Cocoa may place Window and Help and the app menu natively. Don't claim exact native UI behavior until verified.

## Specific settings/menu integration contract

The primary control must be available in **Settings > Documents & Windows**, clearly labeled **"Open new documents in: New Window / New Tab / Current Window"** with **New Window selected by default** on graphical macOS. File and Window menus must also expose explicit "Open in New Window" / "Open in New Tab" commands independent of the default. Changing setting immediately affects subsequent file-open/new-document requests; it does not move already-open buffers. Setting persists across application restart within `GLASSMACS_HOME`; no changes to ~/.emacs, existing Aquamacs or users' global Emacs config.

The application must also expose "Show auxiliary buffers in: existing document window (recommended) / independent frames" as a separate advanced preference with safe defaults. Critical exceptions include ESS, Help, Completions, compilation diagnostics and interactive prompts.

## Test plan and evidence

1. **ERT:** command/keymap definitions, dynamic mode menu construction, context/enable predicates, checked/radio state, preference round-trip; no hidden dependency loading or execution; menu state matches actual keybinding.
2. **macOS GUI:** verify File > New / Open and Finder events create separate frames by default; toggle to tabs/reuse; Command-W/Command-Q unsaved prompts; tab detach/merge; full-screen/window layout, Apple menu placement.
3. **Nonmac/TTY:** no forced Mac-specific frames or shortcut hijacking.
4. **Research:** menus only offer supported ESS/Quarto/Shiny/LaTeX execution for active context and correct local/SSH host; never perform network access when merely opened.
5. **Accessibility/international input:** keyboard navigation, readable labels, right/left Option and composed characters.

**No menu should be marked parity complete** without inspecting its effective runtime keymap or GUI behavior. Historical code contains at least one questionable annotated File > Open shortcut (`Command-S`), which must not be copied uncritically. Use source references and record tested deviations in the compatibility inventory.
