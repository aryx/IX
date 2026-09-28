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

Known, not a bug: mini-5i does not run glibc's programs (gcc's):
their SIMD and more are beyond its subset (plan_arm.md).
