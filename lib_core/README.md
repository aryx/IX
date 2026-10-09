# lib_core: what ix's programs share

| directory | what | from |
|---|---|---|
| `commons/` | ix's own library (Common, Console, Logging, Regex...) | ix; the dune library `ix_core` |
| `commons/`'s `Exception`, `Exit`, `Fpath_`, `Chan`, `Cmd`, `FS` | the author's own from xix: a traced exception, a program's end (`OK`, `Err` of its words, a code), a channel with its origin, a command, files given a capability | xix (`~/xix/lib_core/commons/`, at `e9cfccc3`), below |
| `core/ base/ collections/ printing/ system/` | the OCaml stdlib, for mini-ml | ocaml-light, then ix |
| `concurrency/` | threads for mini-ml (plan_rio.md): `Thread` (ix's: the scheduler), `Mutex`, `Condition`, `Event` (xix's `lib_core/concurrency/todo/`, ocaml-light's, as they are), `Source` (mini-ml's file; OCaml's is `commons/Source.ml`, the dune library `ix_threads`) | ix; xix |
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
written here), and in [`../docs/plans/done/plan_ml_bootstrap.md`](../docs/plans/done/plan_ml_bootstrap.md),
"The ledger". To see it:

    lib_core/diff_ocaml_stdlib.sh      # each file against ocaml-light's

Not ocaml-light's:

- `collections/Seq`: OCaml 4.14's `seq.ml`, the part ix uses, under
  its header.
- `system/In_channel`, `Out_channel`, and in `system/` the libraries
  ix's programs link, written again small for mini-ml only (dune takes
  the real ones): `Fpath` (after Daniel Bünzli's fpath), `Logs`,
  `Logs_fmt` (after his logs), `Cap`, `CapSys`,
  `CapStdlib`, `CapUnix` (xix's caps, erased), `Unix` (OCaml's, over
  one system call). Each says so in its `.mli`.
- `parsing/Lexing`, `Parsing`: ix's, with OCaml's names.
- Removed: `Stream`, `Weak`, `Stdcompat` (no program names them).

## What comes from xix, in `commons/`

Imported 2026-10-05 (the author: "we should probably start to import
the Exception.ml and Exit.ml from my ~/xix repo in
ix/lib_core/commons/ ... as well as its Chan.ml, Cmd.ml, FS.ml, etc."),
with their headers and comments, so that a diff with xix's stays
small. `Exception`, `Fpath_`, `Chan` and `Cmd` are xix's bytes. Two are
changed, each change under a comment that starts with `ix:`:

- `Exit`: `exit` takes its capability by its type (mini-ml has no
  objects: xix's `caps#exit`); on Plan 9 an `Err`'s string is the
  process's last words (`Sys_plan9.exits`: rc's `$status`).
- `FS`: the capabilities by their types too; and ix's functions,
  each under its `ix:` comment: descriptors (`open_in_fd`,
  `open_rw_fd`, `open_out_fd`, `create_fd`, `open_append_fd`:
  `Unix.openfile` given the capability, for a program that says the
  system's reason when it cannot open), `mkdir`, `remove_any`,
  `getcwd`, and whole files in and out (`read`, `read_opt`, `write`,
  `write_perm`, `path`: what was ix's own `Files`, merged here
  2026-10-07).

mini-ml reads them as they are: `[@@deriving show]` is an attribute it
skips (`Exit.show` is xix's own stand-in), `Printexc`'s backtraces are
ocaml-light's partial ones. Not imported yet, of xix's commons: `Proc`,
`IO`, `Date`, `Logs_`, `Tmp`, `Arg_`, `OS`... ix's own `Procs` does
part of what `Proc` does: to merge. (ix's `Files` was merged into
`FS`, 2026-10-07.)
