# Development

## Requirements

- GNU Emacs 29 or newer is recommended. Emacs Lisp tests use ERT.
- R, Quarto, and optional Emacs packages are only needed for their respective
  integrations.

## Test and compile

Run ERT in isolated batch mode:

```sh
./scripts/test
```

Byte-compile the Lisp modules with `.elc` output redirected to the system
temporary directory:

```sh
emacs -Q --batch -l init.el \
  --eval '(let ((byte-compile-dest-file-function
                 (lambda (file)
                   (expand-file-name (file-name-nondirectory file)
                                     temporary-file-directory))))
            (dolist (file (directory-files "lisp" t "\\.el$"))
              (byte-compile-file file)))'
```

For a real ESS/R integration check, install ESS and R, start Glassmacs, open an
R file, run `M-x glassmacs-r-start`, and evaluate `1 + 1`. Rendering tests
likewise require R packages or the Quarto CLI. GUI key behavior must be checked
on macOS with a graphical Cocoa Emacs; Linux batch tests do not validate it.

## Isolated launch and dependencies

`./scripts/glassmacs` launches upstream Emacs with `-Q`, then loads this
checkout's `init.el`. `./scripts/bootstrap` installs current package versions
into the separate Glassmacs package directory. Set `GLASSMACS_HOME` before
launch/bootstrap to choose another location. Optional customizations can be
placed in `$GLASSMACS_HOME/custom.el` (default `~/.config/glassmacs/custom.el`).
This prevents Glassmacs from rewriting a pre-existing Emacs init or Aquamacs
preferences.

The package archives are not version-locked in this initial milestone. Tests
should be run with the project's supported Emacs version and with optional
dependencies absent as well as installed when practical.
