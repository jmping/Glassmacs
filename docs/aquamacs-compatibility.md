# Aquamacs behavioral compatibility inventory

> **Document ID:** DOC-AQUA-COMPAT  
> **Status:** Proposed  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-19  
> **Coverage:** Source-traced Aquamacs behavior, required Glassmacs replacements, defaults, acceptance contracts, and parity tracking  
> **Supersedes:** None

This is the proposed authoritative **behavioral inventory** for Glassmacs after review/merge. The [architecture](architecture.md) controls technical invariants; [menu architecture](menu-architecture.md) controls presentation/command mapping; [keybindings](keybindings.md) controls effective bindings; [roadmap](roadmap.md) controls delivery sequence. Source inspection does not imply implementation or verified behavior.

## Product decision: documents open in new macOS windows by default

**GLASSMACS-DOC-001 — REQUIRED P1.** For ordinary user-initiated opening or creation of a *new document*, prefer a **new native GNU Emacs graphical frame (macOS window)**, not a new tab or replacement of the current document. This is an intentional Glassmacs default, even though Aquamacs 3 source configures tabbar on by default on Mac. The default applies to Finder/LaunchServices open events, File > Open, Command-O, File > New, Command-N, and ordinary new-document commands in graphical macOS mode, subject to explicit context and reuse rules. Keep the existing Emacs frame alive after the last document closes when suitable for macOS application semantics.

**Never globally force every Emacs buffer into a new frame.** ESS inferior R, *Help*, *Messages*, *Completions*, compilation, minibuffer, diagnostics, Dired and other transient/utility buffers must use intentional display policies that keep interaction usable. An already visible file should normally focus/reuse its document window rather than create duplicate views; explicit Open in New Window creates an additional view. A new file opened from within remote/TRAMP or project context must preserve that context. Avoid creating frames during startup/headless operation, batch rendering, or background process callbacks.

**User choices:** `glassmacs-document-opening-policy` (proposed custom variable): `new-frame` (default on graphical macOS), `new-tab`, `reuse-current`, with separate explicit commands for Open in New Window/Tab. `glassmacs-special-buffer-display-policy` is a separate concern; do not conflate documents and auxiliary buffers. On terminal/non-macOS Emacs, preserve ordinary upstream behavior unless explicitly opted in. Use built-in Emacs `display-buffer-alist`, frame APIs, and tab primitives before implementing compatibility logic. Do not assume `tab-bar-mode` and `tab-line-mode` have the same model as Aquamacs tabbar.

**Required tests:** opening A.R then B.R under the default results in distinct graphical frames; the default does not silently replace A or add B as a tab; the Tab policy uses the same frame; `*Help*` and an ESS console do not each spawn unwanted standalone document frames; reopening an already open file reuses/focuses its view unless explicitly overridden; Command-W prompts for unsaved changes and closes the intended document without quitting or killing unrelated buffers; Command-Q handles all dirty buffers; GUI-only behavior tested on actual macOS, not asserted from Linux ERT. Record precise definitions of tab/buffer/frame/window so tests are unambiguous.

## Source-of-truth inventory and status vocabulary

