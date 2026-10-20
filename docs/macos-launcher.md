# macOS Swift launcher

> **Document ID:** DOC-MAC-LAUNCHER  
> **Status:** Informational  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-20  
> **Last reviewed:** 2026-10-20  
> **Coverage:** Development build and operation of the optional AppKit launcher  
> **Supersedes:** None

## Architecture boundary

The optional `macos/` Swift package builds a small unsigned AppKit **launcher and
document-open helper**. It is not the Glassmacs editor application: the helper
does not own Emacs frames, text buffers, editing, R processes, or native Emacs
menus. It launches upstream Cocoa GNU Emacs as a separate process with this
checkout's `init.el`; Cocoa Emacs continues to own rendering, documents and
Emacs-native menu/context behavior. This avoids an in-process `NSApplication`
ownership conflict and avoids a second editor.

Finder/LaunchServices document-open events for `.R`, `.r`, `.Rmd`, `.qmd`, and
`.Rnw` are received by the helper. It starts Emacs with this checkout's `init.el`
using separate `Process` arguments, then sends file paths to the Emacs server
through `emacsclient --eval`. Paths are UTF-8/base64 encoded inside one
fixed-form Lisp expression; Lisp decodes them and calls
`glassmacs-open-files-from-client`, which uses Glassmacs' document-opening
policy. No filenames are interpolated into shell or Lisp source. Events received
while Emacs starts are retried against the server; a failed handoff is reported
and does not launch a second Emacs instance. The helper requests single-instance
LaunchServices behavior. It blocks its own Quit action while the Emacs child is
running; quit from Emacs so Emacs can preserve its normal save prompts. If the
helper is terminated externally, the Emacs child is not killed.
Reopening the helper activates its Emacs child when managed; an existing
server-only Emacs receives forwarded files without the helper taking over its
process lifecycle.

The Emacs server is enabled only when the helper launches Emacs, by setting
`GLASSMACS_LAUNCHER_SERVER=1`. It uses the isolated Glassmacs home and a local
authenticated Emacs server socket at
`$GLASSMACS_HOME/server-sockets/glassmacs`. The home-specific socket path
prevents collisions between different Glassmacs homes. The helper probes for
that compatible server before launching another Emacs, so subsequent helper
launches can forward files to an existing instance. Direct uses of
`scripts/glassmacs` do not start this server. The helper does not search for or
take over unrelated Emacs processes started without the Glassmacs server. If
the helper is killed externally, it does not monitor or terminate the Emacs
child.

The R right-click menu is implemented using Emacs Lisp mode maps and shared
interactive commands. No Swift bridge is needed for that behavior, and no
remote or R operation occurs merely to draw the menu. The native AppKit helper
does not replace Cocoa Emacs menus or register duplicate command state.

## Upstream integration audit

The GNU Emacs manual documents Cocoa-specific `ns-open-file` events and
Emacs-owned handling of Finder file-open requests; the Cocoa port implements
its own `NSApplication` subclass and accesses `NSApp` for native menu state.
This supports treating Emacs as the owner of its windows, menus and event loop,
not an in-process view controlled by the Swift launcher. The manual documents
`server-start`/`emacsclient` as the supported way to send file requests to an
existing Emacs server. It does not promise that a separate Swift app can adopt
the child Emacs `NSApplication`, register itself as a transparent Emacs
document bridge, or take over the child's unsaved-document lifecycle.

Emacs also provides `context-menu-mode` and buffer-local
`context-menu-functions`; Glassmacs uses that extension point rather than
building a parallel Swift context menu. These upstream capabilities motivated
the helper boundary above. They do not establish that LaunchServices will
register this unsigned app automatically or that Finder forwarding behaves
correctly without macOS testing.

References:

