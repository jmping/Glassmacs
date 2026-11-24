# Glassmacs validation build: tester checklist

This is experimental software, not a production release. Back up your work
and keep an existing editor available. Run these checks on files and R data
you can afford to replace. Record **Pass**, **Fail**, or **Not tested** for
each item; include reproduction steps for failures.

1. Download the DMG and checksum from the release, compare SHA-256, copy
   Glassmacs to Applications, and launch it from Finder. Record any
   Gatekeeper warning. Use a clean Mac or account where possible.
2. Open a file through Finder; close the last window and reopen from the
   Dock. Create a new document and type, edit, save, close and reopen it.
3. Exercise native menus and shortcuts, including Command-W and Command-Q.
   With a modified document, test Save, Don't Save and Cancel.
4. Open multiple documents and windows; switch between them and confirm
   document-opening preferences and window focus.
5. Install R separately. Open two ESS R sessions and verify that each source
   document sends commands to the correct console. Test queue controls.
6. Open R Help and run `plot(cars)`; confirm the source document is preserved
   and native graphics display.
7. Install and load a small Emacs package. Note any network or permission
   errors and do not install untrusted code.
8. Check native compilation and cache loading only within Glassmacs's
   configured security policy. Automatic native JIT and user-writable native
   caches are intentionally disabled; record this as the expected policy, not
   as a compilation success. Do not disable hardened runtime to test it.
9. Save session state, quit and relaunch. Check restored documents and
   windows; live R processes are not restored. Test crash recovery with
   expendable, modified files and verify which document/tab is selected.

## Recording and sharing

Download `collect-validation-report` from the same release, inspect it, and
run it in Terminal (replace the app path if installed elsewhere):

```sh
bash collect-validation-report /Applications/Glassmacs.app > acceptance-report.md
```

The report records macOS, shell architecture and app bundle versions and
provides editable result fields. Enter the release tag and DMG SHA-256 from
the release; a legacy candidate may display Emacs's `31.1` bundle version
instead of the Glassmacs release tag. The shell architecture may reflect
Rosetta, so note whether the Mac itself is Intel or Apple Silicon.

Optionally run `M-x glassmacs-diagnostics` inside Glassmacs and save the
displayed buffer with `M-x write-file`. Review both reports before attaching
them to a GitHub issue: the diagnostics buffer includes your Glassmacs home
path, and your notes, logs or screenshots may contain personal information.
Nothing is uploaded automatically.
