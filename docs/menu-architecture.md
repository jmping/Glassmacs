# Glassmacs menu and command architecture

> **Document ID:** DOC-MENU  
> **Status:** Proposed  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-19  
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

Historical source: `aquamacs/src/site-lisp/macosx/aquamacs-menu.el` (`aquamacs3`, ~1533 lines), `aquamacs-tool-bar.el`, `osx_defaults.el`, `emulate-mac-keyboard-mode.el`. Entries below enumerate **substantive user operations**, not every separator, internal menu variable, generated help card, or obsolete/dead conditional. A future agent should produce per-entry machine-checkable coverage from Emacs menu keymaps before claiming exact parity.

| Historical Aquamacs area | Observed operations | Glassmacs destination and contract |
| --- | --- | --- |
| Application/Aquamacs | Quit, application help, update check, preferences, reopen/unhide | **Glassmacs:** About, Settings, keyboard profile, updates, Services, Quit; native placement where possible |
| File | New frame, New tab, New Buffer in Mode, Change Mode, Open, recent files, Save, Save As, Close, Reveal in Finder | **File:** New Document (new frame by default), New in Mode, Open, Open Recent, Save, Save As, Open in New Window/Tab, Reveal, Close Document |
| File/session | Save Session As, Load Session, print, Page Setup, formatted/PDF copy/export | **File:** Save/Restore Workspace; Print/Page Setup/Export. Structured session persistence (R process not falsely restored) |
| Edit | Undo/redo, cut/copy/paste, select all, formatted/PDF copy, fill/unfill, spell, count words | **Edit:** native-feeling basic editing and text transformations |
| Search/Go To | Forward/repeat/backward search, use region, goto line | **Find/Navigate:** search, use selection, go to line, project/symbol locations |
| Options | Tabs, separate frames, UI visibility, line/newline/paren highlighting, fringes, wrap, smart spacing, backup toggle | **View + Settings:** typed, persisted options with synchronized checked/radio state |
| Customize | Customize Aquamacs, top-level customize, Save Options | **Glassmacs > Settings:** organized preferences + Advanced Emacs Customize; expose save/readback |
| Keyboard | Option as Meta, composed characters, right Option/Command as Meta, layout maps | **Settings > Keyboard:** separate physical/logical layout and modifier choices |
| Buffers/Window/Extras | Next/previous tab or buffer, move tab to new frame, hide tab, merge frames, zoom, split/join, new frame, tile/scatter, fullscreen | **Window:** document/frame/tab operations, capability-checked context |
| Toolbar | Recent files, file actions, print, spelling, visibility and user customization | Shared commands surfaced through configurable toolbar, no separate business logic |
| Tools | Command-line tool installation, spell and package tools | **Tools/Research:** CLI integration and language tooling; keep upstream package menus |
| Help | Aquamacs manual, Emacs manual, glossary, Lisp docs, package manuals, reference cards, online support | **Help:** Glassmacs guide, package manuals, offline Help, shortcuts and reference cards |
| Language/research | Mode-specific R and other package commands | **Research** context menu for ESS/R, Quarto, R Markdown, Sweave, Shiny, LaTeX, statistical profiles |

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
