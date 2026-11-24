# Glassmacs Alpha stabilization and acceptance gate

This is the executable acceptance plan for PR #77. PR #76 supplies the
document/console lifecycle safeguards and nonblocking per-session R queue.
**CI success is not equivalent to a human-tested packaged macOS application.**
Record actual observations and failures, not inferred successes.

## Release candidate prerequisites

- [ ] Build the relocatable `Glassmacs.app` from the PR #77 commit and record the
  commit SHA, macOS version, CPU architecture, Emacs and ESS versions.
- [ ] Run `./scripts/test`, macOS launcher validation, and automated packaged
  GUI acceptance. Save job links and artifacts.
- [ ] Install or unpack on a clean Mac/user profile; verify first launch,
  offline startup with installed dependencies, optional-package failure modes,
  and reopening after a full quit.
- [ ] Run `M-x glassmacs-self-check` and record findings.
- [ ] Complete `docs/macos-acceptance-checklist.md`; update
  `acceptance/matrix.toml` only for scenarios actually exercised.
  Regenerate `docs/acceptance-matrix.md` through its documented script.

## P0: Cocoa document and process lifecycle (manual, packaged GUI)

- [ ] Open two distinct files and a new untitled document; verify separate
  macOS windows by default, existing-file reuse, and tab/reuse preferences
  after restart.
- [ ] Edit two dirty documents; cancel the second close decision and verify
  neither document is lost or silently marked clean. Repeat with Save and
  Don't Save, save failure, scratch, and two views of the same buffer.
- [ ] Test Command-W, native red close button, final visible frame close,
  Dock Quit, Command-Q, and reopening after hiding the final frame.
- [ ] With an active R console and pending commands, close its frame: cancel
  must keep the view; Hide must not terminate R or discard queued commands.
- [ ] Exercise quit preservation enabled and disabled; restore unsaved file
  and untitled content after normal quit and forced process termination.
  Test a deliberately unwritable recovery directory; a failed snapshot
  must block unsafe quit rather than claim success.

## P0: Interactive R/ESS and responsiveness

- [ ] Verify line, region, paragraph, function, and buffer submission target
  the intended session and execute in FIFO order. Check two simultaneous
  sessions, explicit targets, and stale-session rejection.
- [ ] Queue at least 100 small commands while a long-running R command is
  active; measure editor keystroke latency and record max/median latency,
  command ordering, and UI responsiveness.
- [ ] Produce sustained output well beyond the configured per-command output
  budget and console scrollback limit. Verify editor remains usable,
  suppression marker appears, output is bounded, and the R process survives.
- [ ] Interrupt a running command with pending work; verify pause, uncertainty
  marking, no automatic replay, explicit resume, removal and clear confirmation.
- [ ] Exercise ESS Help placement (separate graphical frame, right/bottom
  pane), repeat Help requests, and verify the edited source stays visible.
- [ ] Create a base R plot and a ggplot2 plot when installed; inspect
  navigation, focus and graphics-window lifecycle. Record device limitations.

## P1: Desktop and interoperability

- [ ] Finder open/reopen, Dock activation, menu actions, hybrid shortcuts,
  contextual toolbar and preferences persistence.
- [ ] Mixed text/R/R Markdown/Quarto buffers; missing optional dependencies
  must fail gracefully. Document unverified Sweave/Shiny features.
- [ ] Local GUI editing of a TRAMP/SSH file and explicit local/remote ESS
  session targeting where an opt-in SSH test host is available.
- [ ] Terminal `-nw` and batch startup regression, including headless
  confirmation and no GUI-only dependency failures.

## Evidence and decision

For every item, record **PASS / FAIL / NOT RUN**, exact build SHA, test host,
reproduction steps, and evidence location. A failed P0 is an Alpha blocker.
An unexecuted manual P0 is **NOT RUN**, not a pass. Triage failures into this
PR or a follow-up blocker with owner and reproduction steps.

**Alpha exit:** green CI on the candidate commit, no known P0 data-loss or
blocking UI defects, recorded clean-machine GUI and R acceptance, explicit
limitations, and an installable unsigned development build. Signing and
notarization are a separate public-distribution gate; do not claim them
for an unsigned Alpha.
