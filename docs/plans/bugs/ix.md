# Bugs found in ix

What writing the -h helps of every program found (2026-09-28), each
example run as shown: bugs in ix's own programs, not fixed then, as
not essential. The last three need a decision first.

| program | input | what it does | where, why |
|---|---|---|---|
| mini-5i | `mini-5i /bin/echo hi` (an x86-64 ELF) | `unimplemented instruction 464c457f at 0`: the ELF header's first word run | machine/CLI.ml: Elf.parse rejects the file (PIE?), and Plan9.parse then accepts it as an a.out; meant to be the host's to run, as a script is |
| mini-git | `mini-git clone repo copy` (a relative path) | `could not clone repository` | an absolute path works; git9 takes a path as ssh's, and the relative one reaches it without its directory |
| mini-ld | a program calling an undefined function | `hello.c:0: undefined: print` | the line is 0: the reference's line is not kept to the link |
| mini-merge3 | its usage and its .mli | the usage says `theirs base ours`, Difftool.mli `ours base theirs` | one of the two is wrong; the help says `mine base theirs` meanwhile |
| languages/ml/tests/run.sh | `OCL=... run.sh 7 w fact.ml` | the stdlib still read from /tmp/ix-ocaml-light-arm64 | its `S=` hardcodes the path its `OCL=` line honors |

To decide first:

| program | input | what it does | the question |
|---|---|---|---|
| mini-asm | `FOO R1`, or `MOVW $2` (no destination) | accepted, an object written; only mini-ld then says `unknown opcode FOO` (the missing operand: not seen) | 5a refuses a name that is no instruction: should mini-asm, or is the linker's check enough, the encoding being its (toolchain-design)? |
| tiny-c | `#include <u.h>` | ignored, silently: only "file" includes are read | refuse it (an error at its line), or keep ignoring, as a program of goken's includes both? |
| mini-rc | `mini-rc -z` (an unknown flag) | set as a flag variable, silently; its usage never printed | what does rc do: compare with 9base's rc first |

## mini-ml (2026-10-01, goal 2 of plan_ml_bootstrap.md)

Found by `tests/modern/`, whose programs are run by OCaml 4.14 then by
mini-ml. Not fixed:

| what | input | what it does | where, why |
|---|---|---|---|
| a `.mli`'s `val` the `.ml` doesn't define | `val missing : int` in the `.mli`, nothing in the `.ml` | accepted; a unit naming it fails only at the link | no check of a unit against its interface's values (how `Float.infinity` went unseen) |
| `Sys_error`'s message | a file that is not there | the file's name alone | OCaml's is `name: No such file or directory`: the runtime doesn't ask the error |
| stdout at an exit by a fatal error | a runtime's `unsupported`, an uncaught exception | what was printed and not flushed is lost | ocaml-light's contract (plan_ml.md); OCaml flushes at exit |
| `tests/tiny/arrays` | `run.sh 7`, `run.sh 5` | FAIL | known since before goal 2 |
| `tests/tiny/arith`, `strings` on arm | `run.sh 5` | FAIL | their `.out` recorded on 64 bits |
| `corpus.sh` | | 2 failures: `kernel/9pi/*.ml` and `*.mli` | globs of a directory that moved |
| `tiny/TinyMachinePi_test.sh` | in `make test` | "echo: QEMU's output differs", seen twice (2026-10-01, 10-02), each time inside `make test`; not reproduced alone (60 runs of QEMU on echo, 6 with every core busy, 8 of the script) | open. echo is the test whose input comes by interrupts: a race in echo.s, or in how QEMU feeds its input file, or the harness. The script now tries three times, and prints `FLAKY` with the diff when a try differed: to close when a diff shows which |
| `run.sh 5` with `LIVE=1` | | every program `FAIL: ocamlopt` | needs `/tmp/ix-ocaml-light-arm`, which /tmp's cleaning removes (`kernel/ocaml-light.sh arm`) |

Fixed the day they were found, each with its test:

| what | it did | test |
|---|---|---|
| `=`, `<` on floats | `compare`'s order: `nan = nan` true, `x <> x` false for a nan | `floats.ml` |
| `-. x`, `abs_float` | `-. 0.0` was `0.0`; a nan negated changed its bits (goken.md, 28) | `floats.ml` |
| `ceil`, `floor` | a zero result without its sign (goken.md, 29) | `floats.ml` |
| `%ld` in a format | typed as an `int` (the `l` a flag); `%Ld` refused | `formats.ml` |
| `%S` | typed, then `bad format` when run | `formats.ml` |
| `sys_open` | its flags ignored: every file opened to be written, none read | `files.ml` |
| a call without labels of a function with some | `f 1` for `let f ~a b`: passed by position | `labels.ml` |
| `-7L` | read as the negation of `7L`, not a literal | `boxed_ints.ml` |
| `let f : t = fun x -> ...` | not generalized: the annotation hid the function from the value restriction, so `f` had the type of its first use | `formats.ml` (`error`) |
| `let rec f : t = function ...` | "let rec f: only functions" | `constructors.ml` (`count`) |
| a `# 1 "file"` as a file's first line | "illegal character '#'": the rule wanted a newline before it (ocamllex's and ocamlyacc's files start so) | (the census: `database/Sql.ml`) |

Known, not a bug: mini-5i does not run glibc's programs (gcc's):
their SIMD and more are beyond its subset (plan_arm.md).
