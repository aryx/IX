# The tiny spirit, and where tiny/ departs from it

A tiny program is the free variant of its mini twin: "what is left of
a program when compatibility is dropped and only its idea is kept"
(`tiny/README.md`). On 2026-10-11 the author asked whether things under
`tiny/` are "not really the tiny spirit, that is going to the essence
of something, without the backward compatibility constraint". This is
the answer, kept at the author's request, with what was decided for
each item. It is a note and not a plan: most of what departs from the
spirit does so for a reason that is still good ("some of the choices
such as targeting ARM and working on Linux are useful"), so there is
no list of stages to run. It was written from the files' header
comments and their sizes; no program was changed for it but the one
move in section 2.

## 1. The test

Three questions, asked of each file:

1. **Whose contract is it held to?** A tiny program's tests should say
   what the program itself decided. When they compare with another
   program's output, byte for byte, that program is a constraint.
2. **Whose formats and interfaces does it speak?** A file format, a
   calling convention, a system call's number, a library's API taken
   from outside is compatibility, however small the code.
3. **Is each part there for the idea?** A second target, a second
   host, a compression nobody reads: reach, not essence.

A "yes, from outside" is not a fault. It is a cost to name, with what
it buys.

## 2. Decided

| what | how it departs | the author's decision |
|---|---|---|
| `tiny/TinyKernel/steps/v6/` (2,814 lines of C) | its header: "xv6 redone again, its ideas and its names": fork and exec, a kernel stack per process, inodes in layers, spinlocks for cores it does not have. A faithful twin, a mini by ix's naming; `t6/` beside it is its free variant | stays: "we don't really count it anyway in the t-ix make loc so it's fine" (`scripts/stats/loc.py` leaves `tiny/TinyKernel/steps/` out of t-IX's number: "t-ix's own exception") |
| `TinyMkfs.ml` | the disks of v6 (xv6's format less its log and link counts) and of t6; no other program calls it | moved into `tiny/TinyKernel/steps/` (commit c4c1920): "if TinyMkfs.ml is used only by tiny-os/, let's move it inside" |
| `tiny/TinyLibHost/` (7,091 lines, the largest row of t-IX) | `lib_core` copied and trimmed by a script: OCaml's standard library's API, and mini-ml's runtime in C | stays: "we need to compile the TinyXxx programs and they use all the code in TinyLibHost/ (also it's nice that they can be compiled by current OCaml compilers and stdlib)" |

TinyLibHost's case is the clearest example of a constraint that pays: the
stdlib's API is what lets one `TinyShell.ml` be built by dune with
OCaml 4.14 and by mini-ml with nothing of `lib_core/`.

## 3. Kept because useful: arm64 and Linux

One decision runs through four files: the tiny toolchain makes
programs for a real processor, run by a real kernel.

| file | what it takes from outside |
|---|---|
| `TinyAssembler.ml` | Plan 9's assembly syntax (7c -S's), so goken's libc is its input too; an ELF file, as Linux loads it |
| `TinyC.ml` | 7c's calling convention and Plan 9's C conversions, to link with goken's libc |
| `TinyML.ml` | ocaml-light's arm64 ocamlopt as "the contract, quirks included": the order of evaluation, stdout's buffer of 4096 bytes lost on an uncaught exception, that exception printed as `printexc.c` prints it, division by zero giving 0 |
| `TinyCPUArm.ml` (313 lines of code) | "a machine inherited": an arm64 subset, ELF, Linux's numbers for four system calls; its check is that the real CPU and mini-5i print the same |

What it buys:

- **The programs run on the machine the author has.** A tiny-c or
  tiny-ml executable runs on Linux on arm64, on a Pi, with no emulator
  of ix's in between.
- **A check from outside.** A designed machine can only be compared
  with itself. An inherited one has a real CPU, mini-5i and tiny-arm to
  hold against each other, and ocaml-light's ocamlopt gives tiny-ml
  expected outputs nobody had to write, the random programs' too
  (`tiny/tests/TinyML_fuzz.py`).
- **A libc that exists.** goken's libc, by 7c, is under both compilers;
  the free path needed its own (`TinyCRuntime/`).

What it costs:

- **Two back ends in each compiler.** `machine_arm64` and `machine_tm`
  are about 140 and 160 lines in `TinyML.ml`, about 110 and 105 in
  `TinyC.ml`. "One idea, one file" is, there, one front end and two
  targets.
- **A CPU that has no machine.** tiny-arm stops at a system call;
  nothing of t-ix boots on it (the Pi's machine is mini-qemu, m-ix's).
- **Quirks kept on purpose.** tiny-ml's list above is behavior nobody
  would design.
- **goken at test time.** `make test-goken`, not `make test`.

The free path exists beside it and is whole: `tiny-c -tm` and `tiny-ml
-tm`, `TinyCRuntime/`, tiny-cpu, tiny-machine, tiny-kernel. So the
question is not whether t-ix can do without arm64 (it can: t-IX in a
web page does), but whether the second path earns its lines. The
author's answer is that it does.

If it were ever revisited, the pieces go together: the two arm64 back
ends, `TinyAssembler.ml`, `TinyCPUArm.ml` and tiny-ml's contract with
ocaml-light leave or stay as one. Taking one alone breaks the others'
tests.

## 4. Small, and open

- **`TinyVCS.ml` deflates its objects.** Its design is free (an
  operation log, no staging, conflicts as data) and its objects' text
  is its own, which no git reads. The hash is the idea; the
  compression is not, and it is why tiny-vcs links `Zlib` (238 lines in
  `TinyLibHost/ocaml/`).
- **`TinyKernel/user/` has C programs** (`sh.c`, `cat.c`, `ls.c`...) on
  a kernel whose point is ML. They show that the kernel's calls do not
  depend on the language; a shell in ML would show the other half.
- **`TinyMachineWeb.ml`** is a second host for the same machine, by
  js_of_ocaml: reach. It is what makes t-IX a page.

None of these was discussed with the author.

## 5. In the spirit

`TinyBuildSystem.ml`, `TinyShell.ml`, `TinyEditor.ml`,
`TinyDatabase.ml`, `TinyCPU.ml` with `TinyMachineCPU.ml`, `TinyMachine.ml`,
`TinyKernel.ml`, `TinyKernelGraphics.ml`, `TinyWindows.ml`,
`TinyLibPlayground.ml`, `TinyKernel/steps/t6/` and `TinyKernel/steps/v0/`: each decides its
own language, format or machine, and its tests are its own.
`TinyAppTetris.ml` is a port of the playground's game and is small either
way.

## 6. For a new tiny program

- Say in its `.mli` header what it keeps from outside and why, as
  `TinyCPUArm.mli` does ("a machine inherited") and `TinyML.mli`
  ("the contract, quirks included"). A constraint that is named can be
  judged later.
- What only one program or one system uses goes in its directory
  (`TinyKernel/steps/t6/TinyMkfs.ml`), not at `tiny/`'s top.
- A faithful twin that is small is still a mini. It can live in
  `tiny/` as `tiny-os/v6/` does, outside t-IX's number.
