# Validation candidate source and licensing inventory

**Status: incomplete; distribution blocked.** This is an engineering
inventory, not a legal opinion. Package names and upstream source links do
not establish that every exact corresponding source, patch, build script,
copyright notice and license is available. Review the complete materials
before marking `corresponding_source_and_licenses` as passed.

| Component | Evidence and known source | Status |
| --- | --- | --- |
| Glassmacs | Application source `b7f19966e447ad94c5d894211a2dfe15a86c184e`; repository `LICENSE` is GPL-3.0. Build and relocation scripts are in that commit. | Source available; review third-party material in the repository. |
| GNU Emacs | Upstream [build listing](https://emacsformacosx.com/builds) links [Emacs 31.1 source](https://emacsformacosx.com/emacs-sources/emacs-31.1.tar.xz) directly to the pinned binary. Downloaded source SHA-256 `770c1a3d33d7507c1f58fc23f6579828aa4a8f153e95c625dfaca841fd2124a7`. Upstream's [about page](https://emacsformacosx.com/about) says it adds no patches to Emacs. GNU Emacs is GPL-3.0-or-later; its source includes notices and COPYING. | Source linked by upstream; exact builder revision and build-specific modifications are not independently established. The upstream annotated `emacs-31.1` tag points to `a360712c9d272d950d8d8255ef74570f7e90b7d9`, but the release tarball has not been proven byte-for-byte equivalent to that Git tree. |
| ESS | [GNU ELPA ESS 26.5.0 source](https://elpa.gnu.org/packages/ess-26.5.0.tar), SHA-256 `49b40ebf5eee0e24ca0aa8c4c7add3696d8b55b19eb0de0036960f6c1994ae1e`; source files specify GPL-3.0-or-later, and the bundle includes ESS COPYING. | Exact pinned tarball available; preserve the tarball and Glassmacs byte-compilation/build scripts. |
| GCC / libgccjit | Upstream's [31.1 dependency manifest](https://emacsformacosx.com/emacs-sources/Emacs-31.1-dependencies.json), SHA-256 `d65759c76b2c2949f7386472fb2f78f3de9cb23a66d51d9b6dc097a5c88a2986`, identifies GCC 14.3.0 on arm64 and 14.2.1.20250322 on x86_64; embedded GCC headers and library strings agree. GCC and components contain GPL-family licenses and exceptions that must be checked per component. | Nix cache metadata exposes the source objects, but the complete patches, derivations, notices and corresponding source for these exact binaries have not been assembled or reviewed. |
| Rust launcher, Swift bootstrap, lifecycle module and quit helper | Source is present in the upstream [build script mirror](https://github.com/caldwell/build-emacs) and Glassmacs commit; upstream build scripts declare GPL-3.0-or-later. | Confirm exact upstream launcher version and all Rust dependencies, license notices and source. |
| Other bundled dynamic libraries and executables | The upstream dependency manifest gives direct dependencies and versions per architecture, not the complete transitive closure. The app validator inspected 547 Mach-O files; 64, 68 and 62 top-level dylibs were found in the arm64, x86_64 macOS 11 and x86_64 macOS 10.12 library directories respectively. | Map every actual binary to its exact source, modifications, applicable licenses and notices, including static components and SDK materials. |
| R | R is an external, separately installed executable, not bundled by the Glassmacs build. | Its separate distributor's terms apply; do not imply R is included. |

The unique top-level dylib names inspected include Lerc, X11/Xau/Xdmcp/Xext/
Xrender/XCB, brotli, bzip2, libc++/libc++abi, Cairo, datrie, dav1d,
libdeflate, expat, libffi, fontconfig, FreeType, FriBidi, libgcc/libgccjit,
GDK-Pixbuf, GLib/GIO/GObject, GMP, GnuTLS, graphite2, HarfBuzz, nettle/
hogweed, iconv, IDN2, gettext, JPEG, LZMA, MPC, MPFR, ncurses, p11-kit,
Pango, PCRE2, pixman, PNG, resolv, librsvg, SQLite, libtasn1, libthai,
TIFF, tree-sitter, libunistring, WebP, libxml2, zlib and zstd. Names alone
are not a complete license or provenance determination.

The upstream binary is pinned by URL and SHA-256 in
`macos/upstream-emacs.env`. The builder states its public repository is a
[possibly stale mirror of its private build repository](https://github.com/caldwell/build-emacs/blob/d4f679b11848e2843cd7ed76d529156d7c1d8362/README.md#project-status-and-scope).
The public mirror's `dependencies.nix` is useful evidence, not proof of the
actual private build revision. Ask the upstream builder for the exact build
revision, complete source/patch and dependency closure, including all
applicable notices; or rebuild from fully pinned, auditable inputs.

Source and manifest copies are retained locally under
`build/distribution-evidence/source-audit/`; they are not a durable public
source offer. Publish the complete, reviewed corresponding source and license
materials without charge alongside the binary, then verify public access.
