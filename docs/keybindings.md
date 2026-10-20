# Keyboard profile

> **Document ID:** DOC-KEYS  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-19  
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

See the [proposed Aquamacs behavior inventory](aquamacs-compatibility.md) and [menu architecture](menu-architecture.md) for additional commands and state. The planned graphical macOS **new-document default is a separate native Emacs frame**, with tabs and frame reuse opt-in; this does not change the current unverified prototype's behavior. Command-W currently deletes the selected frame; it must eventually dispatch a context-aware document close command with unsaved-buffer protection. Menu shortcut labels should reflect effective bindings, not copied Aquamacs annotation strings. Option/Meta and independent right Option/Command settings need international keyboard tests.
