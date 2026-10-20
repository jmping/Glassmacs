# Architecture

Glassmacs is a modular Emacs Lisp configuration for upstream GNU Emacs. It
does not fork Emacs, vendor upstream source, or port Aquamacs implementation
code.

## Modules

- `init.el` adds this checkout's `lisp/` directory and loads the Glassmacs
  entry point.
- `glassmacs-core.el` configures package.el under the isolated Glassmacs home
  and provides shell-free process execution and R string quoting.
- `glassmacs-keys.el` installs the optional macOS graphical Command-key profile.
- `glassmacs-r.el` integrates ESS, R source buffers, and evaluation commands.
- `glassmacs-documents.el` selects installed document modes and provides
  rendering/knitting commands.
- `glassmacs-shiny.el` starts and stops a local Shiny process.
- `glassmacs-appearance.el` defines built-in light and dark themes.

Package.el uses GNU ELPA, NonGNU ELPA, and MELPA. The bootstrap installs into
`GLASSMACS_HOME` (default `~/.config/glassmacs`), keeping package state apart
from a user's normal Emacs installation. Package versions are not pinned yet.
Optional packages and external executables are discovered at runtime; missing
rendering tools report a user-facing error.

## macOS integration boundary

GNU Emacs remains responsible for text editing, buffers, rendering, frames,
and Lisp extensions. A future lightweight Swift application may own app
launching/lifecycle, preferences, document integration, packaging/updates, and
optional preview coordination. It should communicate with Emacs through
documented process/URL or Emacs client interfaces rather than reimplementing
the editor or embedding an alternate text engine. No Swift scaffolding is part
of this milestone.

## Current limitations

This first slice does not provide a package lockfile or validate native Cocoa
behavior. Quarto, R Markdown, Sweave, and Shiny workflows require their
external tools/packages. The configuration is intentionally compatible with
batch and terminal Emacs; macOS Command shortcuts are only installed for
graphical frames on macOS.