- [GNU Emacs manual: Emacs and macOS / GNUstep](https://www.gnu.org/software/emacs/manual/html_node/emacs/Mac-OS-_002f-GNUstep.html)
- [GNU Emacs manual: macOS / GNUstep events](https://www.gnu.org/software/emacs/manual/html_node/emacs/Mac-_002f-GNUstep-Events.html)
- [GNU Emacs manual: invoking `emacsclient`](https://www.gnu.org/software/emacs/manual/html_node/emacs/Invoking-emacsclient.html)
- [GNU Emacs manual: mouse clicks for menus](https://www.gnu.org/software/emacs/manual/html_node/emacs/Menu-Mouse-Clicks.html)
- [GNU Emacs Cocoa app class](https://github.com/emacs-mirror/emacs/blob/f6742561d0a9b0ee9e896aa1432d01b9251a9d0d/src/nsterm.h)
- [GNU Emacs Cocoa menu implementation](https://github.com/emacs-mirror/emacs/blob/f6742561d0a9b0ee9e896aa1432d01b9251a9d0d/src/nsmenu.m)

## Build and configure

Requirements: macOS 13 or newer, Swift 6 toolchain, and an upstream graphical
Cocoa Emacs build. Xcode is not required for ordinary Glassmacs Lisp/terminal
use.

```sh
swift test --package-path macos
./scripts/build-macos-app "$HOME/Applications/Glassmacs.app"
```

The app is unsigned and intended for local development. Open it once to configure
the Emacs executable and checkout in its Preferences status menu. Optional
fields select `GLASSMACS_HOME` and `emacsclient`. Values are stored in this
launcher app's user defaults and contain paths only; Emacs Lisp and Custom
remain authoritative for Glassmacs editor preferences.

Environment values override launcher preferences:

- `GLASSMACS_EMACS`: executable path for upstream Cocoa Emacs.
- `GLASSMACS_ROOT`: Glassmacs checkout containing `init.el`.
- `GLASSMACS_HOME`: isolated Glassmacs configuration/package directory.
- `GLASSMACS_EMACSCLIENT`: optional `emacsclient` path or command name.

The launcher starts Emacs with `-Q --load <checkout>/init.el`, then uses the
authenticated server handoff for Finder files. The file arguments are encoded
as data and passed through a `Process` argument array, not shell command
strings; spaces, quotes, newlines, Unicode and shell metacharacters remain
ordinary filename characters. Use absolute paths in Preferences or environment
settings. The normal `scripts/glassmacs` command remains available independently.

For remote or unusual macOS launch environments where `emacsclient` is not on
the inherited `PATH`, configure its absolute path in Preferences or with
`GLASSMACS_EMACSCLIENT`. File events arriving while Emacs is starting are
forwarded with retries; failure remains visible and does not fall back to a
second Emacs process.

## Verification and boundaries

The Swift package tests argument construction on Linux and macOS. The
`macos-launcher` CI job compiles the package and checks basic `.app` bundle
structure on a macOS runner; this is **compile/package validation only**, not a
Finder, LaunchServices, Cocoa GUI, native R graphics or interactive ESS test.
No macOS host was available for this change, so app activation, Finder Open With,
multiple open events, process shutdown, unsaved-document prompts, menus and
mouse history behavior remain unverified in a real GUI.

Manual macOS dogfood:

1. Build the app, configure the Cocoa Emacs executable and checkout, then launch
   it and verify Emacs starts with this checkout.
2. Use Finder Open With for two R files and confirm they reach the same Emacs
   instance; verify an open file with spaces in its name.
3. Use an ESS console to recall/edit multiline history, run `plot(cars)`, select
   a different R target and verify the modeline and queue.
4. Quit from Emacs with an unsaved buffer and confirm Emacs' save prompt appears;
   verify the helper status menu does not terminate Emacs.

Known limits: the helper is not signed/notarized, has no automatic installation
or default-handler setup, and does not provide a drag-and-drop window. Finder
document events require the app to be registered by LaunchServices. It does not
find or take over unrelated Emacs processes that were started without the
Glassmacs launcher server. GUI delivery must be validated on macOS; Linux
package tests cannot establish it.