Historical source: [jmping/aquamacs-emacs, `aquamacs3`](https://github.com/jmping/aquamacs-emacs/tree/aquamacs3/aquamacs/src/site-lisp). Relevant files:

- [one-buffer-one-frame.el](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/one-buffer-one-frame.el): frame reuse, exceptions, closing, special buffers, app remains open
- [aquamacs-menu.el](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/macosx/aquamacs-menu.el): dynamic menus, action predicates, enabled/checked state, shortcuts
- [aquamacs.el](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/aquamacs.el): application setup, tabs, display, preferences, scratch, restoration
- [aquamacs-editing.el](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/aquamacs-editing.el): clipboard, selection, wrapping, fill/unfill, scrolling
- [aquamacs-tool-bar.el](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/aquamacs-tool-bar.el): customizable toolbar
- [osx_defaults.el](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/macosx/osx_defaults.el): Mac defaults, Finder and preferences, environment, autosaves
- [emulate-mac-keyboard-mode.el](https://github.com/jmping/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/macosx/emulate-mac-keyboard-mode.el): Option/Command/Meta, international keyboard profiles

Status for all features below is **planned/not parity-verified** unless an existing Glassmacs module and specific passing test are linked; prototype presence does not establish Aquamacs parity. Disposition abbreviations: **U** configure maintained upstream Emacs/packages; **G** focused Glassmacs Lisp policy; **N** possible optional native macOS/Swift bridge; **O** intentionally omit only with explicit accepted decision. P1 means core compatibility; P2 means subsequent refinement. Each feature must eventually record implemented/tested versions, evidence, and intentional deviations.

## Capability matrix

| ID | Aquamacs user-visible feature / behavior | Source | Glassmacs solution | Priority | Acceptance focus |
| --- | --- | --- | --- | --- | --- |
| DOC-001 | New document in independent Mac window | one-buffer-one-frame.el; aquamacs-menu.el | U+G; **new-frame default**; user tab/reuse override | P1 | Two opened files in two frames |
| DOC-002 | New tab, buffer tabs, switch tabs | aquamacs-tabbar; aquamacs-menu.el | U+G opt-in tab policy | P1 | Tab creation/navigation consistent |
| DOC-003 | Show Buffers in New Frames preference | one-buffer-one-frame.el; menu | G document/aux-buffer policy separation | P1 | Toggle and persist settings |
| DOC-004 | Close window, close tab, kill buffer independently | one-buffer-one-frame.el | G explicit semantics, save prompts | P1 | No accidental data loss |
| DOC-005 | Detach tab to frame, hide tab, merge frames | menu window extras; tabbar | U+G commands, capability checks | P1 | No lost buffers or duplicate identities |
| DOC-006 | Join/split, zoom, full screen, tile/scatter | menu window extras | U+G; N only when needed | P1/P2 | Correct frame/window targeting |
| DOC-007 | Special buffers stay appropriately colocated | one-buffer-one-frame.el regexp policies | U+G `display-buffer-alist` policies | P1 | ESS/Help/Completions don't proliferate frames |
| DOC-008 | Smart frame placement, last-frame behavior | smart-frame-positioning; one-buffer-one-frame | U+G, Mac lifecycle optional N | P1 | Windows visible and non-overlapping; app survives |
| DOC-009 | Save, restore, name sessions, resume layouts | revive; aquamacs.el | U+G desktop/tab/session persistence | P1 | Restore files/tabs/layout, never fake R process resurrection |
| DOC-010 | Untitled buffer/scratch content persistence | aquamacs.el | G explicit autosave/recovery and discard confirmation | P1 | Recover non-file content after restart |
| FILE-001 | New Buffer in Mode, Change Buffer Mode, recent modes | aquamacs-menu.el 55–225 | U+G dynamic chooser | P1 | Modes discoverable; absent modes disabled |
| FILE-002 | Open, Save, Save As, Reveal in Finder, recent files | aquamacs-menu.el 230–530; osx_defaults | U+G; N for Finder if necessary | P1 | Recent files and file associations correct |
| FILE-003 | File/document open from Finder, drag/drop, reopen | osx_defaults; mac-extra-functions | U+G, N for LaunchServices packaging | P1 | Native open events follow window policy |
| FILE-004 | Print, Page Setup, export, copy formatted/PDF | aquamacs-menu.el 297–310, 535–610 | U+G; N for native print/clipboard types | P2 | Printer/PDF and styled copy verified on macOS |
| EDIT-001 | Copy/cut/paste with Emacs kill ring | aquamacs-editing.el; menu | U+G; native selection bridge as needed | P1 | Clipboard interoperability both directions |
| EDIT-002 | Undo/redo, select all, forward/back search | aquamacs-menu.el 290–375 | U+G; existing keys prioritized | P1 | Effective commands and menu shortcuts match |
| EDIT-003 | Fill/unfill, wrapping, smart spacing | aquamacs-editing.el; menu 458–477, 620–765 | U+G separate visual/hard wrapping | P1 | Preserves code and prose formatting |
| EDIT-004 | Count words, spelling and correction | menu 946–1030 | U; N for native checker optional | P2 | Buffer/region counts and language context |
| VIEW-001 | Per-mode face/font presets (Auto Faces) | aquamacs-autoface-mode; aquamacs.el | U+G per-mode profiles and theme-safe overrides | P1 | R monospace; prose suitable typography |
| VIEW-002 | Font zoom, color themes, mode line and cursor | aquamacs.el; menu | U+G, native light/dark profile | P1 | Light/dark transition and zoom persist |
| VIEW-003 | Toolbar customization and show/hide UI | aquamacs-tool-bar.el; menu | U+G; N only for deeper native UI | P2 | Enabled/checked/visible state stays consistent |
| VIEW-004 | Tabs, fringes, line highlight, newlines, parenthesis | menu 775–885 | U+G toggles and persistent prefs | P1 | Toggled state reflects real Emacs state |
| PREF-001 | Save Options, customize, defaults and persistence | aquamacs.el 423–545, 1428–1490; osx_defaults | U+G isolated preferences | P1 | Restart retains changed policy; no user config overwrite |
| PREF-002 | Backup/autosave/recovery placement | osx_defaults.el 320–360; aquamacs.el | U+G isolated safe storage | P1 | Recover after simulated crash; no collisions |
| PREF-003 | Startup/user configuration precedence and migration | aquamacs.el; osx_defaults | G opt-in non-evaluating migration assistant | P2 | Never execute arbitrary legacy .el; user approval |
| PREF-004 | Word-wrap, theme, font, tab/frame, toolbar and recent-file settings | aquamacs.el 1428–1490; menus | G typed preferences with clear scope | P1 | Settings persist and UI state updates immediately |
| KEY-001 | Hybrid macOS shortcuts alongside Ctrl/Meta/ESS | osxkeys; menu | U+G existing `glassmacs-keys.el` | P1 | Explicit conflict tests and real macOS GUI |
| KEY-002 | Option composed characters and right-hand modifiers | emulate-mac-keyboard-mode.el | U+G per-layout modifier profile | P1 | International input remains possible |
| KEY-003 | Mode-dependent menu shortcut display | aquamacs-menu.el update-hook | U+G compute effective binding | P1 | Menu labels follow keymap/profile changes |
| MAC-001 | Application menus, Quit, reopen/unhide, updates | menu; osx_defaults | U+G; N for packaging/platform hooks | P1/P2 | Application lifecycle is macOS-correct |
| MAC-002 | Path/environment setup and CLI tool installation | osx_defaults; menu 398–454 | U+G, optional N | P1/P2 | CLI, PATH and app launch coexist |
| MAC-003 | Help/manual/reference cards and bug reporting | menu 1035–1156, 1385–1520 | U+G, optional N help book | P2 | Offline manuals and relevant references available |
| MAC-004 | Scroll behavior, natural Mac navigation, mouse selection | aquamacs.el; aquamacs-editing.el | U+G, test native GUI | P1 | Page scroll/selection follows explicit profile |
| LANG-001 | Mode associations, bundled packages, syntax and help | mode-preloads.el; site-lisp/edit-modes | U actively maintained packages | P1 | Plain text and non-R modes start without R |
| LANG-002 | ESS and R; JAGS/SAS/Stata/Julia integrations | edit-modes/ess-mode; mode-preloads.el | U modern ESS + research profiles | P1/P2 | Existing editing/execution semantics; no stale vendor copy |
| RESEARCH-001 | R Markdown, Quarto, Sweave, Shiny, LaTeX and remote jobs | Glassmacs architecture extension | U+G shared execution with ESS ownership | P1/P2 | Context-aware render/run/preview; explicit host |

## Settings inventory and priority

Aquamacs source persists user-facing variables including `one-buffer-one-frame-mode`, `tabbar-mode`, `aquamacs-autoface-mode`, `visual-line-mode`, `global-hl-line-mode`, `show-paren-mode`, `global-show-newlines-mode`, `global-flyspell-mode`, toolbar size/display/customization, left/right modifier assignments, fontsets, scroll bars, fringes, word-wrap/auto-fill, `make-backup-files`, `case-fold-search`, language/input-method settings, and printing preferences (see `aquamacs.el` around lines 1428–1490). These are **historical settings**, not proposed direct implementation APIs.

Glassmacs settings categories and ownership:

1. **Documents and windows (highest priority):** `new-frame` default on Mac GUI, `new-tab`, `reuse-current`, explicit same-document focus/reuse, utility buffer placement; configure from Settings and View/Window menus. File > New and File > Open honor the preference consistently.
2. **Appearance:** light/dark, font family and size by major-mode family, cursor, toolbar, fringe, line number/highlight, parenthesis and newline display, zoom, tab visibility.
3. **Editing:** soft wrap versus hard fill, smart spacing, selection/clipboard, scrolling, undo and search behavior.
4. **Keyboard:** Command/Control/Option/Meta, right-side modifier, international layouts, app versus Emacs shortcuts.
5. **Files and safety:** autosave, backups, scratch recovery, recent files, remote volume availability, encoding, default new document mode.
6. **Sessions:** session save/restore and startup restoration choice; distinguish document restoration from R/SSH reconnection.
7. **Research:** ESS session selection, execution backend/host, project profiles, Shiny preview, R Markdown/Quarto/LaTeX render options.
8. **Application:** start/reopen/quit behavior, CLI integration, help, updates, printing and accessibility.

All settings need stable identifiers, types, safe defaults, scope (global/project/buffer/frame), persistence owner, setter/readback, and migration rules. Avoid two sources of truth between Emacs Lisp customization and future SwiftUI; Swift must query/mutate the supported preference interface rather than cache an independently authoritative value. Maintain an isolated `GLASSMACS_HOME`. Prefer ordinary Emacs custom variables for Lisp-first settings, with a documented adapter if Swift is added.

## Acceptance and verification strategy

- **ERT (cross-platform):** command selection/predicates, settings defaults, serialization, mode associations, utility-buffer classification, toggle metadata, keymaps, no-op behavior when optional tools absent, no global side effects outside isolated launcher.
- **macOS Cocoa GUI integration:** independent new frames as **default**, alternative tabs and reuse, Finder open/drop, close/quit dirty prompts, toolbar, theme switching, Option input methods, accessibility and menu state.
- **Real research integration:** ESS source/console routing, R Markdown/Quarto/LaTeX render logs, Shiny lifecycle; remote execution selection and detached jobs must not silently initiate upon opening documents.
- **Manual parity exercises:** compare equivalent Aquamacs 3 workflows to Glassmacs; record historical vs intentional modernized behavior and screenshots where meaningful.
- **Regression:** default window opening and special-buffer display must be tested together; changing menu settings must update subsequent open behavior, and persisted setting survives restart.

### Known discrepancies requiring deliberate decisions

- Aquamacs 3 `aquamacs.el` sets `tabbar-mode` default on macOS; Glassmacs **intentionally defaults to independent frames for new documents at user request**. Independent frames are not synonymous with indiscriminately enabling `one-buffer-one-frame-mode` for every internal Emacs buffer.
- Aquamacs historical File > Open declaration contains an apparent Command-S shortcut annotation; verify effective bindings before copying.
- `Command-W` in the current Glassmacs prototype invokes frame deletion; that is **not yet** a complete document close/dirty-state policy.
- Aquamacs legacy `revive`, tabbar and customized Cocoa integration are references for behavior, not code to vendor.
- Program execution/session restore and local-versus-remote document identity are different problems; do not merge their safety policies.

## Implementation order

P1a: **new-window default and document/utility display policies**, stable close/save semantics, settings persistence, ERT + macOS GUI tests. P1b: mode/menu command inventory, binding state, tabs/frame operations and working preferences menu. P1c: clipboard, per-mode typography, session restoration, international modifiers and Finder open. P2: formatting exports, native printing/spellcheck, deep toolbar customization, legacy settings import, application help and updates.

Before declaring completeness, attach for every row an implementation link, failing/passing test evidence, and a decision rationale. Any intentional omission must be documented and reviewed. No feature above is declared finished by the existence of this document.
