# Alpha 3 window-presentation audit and release gates

Status: implementation audit in progress for PR #84, tracking issue #83. This document distinguishes verified call sites from acceptance work that still requires packaged macOS execution.

## Core invariant

A Glassmacs primary document frame must not silently change its primary document because another buffer was opened, R started, Help appeared, a recovery ran, or the mode-line name was clicked. Explicit user actions to replace, move, split or tab are exceptions. Emacs buffers and process lifetimes remain independent of frame lifetimes. No global advice on `switch-to-buffer` or `display-buffer`.

## Inventory: actual entry points and required tests

| Entry point / seam | Current route on PR #84 | Risk / required acceptance |
| --- | --- | --- |
| File > Open, Cmd-O, C-x C-f | `glassmacs--open-file-with-policy`; interactive `glassmacs-find-file`; document presenter delegates to `glassmacs-present-buffer` | Open two modified .R documents; ensure distinct native frames, no source replacement, no duplicate frame when refocusing existing file. |
| Finder / Open With | `ns-find-file` around-advice in `glassmacs-frames.el` | Test actual Finder event both when application is cold and when a modified document is already open. Lisp tests cannot simulate Cocoa delivery. |
| New buffer / New Buffer in Mode | `glassmacs-frames.el` has separate new-buffer menu and creation paths | Confirm ordinary untitled buffers use the same stable primary-document policy; inspect direct `switch-to-buffer` paths before claiming full migration. |
| Mode-line buffer name | `glassmacs-focus-open-document` and mode-line mouse binding | Test mouse-1/mouse-3 in packaged app; preserve optional upstream Emacs behavior; verify no silent cycling. |
| Preferences / Customize | `glassmacs-open-preferences-group` creates or focuses a Customize frame | Verify source preservation, repeated opening and multi-group behavior; ensure no unintended reuse of an unrelated Customize frame. |
| ESS R startup | `glassmacs-r-start-session` in `glassmacs-sessions.el` | Verify startup never destroys existing splits; two independent R processes started from same source; focus and target remain unambiguous. |
| R console focus, move, switch | `glassmacs-r-new-console`, `glassmacs-r-switch-console`, existing console placement helpers | Check process identity survives move and closing a console frame; no accidental source replacement. |
| R Help | `glassmacs-r-install-help-display` and `glassmacs-r--display-help`; UI delegates to the single rule | Two distinct help topics, repeated same topic, reuse policy, side pane override, and no source replacement. |
| Recovery | `glassmacs-recovery-restore` collects restored buffers; interactive graphical restore presents frames | Test multiple dirty recovered buffers on an already populated desktop; preserve modified state and content. |
| Manual move/show/split/tab | `glassmacs-buffer-placement.el` and `glassmacs-present-buffer` dispatch | Verify move undo, inactive tabs, stale destination frames, duplicate views and non-destructive process handling. |
| Lifecycle / close | `macos/GlassmacsLifecycle.m`, `glassmacs-documents.el`, close tests | Native Cmd-W/Cmd-Q, cancel, Don't Save, multi-modified documents, R console frame and recovery. |
| Generic display and navigation | Direct `switch-to-buffer` / `pop-to-buffer` remain in frames, sessions and placement | Classify every remaining call site before declaring API consolidation complete; avoid intercepting package-internal ephemeral buffers. |

## Known direct-display call sites needing classification

On PR #84, `glassmacs-frames.el` still has direct `switch-to-buffer` paths in its central presenter (expected), file-open fallback, and new-buffer paths, as well as `pop-to-buffer` in a separate command. `glassmacs-buffer-placement.el` directly switches buffers during placement and undo (intentional internal adapter). `glassmacs-sessions.el` has direct console switches, `make-frame`, and several `display-buffer` paths. These are **not** automatically defects: inspect intent, originating window, and frame selection for each before migration.

The shared presenter currently accepts `open`, `focus`, `move`, `split`, `tab`, `replace`; it does not yet expose explicit buffer role classification. `focus` reuses a visible window, while other intents delegate to placement helpers. A future role classifier should distinguish document, untitled, console, help, preferences, review and transient buffers without inferring role from buffer name alone.

## Release-blocking acceptance

1. Add ERT tests for role/intent selection, already-visible reuse, stale frames, headless fallback, and modified-buffer preservation.
2. Add GUI acceptance records for Finder, Cmd-O, mode-line clicks, Customize, two R consoles, multiple R Help topics, recovery, manual placement, Cmd-W/Cmd-Q, and graphics.
3. Verify R source commands appear in both transcript and comint history; verify menu line-number preference, comment-aware R symbol extraction, and native close-button capitalization (issues #80 and #81).
4. Run Lisp ERT, Python tests, Swift tests, macOS build, packaged GUI acceptance, and release gates. Record pass/fail/skipped separately; skipped mandatory GUI scenarios must fail closed.
5. Report exact head SHA, outstanding risks and manual test steps. Keep PR #84 draft and do not publish Alpha 3 until explicitly authorized.

## Suggested packaged macOS manual script

Start from a clean profile, then repeat with existing preferences. Open two .R files, modify both, and open a third via Finder. Confirm frame identities and modified flags. Start two R consoles from one source, send alternating commands, inspect each console's history and target, then close one console window without killing the other process. Request two different R Help topics; open Preferences twice; click the mode-line buffer name; explicitly move one buffer into a tab and undo. Recover dirty buffers into a populated desktop. Exercise Cmd-W cancellation and Cmd-Q cancellation; verify all unsaved contents survive. Repeat with side-pane Help and legacy buffer cycling enabled. Record screenshots and any deviations against expected frame/window/process identities.
