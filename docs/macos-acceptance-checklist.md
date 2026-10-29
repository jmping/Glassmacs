# macOS manual acceptance checklist

> **Document ID:** DOC-MAC-CHECKLIST  
> **Status:** Canonical  
> **Owner:** Glassmacs maintainers  
> **Effective date:** 2026-10-29  
> **Last reviewed:** 2026-10-29  
> **Coverage:** Layer D checks that need a person, a physical Mac or a clean machine  
> **Supersedes:** None

<!-- Generated from acceptance/matrix.toml by scripts/acceptance-matrix render; edit the matrix, not this file. -->


Run these on the build being released, not on an earlier one. Record each result as a dated line in the `clean_machine` field of the check in `acceptance/matrix.toml` (for example `2026-11-02 pass, macOS 15.1 arm64, build 1a2b3c4`), then run `scripts/acceptance-matrix render`. Until then every check here is **NOT RUN**.

Before starting: install the app in /Applications on the Mac under test, and run `M-x glassmacs-self-check` there; it should report no FAIL lines.

## DIST-001

**Bundled native libraries resolve inside the app** (P0). Result: **NOT RUN**

- [ ] On a Mac without Homebrew, Nix or Xcode, launch the app and open an .R file; Console.app shows no dyld errors.

## DIST-002

**Apple Silicon and Intel architectures** (P0). Result: **NOT RUN**

- [ ] Launch the same build on an Intel Mac and on Apple Silicon without Rosetta; open, edit and save a file on each.

## DIST-005

**Builds with the supported Xcode and macOS versions** (P0). Result: **NOT RUN**

- [ ] Build with scripts/build-macos-app on the newest macOS and Xcode release (Tahoe) and on macOS 13 with its Xcode; record versions.

## LAUNCH-001

**Packaged app launches from LaunchServices in a clean home** (P0). Result: **NOT RUN**

- [ ] On a fresh user account, copy the app to /Applications, open it from Finder, and confirm one Dock icon and one window.

## LIFE-001

**Closing the last window keeps the app running; the Dock reopens it** (P0). Result: **NOT RUN**

- [ ] Click the red close button of the last window: Glassmacs stays in the Dock and menu bar.
- [ ] Click the Dock icon: the window returns, with no new buffers.

## LIFE-002

**Menus and shortcuts work with no window open** (P0). Result: **NOT RUN**

- [ ] With every window closed, choose File > New Document from the menu bar and press Command-N: each opens a visible Untitled document.

## FINDER-001

**Opening a file from Finder with no window shows it** (P0). Result: **NOT RUN**

- [ ] Close all windows, then double-click an .R file in Finder whose default app is Glassmacs: it appears in a visible window.

## CLIENT-001

**emacsclient and server opens use the right window** (P2). Result: **NOT RUN**

- [ ] Only if you enable server-start: run the bundled emacsclient -n FILE and confirm the file opens in a visible Glassmacs window.

## MENU-002

**Menu presentation: shortcuts, About and Preferences items** (P1). Result: **NOT RUN**

- [ ] Open each menu: shortcuts shown match what the keys do (Command-N, Command-W, Command-S).
- [ ] Glassmacs > About and Glassmacs > Settings… open the right windows.

## MODE-001

**Mode menus with ESS, polymode and TRAMP do not break** (P2). Result: **NOT RUN**

- [ ] Open a remote file over SSH (TRAMP) and open each menu while it is current.

## PREF-003

**Safe local variables and upgrades keep the user's choices** (P1). Result: **NOT RUN**

- [ ] Replace the installed app with a newer build: preferences, recent files and workspace remain.
- [ ] Go back to the older build with the newer home: it starts and keeps editing working.

## SPELL-002

**Interactive spelling suggestions** (P1). Result: **NOT RUN**

- [ ] With hunspell or enchant installed, run M-x ispell-word on a misspelling: a menu of suggestions appears and choosing one replaces only that word.

## SPELL-003

**Native spelling never corrects or substitutes** (P0). Result: **NOT RUN**

- [ ] With enchant using AppleSpell and macOS text replacements enabled (System Settings > Keyboard > Text Replacements), type a replacement shortcut, "quotes" and -- in an .R file and a .Rmd file: nothing changes.

## NATIVE-001

**Bundled native code loads without a compiler; no user cache** (P1). Result: **NOT RUN**

- [ ] On a Mac without Xcode command-line tools, launch the app and install the optional packages: no compiler prompt appears and packages work.

## DIALOG-001

**Open and recent-file dialogs do not hang** (P1). Result: **NOT RUN**

