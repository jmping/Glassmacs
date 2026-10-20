# Keyboard profile

> **Document ID:** DOC-KEYS  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-20
> **Coverage:** Keyboard profile, implemented mappings and intended shortcuts  
> **Supersedes:** None


The configurable `glassmacs-keyboard-profile` currently supports
`glassmacs-hybrid`. On graphical macOS frames, the Super key (normally
Command) is mapped as follows:

| Shortcut | Command |
| --- | --- |
| Command-O | Open file |
| Command-S | Save |
| Command-Shift-S | Save As |
| Command-W | Close the current frame |
| Command-Q | Quit Emacs |
| Command-C / V / X | Copy / paste / cut |
| Command-A | Select all |
| Command-Z | Undo |
| Command-F | Search |

The bindings are conditional on both macOS and a graphical frame. Terminal
Emacs and non-macOS sessions retain their normal global keymaps. Control,
Meta, and language-specific maps are not rewritten, preserving `C-x`, `C-c`,
`M-x`, and ESS evaluation shortcuts including `C-c C-c` and `C-c C-r`.
Set `glassmacs-keyboard-profile` to `nil` in the Glassmacs `custom.el` file to
disable this profile.

This is a practical macOS mapping, not a claim of complete Aquamacs
compatibility. In particular, Command-W deletes the current Emacs frame (not
an independent native document window), and Command-Q exits the Emacs process.
No Aquamacs source or preference behavior was imported.

## Compatibility audit and pending behavior

See the [proposed Aquamacs behavior inventory](aquamacs-compatibility.md) and [menu architecture](menu-architecture.md) for full parity coverage and menu command state. The planned graphical macOS **new-document default is a separate native Emacs frame**, with tabs and frame reuse opt-in; this does not change the current unverified prototype's behavior. Command-W currently deletes the selected frame; it must eventually dispatch a context-aware document close command with unsaved-buffer protection. Menu shortcut labels should reflect effective bindings, not copied Aquamacs annotation strings.

## Aquamacs-specific command and conflict audit

The current Glassmacs profile binds Command-O/S/Shift-S/W/Q/C/V/X/A/Z/F to `find-file`, `save-buffer`, `write-file`, `delete-frame`, `save-buffers-kill-emacs`, `kill-ring-save`, `yank`, `kill-region`, `mark-whole-buffer`, `undo`, and `isearch-forward`. This is a partial macOS convenience layer, not full Aquamacs compatibility. In particular:

- Command-W currently deletes the selected frame. Target behavior is a context-aware close-document/view command with GNU Emacs' unsaved-buffer protection. Closing a frame must not kill a buffer shown in another frame.
- Command-Q currently exits Emacs through the normal save-buffers prompt; it is not proof of a native app remains-open/reopen lifecycle.
- `aquamacs-menu.el` constructs menu shortcut labels dynamically from effective bindings. One historical File > Open declaration appears to annotate Command-S; do not copy that text. Verify the command's effective keymap at runtime.
- Preserve `C-x`, `C-c`, `M-x`, and ESS commands such as `C-c C-c` and `C-c C-r`. Bindings installed globally must not displace a mode-local command with a stronger context-specific meaning.
- Command-Shift-S is the current `write-file` binding. Tests must verify shifted Cocoa key event normalization instead of assuming `[super-S]` behaves identically for every layout.

The following historical menu bindings are source-verified in `aquamacs3`'s `aquamacs-menu.el`, `osxkeys.el` and GNU menu-bar definitions; they are **not all implemented in Glassmacs**:

| Aquamacs shortcut | Historical operation | Glassmacs state / conflict |
| --- | --- | --- |
| Command-N / Command-T | New buffer in new frame / new tab | Not wired; Command-N and tab policy need explicit new-document semantics |
| Command-O / Command-S / Shift-Command-S | Open / Save / Save As | Present as Glassmacs Open/Save/Save As; historical menu annotations must not override effective maps |
| Command-W / Command-Q | Close Window / application Quit | Glassmacs currently deletes frame / exits Emacs; close and native app lifecycle policies are gaps |
| Command-P | Print buffer or active region | Not wired; depends on print support and GUI validation |
| Command-F / Command-G | Forward incremental search / repeat forward search | Command-F is present; Command-G is not currently mapped |
| Command-X/C/V/A; Command-Z/Shift-Command-Z | Cut/Copy/Paste/Select All; Undo/Redo | Most operations are present; redo shortcut is not in the current profile. System clipboard and kill-ring behavior must remain distinct |
| Command-1 / Command-2 | Join windows / Split Window | Not wired; avoid stealing mode-local commands without GUI review |
| Control-Command-F | Full-screen editing | Not wired; graphical macOS only |
| Command-{ / Command-} | Previous/Next buffer or tab depending on tab mode | Not wired; labels and dispatch depend on effective tab state |
| Option-q / Option-Shift-q (Meta-q / Meta-Q) | Fill / Unfill | Emacs Meta semantics are preserved; Glassmacs does not add the Aquamacs unfill command |

The Options keyboard submenu also has toggles for Option-as-Meta, right Option-as-Meta and right Command-as-Meta, plus layout emulation maps. They are distinct from the Command shortcut profile and are not current Glassmacs features. Aquamacs' Option-as-Meta default can conflict with entering composed characters; preserving those characters and allowing independent left/right configuration is the proposed modern behavior. Source snapshot and menu ranges are linked from [menu architecture](menu-architecture.md).

## Option, international input, and right/left modifiers

Aquamacs' historical keyboard emulation offers layout-specific Option combinations for German, French, Spanish, Italian, Italian Pro, Finnish, Swiss German, Swiss French, US and British layouts. It also exposes Option-as-Meta versus system/composed-character input and independent right Option/right Command Meta toggles. Those maps are historical behavior, not a porting target: current macOS input sources and GNU Emacs Cocoa modifier variables should be preferred.

Glassmacs does not currently implement Option/Meta or independent left/right modifier preferences. The intended default is that Option remains available for composed characters and international text. Any future Meta mapping must be configurable independently for left/right Option and Command, disclose lost text-entry behavior, and persist in Glassmacs settings. Do not infer modifier intent from one machine's keyboard layout.

**Validation split:** Linux batch ERT can check keymap declarations, preserved Emacs/ESS bindings, profile enablement and shortcut lookup. It cannot validate Cocoa event translation, dead keys, composed characters, right-side physical modifiers or keyboard-layout behavior. Those require macOS GUI testing on US and at least one non-US layout, covering both sides of Option/Command, Option text entry, Meta sequences, isearch and mode-local ESS bindings.
