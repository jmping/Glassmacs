# Documentation coverage and authority change register

> **Document ID:** DOC-CHANGELOG  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-19  
> **Last reviewed:** 2026-10-27
> **Coverage:** Dated history of documentation authority and coverage changes  
> **Supersedes:** None

## 2026-10-27 — integrated implementation and validation-state synchronization

- Updated README and roadmap to reflect merged PRs #18–22 and distinguish CI from physical macOS acceptance.
- Reconciled UI, macOS, ESS/R, architecture, development, keyboard and Aquamacs documentation with the merged implementation.
- Reserved source-level Aquamacs menu parity and historical issue comparisons for the next separate audit.
- No document authority or ownership changes.

---

## 2026-10-23 — 0.1.0 readiness and contextual toolbar priority

- **DOC-ROADMAP:** added a dated release-readiness snapshot distinguishing P0 release validation, P1 Aquamacs-style usability, and safely deferred enhancements.
- **DOC-README:** added a concise current project/release-status statement, including the draft PR #18 and verification limitations.
- **DOC-AQUA-COMPAT:** clarified that contextual mode-sensitive code-buffer toolbars, especially R/ESS, are a first-release P1 requirement rather than optional polish.
- No document authority, ownership, or supersession changes. No feature is declared implemented solely by these documentation updates.

---

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

## 2026-10-20 — Native compilation and signed macOS release pipeline

- **Updated DOC-MAC-LAUNCHER:** documented deployment-target propagation, native-code trust boundaries, signed bundled `.eln` loading with normal library validation, Developer ID signing, notarization, stapling, Gatekeeper, and final distribution archive.
- **Updated DOC-ARCH, DOC-DEV, DOC-ROADMAP and DOC-README:** distinguish portable build/mocked release validation from actual local signing/notarization and interactive macOS verification.
- No document status or authority changed; no signing credentials or generated app artifacts are documented or committed.

## 2026-10-20 — Standalone macOS app packaging

- **Replaced DOC-MAC-LAUNCHER coverage:** documents the one-bundle Cocoa Emacs architecture, pinned app build, install/bootstrap/configuration, runtime checks, and explicit GUI verification requirements; it no longer describes the superseded child-process launcher.
- **Updated DOC-ARCH and DOC-ROADMAP:** record the process-replacing bootstrap decision and mark package/build validation implemented while keeping Dock, LaunchServices, Finder, GUI, ESS/R, and Quartz checks unverified.
- **Updated DOC-README and DOC-INDEX:** distinguish the standalone macOS app from checkout-based terminal/development launch and register the updated application guide. No document was superseded.

## 2026-10-20 — Issue #12 R routing and macOS launcher prototype

- **Added DOC-MAC-LAUNCHER (Informational):** documented the former optional Swift/AppKit launcher, upstream GNU Emacs/Cocoa ownership boundary, server/client file handoff, build/configuration steps, and macOS verification limits; registered its scope in DOC-INDEX. The guide's current scope is recorded in the later standalone-app entry.
- **Updated DOC-R-WORKFLOWS:** documented per-buffer R targets, stale-session protection, editable per-console comint history, native Emacs context menus, and distinct source/project/session working directories.
- **Updated DOC-ARCH and DOC-ROADMAP:** distinguish the local R/session and unsigned launcher prototypes from unimplemented remote routing and unverified macOS GUI behavior. No existing document was superseded.

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

## 2026-10-19 — Integrated release and first-class remote-workflow planning

- **Expanded DOC-ROADMAP:** made the first integrated runnable Glassmacs release a near-term delivery gate, with independently implementable distribution/startup, remote-running terminal/headless Emacs, and native GUI TRAMP remote-buffer tracks, followed by real ESS/R and SSH integration validation.
- **Clarified three supported target modes:** local macOS GUI; macOS GUI editing first-class SSH/TRAMP remote buffers; and remote Linux/Unix terminal Emacs with server-local R. Editing location and execution location remain independent and explicit.
- **Added GUI remote-document acceptance:** native frame-default policy applies to ordinary remote files; host identity, nonblocking status, disconnected unsaved edits, save retry, external-modification conflicts and remote large-file safeguards require actual macOS/SSH tests.
- **Added terminal/headless acceptance:** single upstream GNU Emacs core without macOS/Cocoa requirements, optional daemon/client and tmux/Mosh workflows, and preserved ESS queue audit/confirmation semantics. Reconnection is not automatic command replay or durable-job proof.
- No document status, owner, precedence, or supersession changed. These are target requirements and planned verification work, **not newly implemented features**.

## 2026-10-19 — R graphics and plotting roadmap

- **Expanded DOC-ROADMAP:** introduced a dogfood-priority R graphics workstream: native macOS R graphics first, explicit X11/XQuartz fallback rather than a dependency, session-aware integrated plot history/viewing, and remote artifact-based plotting.
- **Clarified verification:** real ESS/R graphics tests and minimal maintainer dogfooding are distinct from mocks; no plot viewer or graphics-device integration is claimed as implemented.
- No authority, status, owner or supersession changes.

## 2026-10-19 — Multi-project routing, contextual UI and SSH deployment planning

- **Expanded DOC-ARCH:** specified ten-plus concurrent research projects, process-owned object/plot/queue views, independent per-buffer R execution target selection, terminal/process identity and distinct document/project/shell/R directory contexts. Added native right-click action contracts and local-code-testing/remote-deployment requirements.
- **Expanded DOC-ROADMAP:** added staged per-buffer session selection, context menus, session-scoped object explorer, explicit local-test/remote-deploy provenance and a longer-term graphical SSH file transfer/permission-management track.
- **Clarified safety:** no implicit cross-host path equivalence, execution retargeting, working-directory synchronization, queued-command migration, remote upload execution or destructive remote file/permission operations without appropriate explicit user actions and confirmation.
- These are architectural targets and planned delivery milestones, **not implemented functionality**. No document authority, status, ownership or supersession changed.
