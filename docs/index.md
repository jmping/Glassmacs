# Documentation index and authority register

## Integrated 0.1 development status — 2026-10-27

PRs [#18](https://github.com/jmping/Glassmacs/pull/18), [#19](https://github.com/jmping/Glassmacs/pull/19), [#20](https://github.com/jmping/Glassmacs/pull/20), [#21](https://github.com/jmping/Glassmacs/pull/21), and [#22](https://github.com/jmping/Glassmacs/pull/22) have merged into `main` (most recently #22 at `604e44e`). Their PR CI succeeded (Emacs ERT, ESS/R integration, macOS launcher), **not** interactive Cocoa GUI acceptance.

Implemented: native Cocoa application/menu/window infrastructure; configurable document opening; New Buffer in Mode; ESS-based R menus and contextual toolbar actions; R sessions, explicit targeting, queue/output controls; Save As and modified-document review; keyboard, toolbar and document preferences. R Markdown, Quarto, Sweave, Shiny and remote workflows have partial integrations, not fully verified end-to-end behavior.

Outstanding: real macOS testing for reopening, document safety, keyboard/menu dispatch, R execution/session targets, native Quartz plotting, toolbar image/layout and preference persistence; release candidate signing/notarization, Gatekeeper and licensing/source obligations. **The next separate audit** will compare current menus against Aquamacs historical source, followed by historical issue triage; do not equate design inventory with demonstrated parity.

> **Document ID:** DOC-INDEX  
> **Status:** Canonical documentation governance  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-27
> **Coverage:** Documentation authority, status, ownership and navigation  
> **Supersedes:** None

This is the **canonical index** for maintained project documentation. If a document's authority or scope is unclear, this register governs. Architecture documents describe intended design, **not proof of implementation**; source code and verified tests establish actual behavior.

## Comparative audit (informational)

[Menu parity and deliberate differences](aquamacs-menu-parity-audit.md) and [historical Aquamacs issue regression candidates](aquamacs-historical-issues-audit.md) records the first source-oriented comparison of Aquamacs and Glassmacs, with gaps and GUI acceptance tasks. It does not replace the canonical behavioral inventory or menu architecture, and the historical issue audit remains a separate follow-up.

## Authority register

| Document | ID | Authority / status | Canonical coverage | Exclusions |
| --- | --- | --- | --- | --- |
| [README](../README.md) | DOC-README | Canonical for project identity | Vision, intended audience, high-level feature promises, getting started | Detailed design, delivery schedule |
| [Architecture](architecture.md) | DOC-ARCH | Canonical for target design | Invariants, boundaries, lifecycle/document abstractions, security, execution and integration contracts | Proof features are implemented, milestone status |
| [Aquamacs compatibility inventory](aquamacs-compatibility.md) | DOC-AQUA-COMPAT | Proposed, target for canonical after review | Source-traced feature matrix, dispositions, implementation status, priorities and acceptance tests | General execution architecture, menu taxonomy, proof of current implementation |
| [Menu architecture](menu-architecture.md) | DOC-MENU | Proposed, target for canonical after review | Historical menu inventory, proposed taxonomy, Emacs command dispatch, context/state, extensions and menu test strategy | Keyboard binding authority, per-feature parity status |
| [Roadmap](roadmap.md) | DOC-ROADMAP | Canonical for planned delivery | Milestones, priorities, acceptance criteria, dependencies | Actual implemented state without verification |
| [Development](development.md) | DOC-DEV | Canonical for contributor workflow | Build, tests, CI and verification procedures | Product vision, architecture decisions |
| [macOS application](macos-launcher.md) | DOC-MAC-LAUNCHER | Informational | Standalone Cocoa app build, installation, configuration, and GUI verification limits | Emacs/Lisp workflow authority, proof of GUI behavior |
| [R workflows](r-workflows.md) | DOC-R-WORKFLOWS | Canonical for documented user workflows | Available R/document commands and explicitly labeled proposed workflows | General architecture decisions |
| [Keybindings](keybindings.md) | DOC-KEYS | Canonical for keyboard profile | Implemented shortcuts, conflicts, Option/Meta and left/right international modifier behavior | General macOS architecture, feature parity status |
| [Documentation change register](documentation-changelog.md) | DOC-CHANGELOG | Canonical historical register | Changes to document scope, authority, status, ownership, splits, mergers and supersession | Complete code change history |
| [Documentation governance](documentation-governance.md) | DOC-GOV | Canonical policy | Metadata requirements, precedence, lifecycle, review and update procedure | Individual feature specifications |

The two proposed Aquamacs documents are review candidates on the documentation PR. Once accepted, update their status to Canonical and register their scopes as binding. The proposed inventory records a **new Mac graphical-window default** for ordinary new documents; architecture now records the required abstractions and the roadmap remains the delivery authority. These specifications are not proof of implementation.

If the same subject appears in several documents, the **canonical coverage column** determines authority. Other documents should summarize and link to it, not establish conflicting requirements. Proposed ADRs under `docs/adr/` become canonical for their *specific accepted decision* only after being marked Accepted and linked here; an accepted ADR supersedes inconsistent architecture prose until the architecture is reconciled.

## Status vocabulary

- **Canonical:** authoritative within its listed scope, regardless of whether features described are implemented.
- **Proposed:** draft for review; not binding until accepted/merged and registered.
- **Informational:** explanation, example or background; not authoritative.
- **Deprecated:** still accessible but should not guide new work.
- **Superseded:** replaced by a linked successor; retained only for historical context.
- **Archived:** historical record, no longer maintained.

**Implementation labels** are separate: *implemented and verified*, *implemented but unverified*, *partially implemented*, *planned*, or *not supported*. Never substitute document status for implementation status.

## Precedence and conflict handling

1. Actual repository code and reproducible tests establish **what currently works**; documents may describe intended behavior but must label it.
2. For intended product direction, the README owns identity, the architecture owns technical constraints, and the roadmap owns delivery priority.
3. Accepted ADRs control their narrowly defined decision; update architecture and the index promptly.
4. A conflict between two canonical documents is a documentation defect: open an issue/PR, identify the owner, and reconcile it. Do not silently choose the newer-looking file.
5. Git history is the exact source for line-by-line edits; the change register explains changes in **coverage and authority**, not every typo.

## Maintenance

See [documentation governance](documentation-governance.md) for the required PR checklist and [documentation change register](documentation-changelog.md) for dated scope changes. Dates use ISO 8601 `YYYY-MM-DD`; dates represent an editorial update, not automatic verification of technical claims.
