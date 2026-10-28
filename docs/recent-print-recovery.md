# Recent Files, printing and unsaved-buffer recovery — implementation and GUI gates

This PR adds a persistent `recentf` history, Open Recent / Clear Recent / Preferences commands and a Print Document entry. It **does not** claim native Cocoa printing or a safe-close guarantee without GUI verification.

## Recent Files

- `recentf-mode` starts on load; `recentf` maintains the list across launches using its standard save file and `recentf-exclude` configuration.
- File → Open Recent… uses completion, checks for missing files and routes through Glassmacs's configured frame/tab policy.
- File → Clear Recent Files… requires confirmation and saves the empty list. File → Recent Files Preferences… exposes the upstream `recentf` group.
- A dynamic 25-entry Cocoa submenu is **not yet implemented**; the present menu opens a chooser. Verify exclusion rules, private paths, and clear persistence before adding that submenu.

## Print

- File → Print Document… delegates to `ns-print-buffer` if that function exists, otherwise to GNU Emacs `print-buffer`.
- **Do not interpret the fallback as native macOS Print or Save as PDF.** GNU `print-buffer` may use a configured external print spooler. The current app build must be inspected for `ns-print-buffer`, `ns-print-region`, `print-buffer`, `ps-print-buffer-with-faces`, and the actual File menu before choosing a native adapter.
- Acceptance: printing a local text/R source document presents a usable print destination and produces readable output; Save as PDF must be demonstrated in a macOS GUI before claimed. Cancel must not alter buffer or send a job. For R Markdown/Quarto, rendered PDF/HTML printing is a separate workflow.

## Unsaved document protection — design gate, not yet implemented

**User requirement:** closing a window containing new or modified text should never silently destroy the only copy. Ideally, unsaved contents should survive temporarily until the user decides to save/discard or a configurable retention period elapses.

Current implementation hides the final Cocoa frame and retains its buffers, so *closing the last window is not equivalent to discarding a buffer*. That alone is insufficient: closing another frame, killing a buffer, quitting, a crash, and restarting have different semantics. A save prompt on every close may conflict with the macOS convention that closing a window does not close its document, so the UX must explicitly decide whether to prompt, retain, or both.

**Proposed two-layer design:**

