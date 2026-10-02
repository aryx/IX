# lib_core: what ix's programs share

| directory | what | from |
|---|---|---|
| `commons/` | ix's own library (Common, Console, Files, Logging, Regex...) | ix; the dune library `ix_core` |
| `core/ base/ collections/ printing/ system/` | the OCaml stdlib, for mini-ml | ocaml-light, then ix |
| `parsing/` | Lexing and Parsing, mini-lex's and mini-yacc's run time | ix (plan_lex_yacc.md) |
| `libc/` | the C library under mini-ml's runtime | goken: [`libc/README.md`](libc/README.md) |

dune builds only `commons/`: its programs have OCaml's stdlib. mini-ml
compiles the others (`units.txt`: the units in their link order;
`mkfile`: the build, by mini-mk).

## The stdlib's origin

From ocaml-light (`~/github/ocaml-light`) at `f397c6bf` (2026-09-16),
its `stdlib/`. ocaml-light is itself derived from OCaml 1.07 (INRIA,
1997), kept small by the author: so most of these files are OCaml
1.07's, with what ocaml-light took since from later OCamls. Here: the files' names
capitalized (`list.ml` is `List.ml`) and split in directories as xix's
`lib_core/`. Each file keeps its own header: INRIA's copyright, and
for the modules ocaml-light took from later OCamls (Option, Result,
Either, Fun, Int, Bool, Float, Uchar...) OCaml's LGPL notice.

What ix changed since is in the files, under a comment that starts
with `ix:` (OCaml 4.14's later functions that ix's programs call,
written here), and in [`../docs/plans/plan_ml_bootstrap.md`](../docs/plans/plan_ml_bootstrap.md),
"The ledger". To see it:

    lib_core/diff_ocaml_stdlib.sh      # each file against ocaml-light's

Not ocaml-light's:

- `collections/Seq`: OCaml 4.14's `seq.ml`, the part ix uses, under
  its header.
- `system/In_channel`, `Out_channel`, and in `system/` the libraries
  ix's programs link, written again small for mini-ml only (dune takes
  the real ones): `Fpath` (after Daniel Bünzli's fpath), `Logs`,
  `Logs_fmt`, `Fmt` (after his logs and fmt), `Cap`, `CapSys`,
  `CapStdlib`, `CapUnix` (xix's caps, erased), `Unix` (OCaml's, over
  one system call). Each says so in its `.mli`.
- `parsing/Lexing`, `Parsing`: ix's, with OCaml's names.
- Removed: `Stream`, `Weak`, `Stdcompat` (no program names them).