- [ ] Choose File > Open… from the menu ten times in a row, cancelling and choosing files alternately: the panel always appears and Glassmacs stays responsive.
- [ ] Open a file from File > Open Recent while another app changes it.

## FULL-001

**Closing full-screen windows** (P1). Result: **NOT RUN**

- [ ] Make a window full screen with the green button, press Command-W on a saved document, then reopen from the Dock.
- [ ] Repeat with two windows, one full screen.

## CLOSE-002

**Quitting with unsaved documents asks first** (P0). Result: **NOT RUN**

- [ ] With an unsaved document, choose Quit from the Dock icon's menu and log out of macOS: both ask before quitting.

## RESTORE-001

**Workspace restore reopens files once and starts no processes** (P1). Result: **NOT RUN**

- [ ] With restore on, quit from the Dock menu with two windows; relaunch: both return once.
- [ ] Disconnect an external display, relaunch: windows open on the remaining display.

## TEXT-001

**Typed text stays literal in code, consoles and mixed documents** (P0). Result: **NOT RUN**

- [ ] With macOS 'Use smart quotes and dashes' and text replacements on, type "quotes", -- and a replacement shortcut into an .R file, an R console and a .Rmd chunk: text stays as typed.

## KEY-001

**International keyboards, input methods and Option keys** (P1). Result: **NOT RUN**

- [ ] With German and French layouts, type @, {, [ and é with Option; with Japanese or Chinese input, compose and commit text in a document and the minibuffer.

## ASSOC-002

**Documents open by type through LaunchServices** (P1). Result: **NOT RUN**

- [ ] Choose Glassmacs as the default app for .R and .Rmd in Finder's Get Info, then double-click files of both types.

## MIX-GUI-001

**Mixed documents in the app: document menu and Command shortcuts** (P1). Result: **NOT RUN**

- [ ] With R, ESS and poly-R installed, open an .Rmd, press Command-Shift-Return in a chunk and Command-Option-K: the chunk runs in the R console and the rendered HTML opens in the browser.

## MIX-002

**Rendering and Shiny previews open their output** (P1). Result: **NOT RUN**

- [ ] Render an .Rmd and an .Rnw: the HTML opens in the default browser and the PDF in Skim or Preview.
- [ ] Run a Shiny app: the browser opens on the app once it is ready.

## R-001

**ESS, R and Quarto run from the app** (P1). Result: **NOT RUN**

- [ ] With CRAN R installed, start R from the R menu, evaluate plot(cars): a Quartz window shows the plot and editing focus returns to the document.

## SYNC-001

**Skim SyncTeX forward and inverse search** (P2). Result: **NOT RUN**

- [ ] With MacTeX and Skim, compile a .tex file, press C-c C-v: Skim shows the line; Command-Shift-click in Skim: Glassmacs shows the source line.

## DISPLAY-001

**Multiple displays, Spaces, Stage Manager and scaling** (P2). Result: **NOT RUN**

- [ ] Move a window between a Retina and a non-Retina display, between Spaces, and in and out of Stage Manager: text stays sharp and the window keeps focus.

## APPEAR-001

**Light and dark appearance changes** (P2). Result: **NOT RUN**

- [ ] Switch System Settings > Appearance between Light and Dark while Glassmacs runs: windows stay readable (following the change is not yet implemented).

## SEC-001

**Developer ID signing, notarization and Gatekeeper** (P0). Result: **NOT RUN**

- [ ] Sign and notarize with scripts/sign-macos-app and scripts/notarize-macos-app; on another Mac, download the archive with a browser and open it: Gatekeeper allows it without warnings.

## PERM-001

**No privacy permission prompts at launch** (P2). Result: **NOT RUN**

- [ ] On a fresh account, launch the app and open a file in Documents: only the standard folder-access prompt for Documents appears, once.

## UPSTREAM-001

**NS scroll crash fixed after Emacs 31.1 (bug#81585)** (P1). Result: **NOT RUN**

- [ ] When updating the Emacs pin, confirm the new release contains upstream commit b59a6ea35 (git merge-base --is-ancestor b59a6ea35 TAG).
- [ ] Until then, report any crash in ns_scroll_run or copyRect:to: from Console's crash reports against this check.

## UPSTREAM-002

**NS freeze from events sent to a closed window, fixed after Emacs 31.1 (bug#72496)** (P1). Result: **NOT RUN**

- [ ] When updating the Emacs pin, confirm the new release contains upstream commit ef448d2ca.
- [ ] Close and reopen windows repeatedly (Command-W, Dock click, full screen) for a few minutes: Glassmacs never stops responding.
