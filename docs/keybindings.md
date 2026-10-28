# Keyboard profile

## Integrated 0.1 development status — 2026-10-27

PRs [#18](https://github.com/jmping/Glassmacs/pull/18), [#19](https://github.com/jmping/Glassmacs/pull/19), [#20](https://github.com/jmping/Glassmacs/pull/20), [#21](https://github.com/jmping/Glassmacs/pull/21), and [#22](https://github.com/jmping/Glassmacs/pull/22) have merged into `main` (most recently #22 at `604e44e`). Their PR CI succeeded (Emacs ERT, ESS/R integration, macOS launcher), **not** interactive Cocoa GUI acceptance.

Implemented: native Cocoa application/menu/window infrastructure; configurable document opening; New Buffer in Mode; ESS-based R menus and contextual toolbar actions; R sessions, explicit targeting, queue/output controls; Save As and modified-document review; keyboard, toolbar and document preferences. R Markdown, Quarto, Sweave, Shiny and remote workflows have partial integrations, not fully verified end-to-end behavior.

Outstanding: real macOS testing for reopening, document safety, keyboard/menu dispatch, R execution/session targets, native Quartz plotting, toolbar image/layout and preference persistence; release candidate signing/notarization, Gatekeeper and licensing/source obligations. **The next separate audit** will compare current menus against Aquamacs historical source, followed by historical issue triage; do not equate design inventory with demonstrated parity.

> **Document ID:** DOC-KEYS  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-28
> **Coverage:** Keyboard profile, implemented mappings and intended shortcuts  
> **Supersedes:** None


The configurable `glassmacs-keyboard-profile` supports
`glassmacs-hybrid` and `traditional-emacs`. The Hybrid profile is the default
on graphical macOS. It maps the Super key (normally Command) as follows:

| Shortcut | Command |
| --- | --- |
| Command-N | New untitled document (uses the document-opening policy) |
| Command-O | Open file |
| Command-S | Save |
| Command-Shift-S | Save As |
| Command-W | Close the document and its window (`glassmacs-close-document`; see below) |
| Command-Q | Quit Emacs |
| Command-C / V / X | Copy / paste / cut |
| Command-A | Select all |
| Command-Z | Undo |
| Command-F | Search |
| Command-Shift-G | Find previous (Command-G, find next, is GNU Emacs's own binding) |
| Command-Up / Command-Down | Beginning / end of the document |
| Command-Delete | Delete from the start of the line to the cursor |

The bindings are conditional on both macOS and a graphical frame. Terminal
Emacs and non-macOS sessions retain their normal global keymaps. Control,
Meta, and language-specific maps are not rewritten, preserving `C-x`, `C-c`,
`M-x`, and ESS evaluation shortcuts including `C-c C-c` and `C-c C-r`. Choose
**Glassmacs → Keyboard Profile → Traditional Emacs** to restore the bindings
that the Hybrid profile replaced and leave Command shortcuts unmapped by
Glassmacs. The selection is saved to Glassmacs `custom.el`.
`glassmacs-keyboard-profile` may also be set to `nil` to disable Glassmacs
keyboard mappings. Profile switching restores a previous binding only when
that key still has the Glassmacs Hybrid command, preserving later user
customizations.

GNU Emacs's Cocoa port already provides further Mac shortcuts that Glassmacs
leaves in place, including Command-Left/Right (line start/end), Command-G,
Command-L (go to line), Command-P (print), Command-+/- (text size), Command-`
(next window), Command-H and Command-M.

**Command-W closes the document**, as in other Mac applications (and
Aquamacs's `close-window`). If the window shows an ordinary document that no
other window shows, Glassmacs asks **Save / Don't Save / Cancel** when it has
unsaved changes, closes the document, and then closes the window, its tab
(when the frame has several) or its frame. R consoles, Help, Dired and other
special buffers are never killed, so closing a window never stops an R
session. The window close button behaves the same way for the documents shown
only in that window, and Cancel keeps it open. Closing the final window keeps
Glassmacs running. Command-Q exits the Emacs process.

### R Markdown, Quarto and Sweave documents

In these documents (prose and polymode chunk buffers alike) Glassmacs adds
RStudio-style shortcuts on Command, leaving ESS's `C-c` bindings alone:

| Shortcut | Command |
| --- | --- |
| Command-Shift-Return | Run the R chunk at point |
| Command-Option-P | Run chunks above point |
| Command-Option-R | Run all chunks |
| Command-Option-I | Insert an R chunk |
| Command-Option-Down / Up | Next / previous R chunk |
| Command-Option-K | Render (or run an interactive document) |

See [R workflows](r-workflows.md#mixed-prose-and-r-chunks).

This is a practical macOS mapping, not a claim of complete Aquamacs
compatibility. No Aquamacs source or preference behavior was imported.

## Compatibility audit and pending behavior

See the [proposed Aquamacs behavior inventory](aquamacs-compatibility.md) and [menu architecture](menu-architecture.md) for full parity coverage and menu command state. Interactive Command-O and Command-N now follow the configurable graphical document-opening policy, whose macOS default is a separate native Emacs frame. Actual Cocoa behavior remains unverified. Command-W dispatches the context-aware `glassmacs-close-document` command with Save / Don't Save / Cancel protection (implemented 2026-10-28; GUI unverified). Menu shortcut labels should reflect effective bindings, not copied Aquamacs annotation strings.

## Aquamacs-specific command and conflict audit

The current Glassmacs profile binds Command-N/O/S/Shift-S/W/Q/C/V/X/A/Z/F to `glassmacs-new-document`, `find-file`, `save-buffer`, `write-file`, `glassmacs-close-document`, `save-buffers-kill-emacs`, `kill-ring-save`, `yank`, `kill-region`, `mark-whole-buffer`, `undo`, and `isearch-forward`. Command-O applies the configurable interactive document-opening policy; Command-N creates an untitled document under the same policy. Command-W closes the document and its window (asking about unsaved changes) and preserves the app on final-frame close; Command-Shift-G, Command-Up/Down and Command-Delete were added on 2026-10-28; Command-Q follows Emacs's save-and-quit path. Dock reopen is bridged to Cocoa's native application-reopen callback in the packaged app, but requires signed-app GUI verification. This is a partial macOS convenience layer, not full Aquamacs compatibility. In particular:

- Command-W runs `glassmacs-close-document`: it kills only an ordinary document that no other window shows, after Save / Don't Save / Cancel, and never kills consoles or special buffers. Closing a window does not kill a buffer shown in another window or frame.
- `aquamacs-menu.el` constructs menu shortcut labels dynamically from effective bindings. One historical File > Open declaration appears to annotate Command-S; do not copy that text. Verify the command's effective keymap at runtime.
- Preserve `C-x`, `C-c`, `M-x`, and ESS commands such as `C-c C-c` and `C-c C-r`. Bindings installed globally must not displace a mode-local command with a stronger context-specific meaning.
- Command-Shift-S is the current `write-file` binding. Tests must verify shifted Cocoa key event normalization instead of assuming `[super-S]` behaves identically for every layout.

The following historical menu bindings are source-verified in `aquamacs3`'s `aquamacs-menu.el`, `osxkeys.el` and GNU menu-bar definitions; they are **not all implemented in Glassmacs**:

| Aquamacs shortcut | Historical operation | Glassmacs state / conflict |
| --- | --- | --- |
| Command-N / Command-T | New buffer in new frame / new tab | Not wired; Command-N and tab policy need explicit new-document semantics |
| Command-O / Command-S / Shift-Command-S | Open / Save / Save As | Present as Glassmacs Open/Save/Save As; historical menu annotations must not override effective maps |
| Command-W / Command-Q | Close Window / application Quit | Command-W closes document and window with save prompt (implemented); Command-Q exits Emacs; native app lifecycle needs GUI verification |
| Command-P | Print buffer or active region | Not wired; depends on print support and GUI validation |
| Command-F / Command-G / Shift-Command-G | Forward incremental search / repeat forward / repeat backward | Command-F (Glassmacs) and Command-G (GNU Emacs Cocoa default) are present; Shift-Command-G added 2026-10-28 |
| Command-X/C/V/A; Command-Z/Shift-Command-Z | Cut/Copy/Paste/Select All; Undo/Redo | Most operations are present; redo shortcut is not in the current profile. System clipboard and kill-ring behavior must remain distinct |
| Command-1 / Command-2 | Join windows / Split Window | Not wired; avoid stealing mode-local commands without GUI review |
| Control-Command-F | Full-screen editing | Not wired; graphical macOS only |
| Command-{ / Command-} | Previous/Next buffer or tab depending on tab mode | Not wired; labels and dispatch depend on effective tab state |
| Option-q / Option-Shift-q (Meta-q / Meta-Q) | Fill / Unfill | Emacs Meta semantics are preserved; Glassmacs does not add the Aquamacs unfill command |

The Options keyboard submenu also has toggles for Option-as-Meta, right Option-as-Meta and right Command-as-Meta, plus layout emulation maps. They are distinct from the Command shortcut profile and are not current Glassmacs features. Aquamacs' Option-as-Meta default can conflict with entering composed characters; preserving those characters and allowing independent left/right configuration is the proposed modern behavior. Source snapshot and menu ranges are linked from [menu architecture](menu-architecture.md).

## Option, international input, and right/left modifiers

Aquamacs' historical keyboard emulation offers layout-specific Option combinations for German, French, Spanish, Italian, Italian Pro, Finnish, Swiss German, Swiss French, US and British layouts. It also exposes Option-as-Meta versus system/composed-character input and independent right Option/right Command Meta toggles. Those maps are historical behavior, not a porting target: current macOS input sources and GNU Emacs Cocoa modifier variables should be preferred.

**Implemented (2026-10-28):** by default the left Option key is Meta (GNU Emacs's default) and the **right Option key types special characters** (é, ü, €, and @ on many non-US layouts), via `ns-right-alternate-modifier`. The `glassmacs-right-option-types-characters` option and **Glassmacs → Keyboard Profile → Right Option Types Special Characters** turn this off, making both Option keys Meta. Aquamacs's per-layout emulation maps are not implemented. The intended default remains that Option is available for composed characters and international text. Any future Meta mapping must be configurable independently for left/right Option and Command, disclose lost text-entry behavior, and persist in Glassmacs settings. Do not infer modifier intent from one machine's keyboard layout.

**Validation split:** batch ERT checks profile switching, saved prior bindings,
preserved Emacs prefixes, and menu state. It cannot validate Cocoa event
translation, dead keys, composed characters, right-side physical modifiers or
keyboard-layout behavior. The signed-app GUI test must cover both profiles on
US and at least one non-US layout, including Option text entry, Meta
sequences, isearch, mode-local ESS bindings, and effective shortcut labels.
