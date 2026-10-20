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
2. **Document-first Mac behavior.** New/Open creates a **new graphical frame by default** for an ordinary new document; tab creation is explicit or a selected setting. This intentionally replaces Aquamacs' tabbar-oriented default. Sources: [Aquamacs menu](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/macosx/aquamacs-menu.el), [frame management](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/one-buffer-one-frame.el). Exception: transient Help, ESS console, completions, diagnostic and internal buffers use dedicated routing.
3. **Contextual availability.** Menus report actual buffer major mode, selection, document dirty state, local/remote execution host, active project, ESS session, render tool availability, Shiny process and platform support. Disabled commands explain requirements where sensible; never offer actions that silently execute unknown project code.
4. **True stateful controls.** Toggles and radio groups read the same persistent settings as the command handlers; no independently cached Swift state. Do not hardcode displayed shortcuts when minor modes or modifier profiles alter effective bindings.
5. **Preserve Emacs extensibility.** Native major modes and packages remain able to contribute their own menus; avoid rewriting ESS/AUCTeX maps. Plain text does not require research packages.
6. **Mac conventions without duplication.** Cocoa owns OS-standard application menu placement, Services and window operations where supported; Glassmacs owns editing commands and policy. No parallel Swift text renderer.

## Command metadata contract

Stable command ID; existing command or minimal wrapper; label/description; category/location/order; keyboard binding/profile; context and enablement predicate; visible predicate; checked/radio state; requirement/capability (package/platform/executable); failure message; persistence owner if stateful; test ID. Keep capability evaluation side-effect-free (no SSH/network connection or R invocation merely to display a menu). User customizations and mode maps override defaults. Validate readback and menu state following each setting change.

This is a **documentation contract**, not a proposed command registry or UI framework. Prefer the existing interactive command symbol and its keymap; a menu item should reference that command. Add a wrapper only when Glassmacs policy differs from upstream behavior or needs a useful context-aware prompt. Stable feature IDs in the compatibility inventory identify user-visible requirements; they do not require generating a parallel command database.

### Context, capabilities and state

- Derive context from ordinary Emacs state: `current-buffer`, `major-mode`, active region, selected window/frame, `buffer-file-name`, `file-remote-p`, `project-current`, the associated live process/session, and current frame system. Do not keep a second document/window selection model.
- Capability predicates are cheap and side-effect-free: command exists (`commandp`), mode/package is available (`fboundp`/`locate-library`), executable is discoverable (`executable-find`), document/region is applicable, frame is graphical, or process is already live. A menu update must not start a process, load project code, connect SSH, render a document, or change the selected buffer.
- **Enabled** means invocation can proceed in the current context; **visible** is reserved for genuinely irrelevant/unsupported items, not preference. Disabled items should say what is unavailable where the toolkit supports help text.
- **Checked** state is read from the command's authoritative Emacs mode/variable or Glassmacs preference. **Radio** state is the effective single choice, such as `new-frame` / `new-tab` / `reuse-current`; setting it changes future opens and does not move existing documents.
- **Shortcut labels** come from the effective keymap after active major/minor maps and the selected keyboard profile are applied. Never copy a historical annotation string or cache a displayed shortcut as the binding.
- A capability that needs an external executable must only test its presence for menu state. It should not probe by running it. Remote host/session status may be read only from an already configured identity/live process; do not connect to determine enablement.

## Menu-by-menu historical audit and modern destination