1. **Durable recovery snapshots:** configure Emacs auto-save for both visited and untitled modified buffers, without enabling `auto-save-visited-mode` (which silently overwrites the user's original document). Place recoverable snapshots in a Glassmacs-specific application-support location with restricted permissions, unique identities, and explicit metadata for original path, timestamp, modified state and source buffer. Use atomic writes and never replace an existing file with a snapshot. Offer a startup recovery view with Preview, Restore as Untitled, Save As, and Discard. Do not delete snapshots merely because a frame was closed.
2. **Close decision:** a consistent Save / Don't Save / Cancel decision for genuinely discarded modified documents, with Cancel preserving content and focus. Closing a frame that only hides or retains its buffers must not claim content was discarded. Distinguish closing last window, nonfinal window, buffer kill, Cmd-Q, and external shutdown. Treat ESS consoles, TRAMP files, password buffers and transient buffers separately; do not persist sensitive buffers by default.

**Retention:** configurable 7-day default *after the last modified snapshot*, with a size cap and periodic cleanup only for snapshots already superseded by a saved document or explicitly abandoned. Never silently expire the only known copy of an unsaved document; warn and require an explicit decision first. Encryption/privacy and file permissions require release review.

### Mandatory destructive-path matrix

| ID | Steps | Expected result |
| --- | --- | --- |
| SAFE-01 | Create untitled text, type, close only frame, Dock reopen | Text still present, not silently discarded; explicit save decision if a buffer is destroyed |
| SAFE-02 | Two frames, modify file in one, Cmd-W that frame | No loss; retained buffer or Save / Don't Save / Cancel decision |
| SAFE-03 | Modify saved R file, Cmd-W, cancel save | Original file unchanged; modified text recoverable |
| SAFE-04 | Untitled text, kill buffer | Save / Don't Save / Cancel, and recovery snapshot preserved if canceled or app crashes |
| SAFE-05 | Two dirty documents and ESS console, Cmd-Q | Every ordinary dirty document reviewed; console not treated as a file; cancel retains all |
| SAFE-06 | Modify file, wait past snapshot interval, force-kill app, relaunch | Recoverable last snapshot offered; original file unchanged |
| SAFE-07 | Save document normally, relaunch | No stale recovery offer for that saved version |
| SAFE-08 | Two untitled buffers with same display name, crash, recover | Distinct snapshots and content, no overwrite |
| SAFE-09 | Remote TRAMP file and ESS process buffers | No unexpected local sensitive-content snapshot; policy clearly stated |
| SAFE-10 | Cancel close, then Save As, then restart | Cancel and Save As retain contents; no duplicate or misleading recovery offer |

Record PASS/FAIL/BLOCKED for every case on the built macOS app, including exact commit, macOS version, architecture, and recovery file paths. **These tests are not yet passed and the snapshot subsystem is a design proposal, not shipped functionality.**

## Application Quit versus Close Window — explicit audit and design gate

**Question to verify:** Does the current bundled Glassmacs require all frames to be closed before Command-Q can complete? It must **not**. Inspect the native application Quit menu binding, `save-buffers-kill-emacs`, `kill-emacs-query-functions`, `kill-emacs-hook`, and the macOS lifecycle advice in `glassmacs-macos.el`. The hybrid profile currently binds Command-Q to `save-buffers-kill-emacs`, whereas closing the final Cocoa frame is intercepted and hides that frame; these are different code paths. A static binding is not proof of native GUI behavior.

### Proposed user-facing policy

- **Quit and Review Unsaved Documents (default):** Command-Q initiates one application-level quit, even with many open frames. Review all modified ordinary documents, allowing Save, Don't Save, or Cancel. Cancel aborts quitting without losing text or unexpectedly closing frames. Never require manually closing each window.
- **Quit and Preserve Open Buffers (opt-in preference):** Save a buffer-session manifest and recovery snapshots before exiting. Next launch reopens eligible document buffers and reconstructs their frame/tab layout, with unsaved edits recovered as unsaved content rather than silently written to original files. Provide a clear Restore Preserved Buffers / Start Fresh choice and a way to discard old state.
- **Restore scope:** local files, unsaved text buffers, window geometry, frame/tab assignments and selected document. Exclude transient/special buffers, secrets, and remote documents by default. An ESS/R process, console, running task or command queue must **never** be automatically restarted or replayed; offer explicit manual reconnect/restart instead.
- **Failure semantics:** if the buffer-session manifest or snapshots cannot be written durably, never claim the buffer session was preserved. Show the failure and allow Cancel Quit or proceed through explicit save/discard review. Use atomic writes, unique buffer identifiers, bounded retention and privacy-aware cleanup.
- **Consistency:** restore must be idempotent; repeated launches must not duplicate frames. Missing/moved files and display changes should degrade gracefully. Standard Cmd-Q, Dock Quit, menu Quit and system logout must be examined separately.

### Additional GUI acceptance matrix

| ID | Steps | Expected result |
| --- | --- | --- |
| QUIT-01 | Open three document frames, all saved; Command-Q | Application quits with one command; no prerequisite to close frames |
| QUIT-02 | Two modified files plus one untitled buffer; Command-Q, Cancel | Entire quit canceled; all text and original frames retained |
| QUIT-03 | Same setup; choose Save for one, Don't Save for another | Each decision honored; no silent data loss or repeated prompts |
| QUIT-04 | Enable Preserve Open Buffers, open multiple files and unsaved text, Quit | Durable manifest/snapshots created before exit; original files unchanged |
| QUIT-05 | Relaunch after QUIT-04 | Frames/documents restored once; unsaved content recovered; no duplicates |
| QUIT-06 | Workspace includes two ESS sessions and pending commands; Quit and restore | No R process auto-restart, no pending command replay; explicit user action required |
| QUIT-07 | Buffer-session save fails (unwritable directory/full disk) | Visible error; no false success; Cancel Quit remains available |
| QUIT-08 | Native Dock Quit, menu Quit, Cmd-Q and macOS logout | Correct safe-close policy on each supported exit path; report unsupported shutdown constraints |
| QUIT-09 | Restore after monitor removal, file moved, or missing path | Usable windows, clear missing-file notice, no duplicate frames or file overwrites |
| QUIT-10 | Quit after last frame was closed/hidden | Quit works without reopening or requiring manual window closure |

**Status:** These are requirements and unexecuted GUI tests. This PR does not yet implement a restore-workspace preference or guarantee safe quitting. A separate implementation and macOS GUI verification gate are required before claiming TextEdit-style restoration.

## Clarification: Preserve Open Buffers is not process/workspace restoration

The user-facing preference should be named **Preserve Open Buffers on Quit**, not Restore Open Documents and Windows or Restore Workspace. This is a document-state feature, **not** a terminal/process checkpoint or an attempt to recreate a previously executed R session.

- In this mode, Command-Q first writes durable snapshots for every eligible modified/untitled ordinary buffer and records references to saved files. On successful snapshot/manifest commit, quitting may proceed **without asking the user to Save or Don't Save each individual document**. Original files remain unchanged; recovered edits remain marked unsaved until the user explicitly saves them.
- If any eligible dirty buffer cannot be durably captured, do **not** silently quit or skip it: report the failure and offer Cancel Quit or the ordinary per-document save/discard review path.
- On relaunch, restore eligible file-backed and untitled *text/document buffers*, their content, names and unsaved status; optional document-window layout can be considered later. No promise to restore windows or frames is implied by the feature name.
- **Never restore ESS/R command windows, inferior-process buffers, shell/terminal buffers, REPLs, process state, execution history as a live session, pending command queues, or command-side effects.** Even if their text remains available in an archived log, that is not an executed session. The application must not auto-run commands or automatically reconnect a process.
- A separate **Safe Workspace** capability could eventually serialize opt-in command-window logs, session metadata, working directories, and reproducibility instructions, but process recreation and execution must remain explicit, independently designed and tested. It is **out of scope for this PR**.
- Recovery snapshots need clear privacy boundaries, permission checks, a way to inspect/discard preserved buffers, and a policy for stale snapshots that never silently deletes the only known copy of unsaved text.

### Revised acceptance tests

| ID | Steps | Expected result |
| --- | --- | --- |
| BUFFERS-01 | Enable Preserve Open Buffers, edit three files and create untitled text, Command-Q | One quit without individual save/discard prompts after all snapshots are durably committed; originals unchanged |
| BUFFERS-02 | Relaunch after BUFFERS-01 | Four document buffers restored with edits and unsaved state; no automatic file writes |
| BUFFERS-03 | Open R console and source buffer, execute commands, preserve buffers, relaunch | Source buffer restored; no live console/process, execution-state reconstruction, command replay or auto-reconnect |
| BUFFERS-04 | Make snapshot directory unwritable, edit untitled buffer, Command-Q | No unprotected silent quit; Cancel or explicit ordinary save/discard review |
| BUFFERS-05 | Quit, restore, quit again, restore | No duplicate buffers; preserved edits remain intact until explicitly saved or discarded |

These replace any implication in QUIT-04 through QUIT-06 that preserving document buffers requires restoring window layouts or R process state. All are **unimplemented acceptance criteria**, not claims about current Glassmacs behavior.

## Snapshot storage budget — PR #28 implementation gate

Large-file inspection must not silently generate unlimited copies of a document.
The initial implementation sets two configurable ceilings:

- **8 MiB per modified buffer** (`glassmacs-recovery-max-buffer-bytes`). Clean, file-backed documents are represented by their paths and do not need text snapshots.
- **256 MiB total recovery-directory storage** (`glassmacs-recovery-max-total-bytes`). This includes manifests and retained snapshot files. Periodic snapshots stop at the ceiling; explicit preservation fails closed rather than silently skipping a modified buffer.

These are *safety ceilings*, not a complete bounded-retention policy. Previously written immutable snapshots remain on disk, so storage stops growing when the ceiling is reached, but the application cannot keep taking new snapshots until space is reclaimed. Never automatically evict a snapshot that might be the only surviving copy of unsaved edits. A subsequent PR pass must add a reference-aware retention index, a user-visible storage inspector, and explicit review/discard controls before claiming automatic cleanup. Consider change detection/deduplication and a per-session quota so repeated idle snapshots of unchanged large buffers do not exhaust the quota.

**Acceptance:** Open a 1 GiB clean local file: no text snapshot should be written merely for viewing. Modify a file beyond the per-buffer limit: preserve-on-quit must cancel safely with the original content still open. Exhaust the global quota: same fail-closed behavior. Test UTF-8 multibyte sizes and filesystem errors.

### Reference-aware reclamation and deduplication (PR #28)

The recovery writer now reuses a snapshot when the buffer's content hash is unchanged **and** the snapshot is still referenced by a durable recovery index. This avoids repeated full-buffer copies during idle periods. Snapshots referenced by either the normal-quit manifest or crash index are protected from the explicit `M-x glassmacs-recovery-reclaim` operation. `M-x glassmacs-recovery-storage-status` reports usage and potentially reclaimable bytes.

**Important:** An unreferenced snapshot may still be the only surviving data after a failed manifest update or crash. Therefore reclamation is **manual, confirmation-gated**, not automatic. Treat reported reclaimable bytes as candidates for review, not proof that deletion is harmless. Until a transactional journal/retention protocol is implemented, there is no unconditional safe automatic eviction. The total storage ceiling remains a hard stop; preserve-on-quit must fail closed rather than exceed the budget or silently discard edits.

Validation must include repeated idle ticks without edits, changed edits producing new snapshots, both indexes protecting their referenced files, malformed indexes blocking reclamation, quota exhaustion, and forced termination between snapshot creation and index commit.
