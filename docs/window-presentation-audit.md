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


## November 2026 follow-up: two native-presentation development slices

The window campaign is deliberately stacked on draft research integration PR #112,
not merged independently to `main`. Cycle 1 adds a read-only role-to-policy
lookup and terminal-safe effective placement to the presentation model. It
protects the bootstrap path from replacing an existing source when a native
document frame was explicitly requested. No global `display-buffer` or
`switch-to-buffer` advice is introduced.

Cycle 2 routes explicitly requested research jobs dashboard and retained log
views through a single conservative auxiliary-display adapter. Its native
frame default applies only to graphical macOS, and an explicit preference
restores standard Emacs placement. Existing suitable frames can be reused;
source buffers, ESS sessions and research processes are not changed. The
adapter never opens completed output, connects to SSH or starts/replays a job.

### CI and packaged GUI acceptance

- Run complete exact-head CI for both stacked commits, including ERT, real
  ESS/R integration and the macOS launcher build. A newly opened PR has
  **no** assumed passing status until the actual run is inspected.
- On packaged native Cocoa Glassmacs: open two modified documents, request
  the research dashboard twice, inspect a retained log, then return to the
  source documents; verify identities, no replacement and no unexpected
  duplicate native frame. Repeat with standard Emacs display preference.
- Repeat with two independent R consoles, two distinct R help topics,
  new tab and terminal fallback. Verify closing only the dashboard/log view
  does not kill R or a research job.
- Keep all physical GUI, trusted SSH, Intel, clean-machine and
  corresponding-source checks explicitly NOT RUN until separately evidenced.
  No DMG publication is authorized by these slices.

## November 25 follow-up: exact console and R Help identity

Window cycles 3 and 4 extend the presentation stack with explicit identity-preserving navigation:

- R console navigation lists registered live sessions by immutable session ID; switching a console view does not change an R source document's execution target. A separate *Focus Linked R Console* source action refuses a stale explicit target rather than silently switching sessions. Starting another console remains an explicit operation.
- R Help navigation reuses the view showing the exact requested Help buffer, focuses that frame when graphical, and creates distinct views for different topics rather than replacing an unrelated document. Side-pane overrides remain opt-in, and terminal presentation falls back to Emacs display.
- CI tests include same-name session ambiguity, stale targets, preserving source targets when switching console views, repeated Help topics, distinct Help topics, and terminal fallback. A preexisting console-chooser test was updated to use the new exact-selection interface.

These slices remain stacked on #128 and draft #112. Full exact-head CI validation of the descendant stack is necessary before consolidation. Packaged Cocoa GUI (including Finder, closing only a console frame, and multiple simultaneous Help topics) is NOT RUN; no automatic process restart, remote SSH operation, main merge, or DMG publication is authorized.
