# TinyLib: the library under the tiny programs

What a tiny program of the host (`tiny/mkfile`'s: tiny-build,
tiny-shell... tiny-mkfs) has under it when mini-ml compiles it, in
place of m-ix's `lib_core/`: the modules those programs name, and
the ones these name, each with only the functions that are called.

    cd tiny && mini-mk LIB=tiny      # the programs, in _mk/7/tinylib/
    cd tiny && mini-mk               # as before: lib_core/'s, in _mk/7/tiny/

It is an option. dune's build has OCaml's stdlib and `ix_core`, as
before, and mini-mk's default is `lib_core/`.

| directory | what |
|---|---|
| `ocaml/` | the stdlib's modules and ix's own (`commons/`), SHA-1 and zlib: a flat list |
| `c/`, `asm/` | not there yet: mini-ml's runtime (`languages/ml/runtime/`) and the C library under it (`lib_core/libc/`) are still m-ix's, for both builds |

## `ocaml/`

Copied from `lib_core/`, `lib_crypto/` and `lib_compression/` on
2026-10-09 (the author: "Let's start a TinyLib/ that mini-ml would
use instead of lib_core, with in it the flat list of modules for now,
with just the functions needed"), then trimmed by
`scripts/stats/tiny_lib_trim.py`: a value of a module that no tiny
program names, nor another module here, nor the module itself, is
taken out of its `.mli` and its `.ml`, again until nothing goes (275
values in all; `Uchar` went whole). Each `.mli` says in its first line
where it is from. `Unix` is Linux's.

The comments are shorter than lib_core's (the author: "copyright
boilerplate that could be reduced to one line for the author and one
line for the copyright; we can maybe shorten also many comments in the
.mli; keep the essence of the original, especially if contain useful
assumptions"): OCaml's boxed license header is two lines, the author
and the copyright with the license's name
(`scripts/stats/short_box_header.py`); a function's text is kept where
it says more than its type (what it raises, an order, a limit, a
copy), by hand; the lists of what lib_core took out, and the comments
of functions that are gone, are not there. The full texts are
lib_core's, and OCaml's manual's.

What is kept is kept by name, a word found in the code or in a
comment: so a function may still be there for nothing. Types,
exceptions, operators and the functions behind an `and` stay.

`scripts/stats/tiny_lib_trim.py -t`:

| module | from | lines there | lines here |
|---|---|---|---|
| `Arg` | `lib_core/system/` | 382 | 306 |
| `Array` | `lib_core/collections/` | 292 | 189 |
| `Buffer` | `lib_core/base/` | 252 | 144 |
| `Bytes` | `lib_core/base/` | 562 | 225 |
| `Cap` | `lib_core/system/` | 21 | 22 |
| `CapStdlib` | `lib_core/system/` | 10 | 11 |
| `CapSys` | `lib_core/system/` | 10 | 11 |
| `CapUnix` | `lib_core/system/` | 22 | 21 |
| `Chan` | `lib_core/commons/` | 87 | 76 |
| `Char` | `lib_core/base/` | 117 | 76 |
| `Common` | `lib_core/commons/` | 20 | 21 |
| `Console` | `lib_core/commons/` | 30 | 20 |
| `Digest` | `lib_core/base/` | 90 | 46 |
| `FS` | `lib_core/commons/` | 177 | 72 |
| `Filename` | `lib_core/system/` | 151 | 102 |
| `Float` | `lib_core/base/` | 271 | 55 |
| `Format` | `lib_core/printing/` | 780 | 683 |
| `Fpath` | `lib_core/system/` | 87 | 64 |
| `Fpath_` | `lib_core/commons/` | 51 | 36 |
| `Fun` | `lib_core/base/` | 99 | 25 |
| `Hashtbl` | `lib_core/collections/` | 282 | 216 |
| `In_channel` | `lib_core/system/` | 39 | 38 |
| `Int` | `lib_core/base/` | 141 | 37 |
| `Int32` | `lib_core/base/` | 154 | 52 |
| `Int64` | `lib_core/base/` | 191 | 124 |
| `List` | `lib_core/collections/` | 552 | 461 |
| `Logging` | `lib_core/commons/` | 20 | 21 |
| `Logs` | `lib_core/system/` | 72 | 69 |
| `Logs_fmt` | `lib_core/system/` | 10 | 11 |
| `Marshal` | `lib_core/core/` | 456 | 376 |
| `Obj` | `lib_core/core/` | 71 | 49 |
| `Option` | `lib_core/base/` | 136 | 58 |
| `Out_channel` | `lib_core/system/` | 25 | 26 |
| `Pervasives` | `lib_core/core/` | 939 | 627 |
| `Printf` | `lib_core/printing/` | 272 | 246 |
| `Procs` | `lib_core/commons/` | 86 | 74 |
| `Queue` | `lib_core/collections/` | 127 | 79 |
| `Seq` | `lib_core/collections/` | 153 | 142 |
| `Sha1` | `lib_crypto/` | 86 | 75 |
| `String` | `lib_core/base/` | 488 | 369 |
| `Sys` | `lib_core/system/` | 228 | 136 |
| `Unix` | `lib_core/system/` | 712 | 636 |
| `Zlib` | `lib_compression/` | 287 | 274 |
| all | | 9038 | 6401 |

## What remains

- The size: 6,401 lines where lib_core's are 9,038 (the same 44
  modules). What weighs: `Format` (there for `Logs`, which `FS` and
  `Logging` call), `Unix`, `Pervasives`, `Marshal` (tiny-db's
  records), `Arg` (tiny-build's).
- To make it smaller a tiny program has to call less (the author:
  "we can later decide wether or not simplify some Tiny programs to
  remove the use of certain fucntions to keep the size small"); then
  the script again.
- A change in `lib_core/` does not come here by itself.
- The runtime and the C library (`c/`, `asm/`); and tiny-c -tm's own
  library, `tiny/TinyC/libc/`, which could be this directory's too.

## Checked

The 13 programs built with `LIB=tiny` (in a copy of the tree), and
`tiny/tests/`'s scripts run on them: the same answers as the programs
built on `lib_core/`, `TinyML_test.sh`'s `loops` under tiny-arm
included, which times out with both.
