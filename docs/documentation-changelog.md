# Documentation coverage and authority change register

> **Document ID:** DOC-CHANGELOG  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-20
> **Coverage:** Dated history of documentation authority and coverage changes  
> **Supersedes:** None

This log records changes in document **scope, ownership, status and authority**. It is not a substitute for Git history or a complete changelog of prose edits.

## 2026-10-19 — Documentation governance baseline (PR #2)

- **Created DOC-INDEX:** central canonical authority and scope register; previously no explicit precedence map existed.
- **Created DOC-GOV:** metadata, status, change-control and review policy.
- **Created DOC-CHANGELOG:** dated record of documentation coverage changes.
- **Registered DOC-README, DOC-ARCH, DOC-ROADMAP, DOC-DEV, DOC-R-WORKFLOWS and DOC-KEYS:** assigned canonical coverage and accountable maintainer group.
- **Expanded DOC-ARCH coverage:** execution/SSH/Mosh, output flooding, editable R execution queue, plain-text and large-file safety, LaTeX/PDF, AI agents, research application profiles and polyglot research-user positioning. These are target requirements, not claims of implementation.
- **Established DOC-ROADMAP as delivery authority:** milestone and acceptance-criteria planning separated from architectural requirements and current feature documentation.
- **Clarified DOC-R-WORKFLOWS:** existing commands versus planned research workflows must be explicitly distinguished.
- **Precedence:** the README controls vision; architecture controls target technical design; roadmap controls delivery planning; code/tests control actual implemented behavior. No documents superseded in this baseline.

Future entries should state date, affected document IDs, old/new coverage or authority, rationale, successor (if any), and associated PR/ADR.

## 2026-10-19 — Proposed Aquamacs feature, settings and menu audit (documentation PR)

- **Added DOC-AQUA-COMPAT (Proposed):** source-traced historical feature inventory, intended replacement strategy, settings taxonomy, implementation priorities and acceptance criteria. Establishes separate graphical windows as the intended default for new documents, with tabs/reuse optional and special buffers exempted by policy.
- **Added DOC-MENU (Proposed):** first dedicated menu command/capability and dynamic-state specification spanning application, file, editing, display, keyboard, tools/research, window and help menus.
- **Updated DOC-INDEX:** registered proposed documents and explicit scope boundaries. These are not implemented features; review/merge establishes canonical authority.
- **Linked DOC-ARCH, DOC-KEYS and DOC-ROADMAP:** preserved execution/ESS/research and governance coverage while pointing to detailed proposals. No document superseded; no functional code touched.

## 2026-10-20 — Aquamacs parity and menu architecture audit expanded

- **Expanded DOC-AQUA-COMPAT:** converted the initial topic summary into a stable-ID matrix with source ranges, user-visible behavior, GNU Emacs equivalents, explicit dispositions, checkout status, priority and acceptance tests. Marked implementation gaps and modern macOS/GNU Emacs departures; documentation is not proof of implementation.
- **Expanded DOC-MENU:** recorded source-verified File, Edit, Search/Go To, Options, Buffers, Tools, Help, application, toolbar and dynamic mode/package commands. Distinguished Aquamacs' Lisp Buffers additions from native Cocoa Window content. Added side-effect-free context/capability, checked/radio/shortcut, extension and Linux ERT versus macOS GUI contracts.
- **Expanded DOC-ARCH and DOC-KEYS:** specified lifecycle/document/buffer/window/tab/frame/session/command/context/capability/appearance/preference/platform/research boundaries; documented existing Command bindings, conflicts, Option input, international layouts and left/right modifier gaps.
- **Updated DOC-INDEX:** narrowed canonical coverage and cross-references; compatibility and menu documents remain Proposed pending review. The architecture and existing execution, SSH, ESS, LaTeX, Shiny and research boundaries remain authoritative for their existing scopes.
- **No code changes:** this audit specifies future engineering and acceptance criteria; it does not implement frames, menus, settings persistence, native services or keyboard behavior.

## 2026-10-20 — ESS session registry and minimal R queue (implementation PR)

- **Updated DOC-R-WORKFLOWS:** the minimal queue and session registry are now documented as implemented (`lisp/glassmacs-sessions.el`); editing, reordering, a queue buffer, output budgets, persistence and remote sessions remain planned.
- **Updated DOC-ROADMAP:** Milestone 2 queue track records what is delivered and what is deferred. Pending-command removal now always requires confirmation; this tightens the earlier "delete work not yet sent" wording.
- No documents superseded. Dependencies on menu, keybinding and preference architecture are documented, not implemented.
