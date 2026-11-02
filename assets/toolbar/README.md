# Glassmacs toolbar PNGs

This directory contains **18 newly drawn, original Glassmacs icons** for the
Aquamacs-inspired document toolbar. They were created as simple 32 × 32 pixel
transparent RGBA line drawings, rather than copied or traced from Aquamacs
bitmaps. All files are valid PNG images.

The icons are: `new`, `open`, `save`, `saveas`, `print`, `undo`,
`redo`, `cut`, `copy`, `paste`, `search`, `preferences`, `close`,
`refresh`, `spellcheck`, `help`, `new-window`, and `history`.

## Provenance and reuse

Created specifically for Glassmacs on 2026-11-02 with procedural vector-like
drawing primitives rendered to PNG. No Aquamacs original PNG/TIFF images, icon
font, or third-party artwork were used as input. The icon shapes are generic
user-interface metaphors.

These assets are offered under **CC0-1.0** (public-domain dedication, where
legally effective), allowing later replacement and redistribution independently
of the upstream Aquamacs artwork. The Glassmacs application code retains its
own applicable software license.

The Aquamacs layout and command ordering are credited separately in
`docs/aquamacs-toolbar-asset-licensing.md`. See issue #57 for the restriction
on redistributing the original Aquamacs artwork.

## Integration

`lisp/glassmacs-aquamacs-toolbar.el` loads these PNGs from
`assets/toolbar/` and falls back to bundled GNU Emacs images if needed.
`scripts/build-macos-app` copies the directory to
`Glassmacs.app/Contents/Resources/Glassmacs/assets/toolbar/`.