Historical source: `jmping/aquamacs-emacs`, branch `aquamacs3`, inspected at revision [`5a2833896341ea02b65ef7ca145a2de3b5f82f30`](https://github.com/jmping/aquamacs-emacs/commit/5a2833896341ea02b65ef7ca145a2de3b5f82f30). Key files: [`aquamacs-menu.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/macosx/aquamacs-menu.el), [`aquamacs-tool-bar.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/aquamacs-tool-bar.el), [`osx_defaults.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/macosx/osx_defaults.el), [`emulate-mac-keyboard-mode.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/macosx/emulate-mac-keyboard-mode.el), [`one-buffer-one-frame.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/one-buffer-one-frame.el), and GNU baseline [`menu-bar.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/lisp/menu-bar.el). Source establishes Lisp-defined actions, not every menu item rendered by native Cocoa.

| Historical menu / source range | Source-verified user commands and behavior | Glassmacs destination |
| --- | --- | --- |
| Application/Aquamacs: `aquamacs-menu.el` L1050–1156; `osx_defaults.el`; `lisp/term/ns-win.el` | About and Preferences are native application events; Quit is removed from File and dispatched as an application-quit event to save/exit; reopen restores a visible frame; Aquamacs registers update/help destinations | **Glassmacs:** native app-menu placement for About, Settings, Services, Hide/Show and Quit; expose help/update only when implemented. Do not build a second app-menu renderer |
| File—creation/open: `aquamacs-menu.el` L55–225, L230–278; GNU `menu-bar.el` File menu | Dynamic New Buffer in Mode and Change Buffer Mode; New Buffer in New Frame (`Cmd-N`) / New Buffer in New Tab (`Cmd-T`); Open (`Cmd-O`), Open Directory, recent files up to 25 entries (basename labels), contextual availability | **File:** New Document (new frame by default), New in Mode, explicit New in Window/Tab, Open, Open Directory, Open Recent. Use Emacs completion and mode commands |
| File—save/close/session: L278–288, L484–530, L495–503, L508–530 | Close Window (sometimes “and Buffer”), Reveal in Finder, Save/Load Session, Save Buffer, Save Buffer As; menu state varies with live frame/buffer | **File:** Save/Save As/Close Document, Reveal, Save/Restore Workspace. Keep view, buffer and document close semantics distinct; preserve unsaved prompts |
| File—print/export: L297–310, L535–610 | Copy Formatted, Copy as PDF, Page Setup, Print Region/Buffer; some export declarations are commented/disabled in this source | **File:** maintained export and native print commands; distinguish implemented from commented historical proposals and unavailable dependencies |
| Edit: `aquamacs-menu.el` L250–440, L459–477, L748–766, L946–1031; `aquamacs-editing.el` L25–70 | Cut/Copy/Paste/Select All (`Cmd-X/C/V/A`), Undo (`Cmd-Z`), Redo (`Shift-Cmd-Z`), Copy Formatted/Copy as PDF, Fill/Unfill (`M-q`/`M-Q`), Smart Word Spacing, Spelling and Count Words. CUA mode is enabled while ordinary kill-ring clipboard synchronization is disabled; clipboard actions use wrappers | **Edit:** existing Emacs commands/maps for editing, fill, spell and count. Keep ordinary kill-ring behavior distinct from explicit system clipboard commands |
| Search and Go To: L356–375, L777–785, L929–945 | Forward/repeat-forward/repeat-backward search, use region for search, case-insensitive option, Go to Line | **Search/Navigate:** Emacs incremental search, use selection, effective case-fold setting, Go to Line; project/symbol actions are Glassmacs extensions |
| Options/View: L640–925, especially L748–925 | Smart spacing; tabbar and one-buffer-one-frame toggles; user-interface visibility and display options; fringe widths; backups; Save Place; Customize and Save Options. Menu checks/options refer to actual variables | **View + Settings:** accessible toggles/radios backed by existing Emacs modes or Glassmacs preferences. Document opening policy stays explicit and separate from auxiliary buffer routing |
| Keyboard submenu: `emulate-mac-keyboard-mode.el`; added under Options | Option as Meta or system/composed-character input; right Option and right Command independently set to Meta; language layout emulation modes; menu toggle/check state | **Settings > Keyboard:** preserve text input by default; expose left/right modifier choices and international input behavior through current Emacs APIs, not old translation tables |
| Buffers/frame-tab extras: `aquamacs-menu.el` L1161–1300 | Font zoom; Join Windows; Split Window; Show Buffer in New Frame; Scatter; Tile vertically/horizontally; Full Screen Editing; generated buffer menu entries, switching and frame placement. The Lisp additions are attached to the Buffers menu; the native Cocoa Window menu is not inventoried by these files | **Window:** frame/tab/document/window operations with actual capability predicates; **Navigate:** buffer switch and document navigation |
| Toolbar: `aquamacs-tool-bar.el` | New/Open/Recent/Close/Revert/Save/Save As/Print/Undo/Redo/Cut/Copy/Paste/Search/Spelling/New Window/Preferences/Help; buttons inherit visibility, enablement and command behavior from menu/map | Shared commands on optional standard Emacs toolbar. Preserve user configurability where supported; don't port Aquamacs toolbar conversion internals |
| Tools: `aquamacs-menu.el` L447–454, L946–990 | Install Command Line Tools; spelling is moved from Tools to Edit; upstream/package tool entries may remain | **Tools/Research:** show optional tools only when available and avoid installer side effects. Native mode/package maps remain authoritative |
| Help: L1050–1156, L1420–1515 | Aquamacs Manual, Tips Wiki, Homepage, Emacs Manual, Lisp Intro/Reference, glossary, manuals, man page, package manuals, lookup all manuals, printable language reference cards | **Help:** Glassmacs manual and keyboard reference, Emacs/package Info manuals, Search All Help and optional support link; no obsolete Aquamacs-specific copy |
| Dynamic language/package menus | Major-mode maps and package menus supplied by ESS, AUCTeX, Org and other modes; recent/common mode list is generated by Aquamacs, not a static mode inventory | **Research / mode maps:** use active mode's keymaps and existing interactive commands. Add only Glassmacs workflows not already provided upstream |

### Inherited menu contents and source interpretation

The baseline GNU Emacs menus are part of the audit: Aquamacs modifies rather than replaces them. Preserve available upstream commands unless Glassmacs deliberately relocates or replaces them.

| Menu | Inherited or application-specific commands that must remain accounted for |
| --- | --- |
| **File** | Open Directory; Open Recent (up to 25 entries, basename labels); close, save/save-as; print/page setup; save/load session. Aquamacs removes Quit from File because macOS application-quit is handled separately. |
| **Search** | Incremental and nonincremental string/regexp search in either direction, repeat, replace, tagged-file search/replace, grep and Go To; Search Options cover literal/regexp, whole words/symbols and case/folding. `Cmd-F` starts forward incremental search, `Cmd-G` repeats it, and Use Region For Search is context-dependent. |
| **Options** | Customization and package management, saving options, UI visibility, display modes, line wrapping choices, smart spacing, backups and saved place. Aquamacs wrapping distinguishes Auto Fill (hard newlines), Word Wrap, edge wrapping, truncation and text-mode auto-detection; do not collapse these to one toggle. |
| **Buffers** | Live buffer/frame list and generated frame/tab commands. Aquamacs adds Join/Split Windows, Zoom, Full Screen, New Frame, Scatter/Tile, next/previous buffer or tab (`Cmd-{` / `Cmd-}`), detach/move tab, hide tab and merge frames. These Lisp additions are attached to the **Buffers** menu; the Lisp source does not establish the complete native Cocoa **Window** menu. |
| **Tools** | Inherited games, encryption/decryption, calculator/calendar, mail/news/web, version control/comparison, spelling, debugger, shell command, compile, grep and programming tools. Aquamacs adds Install Command Line Tools, removes Compose Mail from Tools and places spelling in Edit. Each optional tool retains upstream availability rules. |
| **Help** | Aquamacs manual, tips wiki, homepage, mailing list, donations, Emacs manuals, Lisp Intro/Reference, glossary, man page, installed package manuals, search across manuals and printable multilingual reference cards. Some GNU distribution/About/version entries are removed because About is owned by the application menu. |
| **Application / native Cocoa** | About and Preferences are native app events; application Quit dispatches save-buffers/exit, and reopen-application makes a frame visible. Aquamacs registers an update event. The exact native Cocoa menu presentation is not fully proven by Lisp menu definitions. |

**Dynamic evidence:** New Buffer in Mode / Change Buffer Mode combine known/common modes with a most-recently-used list capped at ten; unavailable mode functions are filtered, internal debugger/help/completion modes are excluded, and mode changes refresh the list. Major/minor-mode keymaps and packages such as ESS, AUCTeX and Org add context-specific menu items. The `:enable`, `:visible`, button state, active region, selected frame and keymap determine runtime appearance; static source inspection cannot prove every item is visible in the built GUI.

**Keyboard and clipboard evidence:** Aquamacs' `osxkeys` configures Command as the macOS shortcut modifier and Option as Meta by default; layout emulation adds optional character translations, while independent right Option/Command settings can preserve one side for text input. Its editing defaults enable CUA but disable automatic clipboard selection; clipboard wrappers temporarily enable system clipboard behavior. Thus Command clipboard operations and the ordinary kill ring are distinct. See the pinned [`osxkeys.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/macosx/osxkeys.el), [`emulate-mac-keyboard-mode.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/macosx/emulate-mac-keyboard-mode.el) and [`aquamacs-editing.el`](https://github.com/jmping/aquamacs-emacs/blob/5a2833896341ea02b65ef7ca145a2de3b5f82f30/aquamacs/src/site-lisp/aquamacs-editing.el).

This is a substantive command inventory, not a dump of every translated reference-card entry or every upstream Emacs menu item. For source-verified completeness, check the cited ranges and effective runtime maps; commented-out historical declarations are not enabled features. The compatibility matrix records implementation status and per-feature acceptance tests.

### Dynamic menu coverage

- **New Buffer in Mode / Change Buffer Mode:** Aquamacs builds these from `aquamacs-known-major-modes` and recently used modes; the MRU list is capped at ten, unavailable mode functions are filtered, debugger/help/completion modes are excluded, and mode changes refresh both menus (`aquamacs-menu.el` L55–225). Glassmacs may use `M-x` completion or a small dynamic menu; installed modes are discovered without eagerly installing/loading packages.
- **Buffers and tabs:** commands operate on the active Emacs buffer or explicitly selected tab/frame. `Next/Previous` labels and enablement follow the actual selected policy and available tabs. Move, hide, merge and close target a stable frame/tab/buffer identity, never a late-bound `selected-frame` after asynchronous work.
- **Open/Save/Close:** state follows the active document, local/remote identity and modified state. Distinguish closing a view/frame from killing a buffer; retain GNU Emacs save prompts. A repeated open of an already visited file focuses/reuses it unless an explicit second view is requested.
- **Research and mode menus:** `.R` may contribute existing ESS evaluation/session commands; `.Rmd`/`.qmd` render, preview and chunk actions require their relevant mode/tool; `.Rnw`/`.tex` use ESS/AUCTeX; Shiny actions require a recognized project and supported process. A plain text buffer does not get research-only commands. Remote actions require an explicit execution host/session. These are Glassmacs extension targets, not historical Aquamacs menu entries.
- **Toggles/radios:** opening policy is New Window (default), New Tab or Reuse Current; other examples include toolbar/tabs visibility, theme/zoom, line highlight, fringes, wrap and keyboard profile. On change, modify the authoritative setting, then refresh/read back state. Persist only through the setting's declared owner/scope.
- **Menu refresh:** Aquamacs attaches `aquamacs-update-menu` to `menu-bar-update-hook` and updates dynamic labels/state (L1300–1390). Glassmacs should use Emacs menu evaluation/update hooks and keymap lookup; do not rebuild a menu tree or perform process discovery on every redisplay.
- **Package/mode extensions:** retain commands contributed by active major/minor-mode maps and upstream packages. Avoid a static Glassmacs copy of every package menu; test representative ESS/AUCTeX/Org contributions and absence of optional packages.

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

1. **Linux batch ERT:** dispatches existing interactive commands; map lookup honors major/minor-mode precedence; dynamic mode list excludes unavailable/internal modes; capability predicates and menu construction have no process/network/project-code side effects; checked/radio state reads actual preferences; shortcuts match `key-binding`; settings round-trip; absent optional packages/executables disable or explain relevant actions.
2. **Linux batch ERT—documents:** mock file buffers, modified state, shared buffers and display functions to test close-document/close-buffer/close-frame distinctions, save/cancel behavior, duplicate opens and auxiliary-buffer routing. Do not claim native frame or Cocoa behavior from batch tests.
3. **Linux batch ERT—transitions:** test document-opening preference changes, tab/frame operation dispatch, stale/dead frame handling, persisted setting reload and fallback when graphical APIs are unavailable.
4. **macOS GUI only:** File > New/Open and Finder open events create separate frames by default; switch to tab/reuse modes; dirty Command-W/Command-Q prompts; detach/merge; full-screen/tile; app-menu placement; theme, toolbar and menu state; accessibility and keyboard navigation.
5. **macOS GUI only—keyboard/input:** exercise US and at least one non-US layout; left/right Option and Command independently; composed/dead keys, Option/Meta commands, shifted Command shortcuts, isearch and mode-local ESS bindings. Linux ERT can validate keymap declarations but cannot prove Cocoa event translation or composed-character input.
6. **Optional dependency tests:** use stubs/mocks in batch ERT for absent/present `Rscript`, Quarto, ESS, AUCTeX and remote process identity; opt-in real integration tests cover actual tools. Opening/updating a menu must never execute R, run a renderer or establish SSH.

Record each result with Emacs version, platform, profile, optional dependency state and test type. GUI-only checks are not Linux CI pass claims. No menu is “parity complete” without inspecting both its effective Emacs keymap and behavior in the target GUI.

## Extension points and non-goals

- Existing global, minor-mode and major-mode keymaps remain the command-discovery mechanism. Use standard menu-bar keymaps, `menu-item` properties and `easy-menu` where appropriate; preserve package maps and user overrides.
- Add a focused Glassmacs menu item through normal Emacs menu primitives only for a meaningful macOS policy or cross-package workflow. Keep command symbols as dispatch targets. Cocoa/Swift may host OS-standard menus/services but must call the same Emacs command or preference boundary.
- Do not add an independent command registry, generic declarative UI toolkit, menu serialization format, document database, duplicate keybinding engine, or Swift text renderer.
- Native extension is limited to a demonstrated platform gap (for example Finder/LaunchServices reopen); the Emacs command, buffer and preference remain authoritative.

**No menu should be marked parity complete** without inspecting its effective runtime keymap or GUI behavior. Historical code contains at least one questionable annotated File > Open shortcut (`Command-S`), which must not be copied uncritically. Use source references and record tested deviations in the compatibility inventory.
