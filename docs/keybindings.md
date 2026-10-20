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
