# Aquamacs toolbar provenance and licensing decision

**Tracked in:** [Glassmacs issue #57](https://github.com/jmping/Glassmacs/issues/57)

## Key source documents

- Original Aquamacs toolbar implementation: [`aquamacs/src/site-lisp/aquamacs-tool-bar.el`](https://github.com/aquamacs-emacs/aquamacs-emacs/blob/aquamacs3/aquamacs/src/site-lisp/aquamacs-tool-bar.el), branch `aquamacs3`. Copyright (C) 2005–2013 David Reitter; **GPL-3.0-or-later** notice.
- **Artwork-specific license**: [`aquamacs/Icons/build/COPYING`](https://github.com/aquamacs-emacs/aquamacs-emacs/blob/aquamacs3/aquamacs/Icons/build/COPYING), same branch. This overrides any inference that every PNG in the GPL software tree can be freely redistributed in other applications.
- [Aquamacs icon directory](https://github.com/aquamacs-emacs/aquamacs-emacs/tree/aquamacs3/aquamacs/Icons) — individual upstream PNGs and build resources.

## Licensing findings

Upstream explicitly states that **all icons other than the identified Nuovext icons were licensed to the Aquamacs project**, and **may not necessarily be redistributed separately or in another application**. Therefore Glassmacs cannot assume a wholesale right to copy them.

| Upstream artwork | Stated attribution / grant | Glassmacs disposition |
| --- | --- | --- |
| `new_window`, `tab_new`, `view_bottom` | Nuovext project, GPL version 2 | May be reusable with notice and careful license-version / source verification; *not yet imported*. |
| `history` | David Vignoni, LGPL | Potentially reusable if the exact source, version and requirements are confirmed; *not yet imported*. |
| `update`, altered TeX preview, `bibtex` | MySite Myway, described as “free license” | Terms insufficiently specific; do not import. |
| `preferences`, `circle_stop`, `pdftex`, `tex` | Jasper Hauser, all rights reserved | Do not import without permission. |
| Other toolbar icons (New/Open/Save/Print/Undo/Cut/Copy/Paste/Search/etc.) | Adrian Chromenko / David Reitter, all rights reserved; licensed to Aquamacs project | Do not import without permission or independent clearance. |
| `LucidaGrande.ttf` | Font file, not toolbar art | Do not import; separate font licensing concerns. |

**The GPL status of the Aquamacs application does not grant blanket permission to redistribute these specific icons.** Reusing the independently licensed toolbar *source layout and command ordering* is a different question from copying the images themselves.

## Glassmacs implementation

PR [#58](https://github.com/jmping/Glassmacs/pull/58) implements the familiar general-toolbar button order using Glassmacs/GNU Emacs commands. The artwork uses *only icon assets distributed with GNU Emacs* (subject to existing Emacs distribution compliance). It is configured as the default on graphical frames; ESS/R source and console toolbars remain contextual.

The general toolbar includes New, Open, Recent, Close, Revert, Save/Save As, Print, Undo/Redo, Cut/Copy/Paste, Search, Spelling, Duplicate, Preferences and Help. Button visuals can be replaced without changing command dispatch.

## Release gates

1. Obtain explicit permission or independently verify appropriate licensing for any Aquamacs artwork before adding it to the Glassmacs repository or app bundle.
2. Preserve copyright, license versions, source references and attribution for any later-imported artwork.
3. Do not imply Aquamacs affiliation or copy Aquamacs logos/wordmarks without a separate branding decision.
4. Verify actual Cocoa toolbar rendering, image resolution, application packaging, context-dependent controls and CI/ERT before merging the implementation. This provenance document is **not legal clearance**.

Aquamacs maintainer outreach is planned at beta stage; no permission is assumed before that.
