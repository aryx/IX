# Plan: t-ix on one machine, and t-ix building itself there

The author (2026-10-19): "for t-ix, what remains to get all the
tiny-programs to actually run under tiny-machine? Also I wonder if we
should stop having this division of tiny programs that runs under t-ix
and some tiny-programs that run only on the host. Maybe we should get
rid of the TinyAssembler targeting ARM? Maybe t-ix should only be
concerned with the tiny-machine (and also the ability to run on the host
directly, which makes things easier to test)." Then: "I think we could
still compile t-ix with m-ix, which is a good test for m-ix, but we can
use directly lib_core/ instead of a copy-pasted reduced TinyLibHost/. I
originally asked for the copy-pasted TinyLibHost/ to get a sense of what
is used and not used from lib_core, but if we manage to self-host t-ix,
we will just need TinyLibCore and TinyLibStd." Then: "maybe we can also
revisit the tiny-ml no module support; now that TinyLibHost/ is gone,
that frees lots of lines of code, and maybe we could have a proper
TinyLibCore/ with separate modules that reminds of the OCaml standard
library organization. Tiny is a free variant though, so we don't have
to follow the OCaml standard library of course"; "maybe we could also
have a proper TinyAssembler and TinyLinker and separate compilation";
"we could even self-host and run this under the tiny-machine itself
too". Section 6 is those three.

This revisits two decisions of 2026-10-11 recorded in
[notes_tiny_spirit.md](../notes_tiny_spirit.md): arm64 kept (its §3) and
TinyLibHost kept (its §2). That note already said that, if arm64 were
ever revisited, its pieces leave together; they do here.

## 1. The idea: one target, three builds of the same files

Today a tiny program is either the host's (tiny-build, tiny-c, tiny-ml,
tiny-db, tiny-vcs...) or tiny-kernel's (rc, utils, ed, emacs, office,
www, tetris...), and three of them are both. After this plan every
program of t-ix is a program of tiny-kernel. The host keeps two roles
only: it is the machine (tiny-machine, its window, its socket, its
page), and it runs the same files under OCaml to test them.

```
                      TinyXxx.ml  (OCaml ∩ tiny-ml: no modules, no Printf)
                 /                     |                          \
     dune, OCaml's stdlib     mini-mk + mini-ml, lib_core/     tiny-ml -tm, TinyLibCore + TinyLibStd
     + TinyLibSystem (Unix)   (m-ix building t-ix: a test     + TinyLibSystem (tiny-kernel's calls)
     = the tests, on the host   of m-ix's toolchain)          = the program on tiny-kernel
                                                                  |
                                                     at the end, built on tiny-kernel itself
```

- **The target is tiny-machine.** tiny-c and tiny-ml lose their arm64
  back ends; tiny-assembler and tiny-arm leave.
- **The host is a test bench, not a target.** dune builds every file on
  OCaml's own standard library, so a program is tried, and its tests
  run, without the machine.
- **m-ix still builds t-ix**, as a test of mini-ml on programs it did
  not grow up with, but on `lib_core/` directly (`mini-mk LIB=core`,
  which already exists). `TinyLibHost/ocaml/` and `TinyLibHost/c/`, the
  trimmed copy, have done their job: they showed what of `lib_core/`
  the tiny programs use.
- **Self-hosted, t-ix's library is TinyLibCore.ml and TinyLibStd.ml**,
  with `TinyLibSystem` beneath (one per side) and `TinyMLRuntime/`.

## 2. What goes

| what | lines (about) | why it can go |
|---|---|---|
| `TinyAssembler.ml` | 600 | arm64's assembler and linker; the name is reused by tiny-machine's (section 6) |
| `TinyCPUArm.ml` | 350 | arm64's interpreter |
| `TinyLinker.ml` | 70 | a comment about the two toolchains' links; the name is reused by tiny-machine's real linker (section 6) |
| `TinyC.ml`'s and `TinyML.ml`'s arm64 back ends, `start_arm64` | 300 | one back end each, `-tm`'s, which becomes the only one (the `-tm` flag goes too) |
| tiny-ml's ocaml-light quirks | a few dozen | the 4096-byte buffer lost on an uncaught exception, division by zero giving 0: behavior nobody would design |
| `TinyLibHost/ocaml/`, `TinyLibHost/c/` | 5,500 of code (`make loc` counts tiny-lib-host as 8,500: README's 26,500 for t-IX, 18,000 without it) | dune has OCaml's stdlib, mini-mk has `lib_core/` |
| `scripts/stats/tiny_lib_trim.py`, `tiny_lib_c.py` | | they made and checked the copy |
| `make test-goken`, `TinyAssembler_test.sh`, `TinyCPUArm_test.sh` | | goken's libc and 7c were arm64's contract |

What stays, moved: `TinyLibHost/TinyLibSystem.ml` (the host's system,
over Unix) goes to `TinyKernel/host/`, beside `TinyCalls`, which is the
same pattern (one interface, an implementation per side). `tiny/mkfile`
keeps its `LIB=core` half and loses `LIB=tiny`; `tiny-assembler` and
`tiny-arm` leave its `PROGS` and `tiny/dune`.

The outside check arm64 gave is replaced, not lost:

- **tiny-ml's expected outputs stay.** `languages/ml/tests/tiny/*.out`
  were recorded from ocaml-light's ocamlopt; they are run under tiny-cpu
  (`-tm`) instead of on arm64. The few that depend on a quirk are
  recorded again, from OCaml.
- **OCaml is the new reference.** `TinyML_fuzz.py` compares `ocaml`
  with `tiny-ml` on tiny-cpu, where it compared ocaml-light with
  tiny-ml on arm64. `TinyC_fuzz.py` and `TinyC_test.sh` compare tiny-c
  on tiny-cpu with the host's C compiler, where they used 7c's outputs.

## 3. The rule: one dialect for every file

A file of t-ix is written in what OCaml and tiny-ml both compile, and
calls the system only through `TinyLibSystem`. rc, utils and ed already
are; the others are not:

- **a file is a module, and there are no others** (no nested modules,
  no functors); `String.trim` is OCaml's on the host and TinyLibStd's on
  the machine (TinyLibCore/'s after section 6), with the same behavior
  (`TinyLibStd_test.sh` checks it);
- **no `Printf`**: `^` and `string_of_int`;
- **no `Seq`, `Queue`, `Marshal`, `Int64`**: lists, a pair of lists, a
  format of the program's own, two halves;
- **no `Cap`, `FS`, `Fpath`, `Console`, `Logging`, `Procs`, `Unix`,
  `Sys` directly**: `TinyLibSystem`'s functions, which still take `caps`
  (the host's are real capabilities, tiny-kernel's are ignored);
- **integers of 31 bits**: tiny-ml's are, so a 32-bit word is two
  halves (section 5).

A shared helper that is not the stdlib's is a plain file of the same
dialect, `TinyLibRegex.ml`'s way: functions with ordinary names,
compiled into each program that needs it, by both compilers.

## 4. What each program needs

From a grep of the names each file uses, before trying any of them:

| program | needs | size |
|---|---|---|
| tiny-prof | `Hashtbl`, `Printf` out; reading the profile through `TinyLibSystem` | small |
| tiny-cpu (and `TinyMachineCPU.ml`) | `Printf` (14), `Int32` (5) out; its memory a `Bytes` of a few MB, not the 128 MB of tiny-machine; 32-bit words (section 5) | medium |
| tiny-db | `Seq` (19) as lists, `Unix` (10) as `TinyLibSystem`, `Bytes` | small–medium |
| tiny-vcs | SHA-1 (section 5); `Zlib` dropped (notes_tiny_spirit.md §4: "the compression is not" the idea); `Filename`, `Sys`, `Unix` through `TinyLibSystem` | medium |
| tiny-build | SHA-1; exec and wait (tiny-kernel's `TinyLibSystem` has both); `Hashtbl` (32) | medium |
| tiny-c | `Printf` (34), `Int64` (37: mostly arm64's, gone with it), `Hashtbl` (49), `Buffer` (26) | large |
| tiny-ml | `Printf` (15), `Queue` (7), `Hashtbl` (38), `Buffer` (10); its prelude, `TinyLibCore.ml`, read as a file of `/sys` instead of being put in the compiler by the build | large |

Not ported: tiny-machine and its window, socket, page and peer (they
are the machine), tiny-mkfs (`TinyKernel/steps/`' own).

## 5. The three things in the way

**TinyLibStd's `Hashtbl` and `Buffer` are not a compiler's.** Today
`Hashtbl` is an association list and `Buffer` grows by `^`: fine for
rc's variables, quadratic for a compiler's symbol tables and output. A
real `Hashtbl` is an array of buckets, which needs a hash of any value:
an external of `TinyMLRuntime/` that walks a value as OCaml's
`Hashtbl.hash` does (about 20 lines of C). A real `Buffer` is `Bytes`
that doubles. rc, utils and the office get faster with them.

**31 bits.** SHA-1 (tiny-build's stamps, tiny-vcs's objects) and
tiny-machine's instruction words are 32 bits. Both are done on halves
of 16 bits: a `Sha1.ml` in the shared dialect, in TinyLibCore/ (which
also takes dune's tiny-build and tiny-vcs off `lib_crypto/`), and the assembler's
words written as two halves into `Bytes`. A wider integer in tiny-ml is
the other road; it would change the runtime's value representation for
two programs, so halves first.

**Memory and time.** A process has 1 MB unless its a.out asks for more
(`tiny-linker -a n`); the compilers will be built with a larger `-a`, and
the partitions (112 MB, 8 slots) have room. How long tiny-ml takes to
compile `TinyML.ml` under the interpreter is not known; it is measured
first on the host under tiny-cpu, without the kernel, then
`TinyProfiler` says where the time goes (and the fixes go to the
compiler, the runtime or the machine, not to the program).

## 6. With one target, the toolchain revisited (proposed)

arm64 forced two shortcuts that one target no longer needs: tiny-ml has
no modules (a name with a dot is one name, `open M` is read and left),
and nothing is compiled separately (all of a program's `.tm` files are
assembled and linked together, by `TinyMachineCPU.ml`'s
`assemble_files`). Both cost more once t-ix builds itself: the
compilers will run under an interpreter, so recompiling only what
changed matters, and a partition is smaller than a whole program's
compilation.

```
   M.mli ──(read by the modules that name M)──┐
   M.ml ── tiny-ml ──> M.s ── tiny-assembler ──> M.o ─┐
   f.c  ── tiny-c  ──> f.s ── tiny-assembler ──> f.o ─┼── tiny-linker ──> image or a.out
   TinyLibCore/*.ml, TinyMLRuntime/, TinyCRuntime/ ──> lib.a ─┘          (+ its symbols)
```

- **tiny-assembler: tiny-machine's assembler, a program of its own.**
  The assembler leaves `TinyMachineCPU.ml`, which keeps the CPU only
  (encode, decode, step); tiny-cpu and tiny-machine load images and no
  longer assemble. An object is the words, the symbols it defines and
  the ones it needs, and the places to patch (a branch's offset, `la`'s
  address). The object format is t-ix's own.
- **tiny-linker: a linker, at last.** Objects and archives (an archive
  is objects one after the other) to an image or an a.out, at the
  addresses it chooses; the symbol table after the image, which is
  what `plan_tiny_debugger.md` §4 wants for db and what tiny-prof reads
  today from the `.tm` files.
- **Modules in tiny-ml, as compilation units and nothing more.** A
  file is a module; `M.mli` is its interface, read by the modules that
  name `M` (every file of t-ix already has one, checked by OCaml); a
  name is `M.x` outside `M`, `x` inside, and `open M` really opens.
  There are no nested modules, no functors and no signatures other than
  the files': ocaml-light's minimum. Per module: its own globals table
  (today `ml_globals` is one table numbered across the program), its
  initialization run in link order, its exceptions as symbols. The
  dotted-name trick (`let String.trim = ...`) goes.
- **TinyLibCore/ as modules.** `Stdlib.ml` (today's prelude: the
  operators, `option`, the exceptions; opened by every module, as
  OCaml's), `List.ml`, `String.ml`, `Bytes.ml`, `Array.ml`, `Char.ml`,
  `Option.ml`, `Hashtbl.ml` (buckets, with the runtime's hash),
  `Buffer.ml` (doubling `Bytes`), `Filename.ml`, and `Sha1.ml`, compiled
  once into `lib.a`. `TinyLibCore.ml` and `TinyLibStd.ml` become this
  directory; the build no longer puts the prelude's text into the
  compiler (`TinyMLPrelude.ml`), which reads `Stdlib.mli` like any
  other interface.
- **Its API stays a subset of OCaml's, on purpose.** Tiny is free
  to differ, but every program is also built by dune on OCaml's own
  standard library, which is how it is tested on the host and how
  `TinyLibStd_test.sh` checks TinyLibCore/'s implementation. A name that
  meant something else on each side would break both. The freedom is in
  the implementation, and in leaving out what tiny programs do not
  need.
- **All of it runs on tiny-kernel.** tiny-assembler and tiny-linker are
  small programs in the shared dialect, so they are ported as the others
  are, and tiny-build drives the compilers there, recompiling only the
  modules whose sources (or the interfaces they read) changed.

## 7. The steps

1. **arm64 out.** The back ends, `TinyAssembler.ml`, `TinyCPUArm.ml`,
   `TinyLinker.ml`, the goken tests; tiny-ml's and tiny-c's tests and
   fuzzers on tiny-cpu against OCaml and the host's C compiler; the
   docs (`tiny/README.md`, `docs/manuals/t-ix.md`, `docs/projects.md`,
   `notes_tiny_spirit.md`). One commit, so no test is left on a
   missing piece.
2. **TinyLibHost out.** `TinyLibSystem.ml` to `TinyKernel/host/`;
   `tiny/mkfile` on `lib_core/` only; the scripts and `make loc`'s row.
   Check: `mini-mk` in `tiny/` builds every remaining host program, and
   they pass their tests.
3. **tiny-assembler and tiny-linker.** The assembler out of
   `TinyMachineCPU.ml`; objects, archives, the symbol table; tiny-cpu
   and tiny-machine on images; tiny-prof on the symbol table. Check:
   every image `make check` boots is the same, byte for byte, as when
   `assemble_files` linked it.
4. **Modules in tiny-ml.** `.mli` read, `M.x`, `open`, a globals table
   and an initialization per module; a program compiled a module at a
   time and linked. Check: every program of tiny-kernel built this way,
   and `make check`'s screens and sums unchanged.
5. **TinyLibCore/.** The prelude and TinyLibStd.ml as modules; the real
   `Hashtbl` and `Buffer`; `Sha1.ml`. Each tested on both sides by
   `TinyLibStd_test.sh`.
6. **The small ports.** tiny-prof, tiny-db, tiny-vcs (no zlib),
   tiny-build, each into the dialect and onto `/bin`, with a line of
   `make check` that runs it on tiny-kernel.
7. **The toolchain on tiny-kernel.** tiny-assembler, tiny-linker and
   tiny-cpu (an interpreter inside the machine); then tiny-c, which
   compiles `TinyMLRuntime/` and `TinyCRuntime/` there; then tiny-ml,
   compiling a small program, the tools, and itself. Each result is the
   host's, byte for byte.
8. **The system from its sources.** The sources in the image (or on
   the disk) under `/sys/src`, Plan 9's place; tiny-build's mkfile for
   `/bin` and for the kernel; the boot image made on tiny-kernel, booted
   with `-d`, and equal to the one `TinyKernel/Makefile` made on the
   host. A change to one module recompiles that module and relinks.

After step 2, t-ix has one target. After step 5, tiny-ml is a compiler
of modules with a library of modules. After step 6, every tool of t-ix
runs on tiny-kernel but the toolchain. After step 8, t-ix builds itself,
and its library is TinyLibCore/.

## 8. What is given up

- **t-ix's programs on a real CPU.** A tiny-c or tiny-ml executable no
  longer runs on Linux on arm64 or on a Pi. m-ix's build of the host
  tools still does (`mini-mk`), as programs of m-ix.
- **ocaml-light as a second implementation to compare with.** OCaml
  takes its place, which is a stronger reference but a less
  independent one for the fuzzers (both of OCaml's family).
- **The trimmed library as a measure** of what the tiny programs take
  from `lib_core/`. Self-hosted, that measure is TinyLibStd.ml's size.

## Status

- 2026-10-19: written, from a survey of the files; nothing tried yet.
- 2026-10-19: step 1 done, arm64 out. Gone: `TinyAssembler.ml`,
  `TinyCPUArm.ml`, `TinyLinker.ml`, `TinyMLRuntime/runtime.c` (arm64's
  main), the two back ends and `start_arm64`, the `-tm` flag (tiny-c
  988 lines, 113 fewer; tiny-ml 1,576, 171 fewer); t-IX 25,700 lines,
  18,500 without TinyLibHost. What was found and decided on the way:
  - **tiny-c's reference is the host's cc**, through
    `TinyC_tests/host.h` (Plan 9's C on a 64-bit host: long an int,
    print printf, -fsigned-char -fwrapv); the tests' outputs recorded
    (`TinyC_tests/*.out`), RECORD=1 records them again. No `-m32` on
    the author's aarch64 Linux, so a test prints no pointer's size.
  - **long long out of the tests**: arith.c, calls.c and struct.c lost
    their vlong lines (they were refused on tiny-cpu, so tested only
    on arm64); all eleven run on tiny-cpu now. `libc.h` keeps vlong's
    typedef, for mini-cc's `simple.sh` and TinyC_fuzz.py without
    --32.
  - **tiny-c's promotion is ANSI's**: a uchar or ushort widens to int,
    not uint (Plan 9's, 7c's). TinyC_fuzz.py's programs, 300 of them,
    then agree with gcc; before, 23 did not. tiny-kernel's programs
    are the same size (check.expected's `ls -l` lines unchanged).
  - **TinyC_fuzz.py read a variable never set** (`x0 = x0`), which 7c
    and tiny-c agreed on and gcc did not: bugs/ix.md.
  - **tiny-ml's tests run on tiny-cpu** only, at two heaps (4096
    words, and 64 for the collector's law); gc.ml left out, as before
    (its lists are deeper than tiny-cpu's 1 MB). arith.ml and
    strings.ml print max_int: `.tiny-ml.out` for them, the 31-bit
    lines alone differing; the `.out` files, shared with mini-ml's
    run.sh, unchanged. TinyML_fuzz.py --31 against OCaml's ocamlopt:
    150 programs the same. Without --31 it stays mini-ml's (make
    test-ocaml).
  - **Both tests and both fuzzers are in `make test`** (30 random
    programs each, in /tmp/ix-tiny), no goken needed; test-goken and
    test-ocaml lost their tiny lines; tests/lite.sh runs TinyC_test.sh
    and TinyML_test.sh.
  - **`languages/c/tests/simple.sh 7`**, mini-cc's, assembled 7c's
    code with TinyAssembler (7l's section-table bug): mini-asm and
    mini-ld now, with libc.sh 7's libc. 28 of 28 the same (goken's
    hello_libc and TinyC_tests).
  - **Not done in step 1**: tiny-ml's ocaml-light quirks (stdout's
    buffer lost on an uncaught exception, division by zero, the
    uncaught exception's message: §2 lists them); the recorded
    `.out` files are still ocaml-light's, and mini-ml's run.sh reads
    them too, so they go with a decision about both.
  - **Run**: TinyC_test.sh, TinyML_test.sh, both fuzzers, every
    tiny/tests/*_test.sh, simple.sh 7, `make check`'s text part and
    its two sounds (tiny-kernel built into the scratchpad: the same
    but a line of the host's `wc -c`, padded on the author's other
    machine). Not run: make check's 23 recorded screens, mkfiles/check.sh
    (m-ix building tiny/), make test-goken. Two failures that are not
    this step's: TinyUtilities_test.sh's `du` (the host's order) and
    TinyKernelNetwork_test.sh's linux case on the shared, older
    `_make/boot.img` (it passes on a fresh image).
- 2026-10-19: step 2 done, TinyLibHost out (5,000 lines of OCaml,
  2,200 of C and assembly, its README and its two scripts,
  `tiny_lib_trim.py` and `tiny_lib_c.py`; `short_box_header.py` too,
  whose one use was its files). `TinyLibSystem.ml` is in
  `TinyKernel/host/`, beside `TinyCalls`, its dune library with it.
  `tiny/mkfile` is on `lib_core/` only (no `LIB=`, no `_mk/$O/tiny-*`);
  tests/lite.sh builds `tiny` once and runs its programs' tests on
  that build; compile_ix.sh compiles `tiny/` against `TinyKernel/host/`
  and `lib_core/`. t-IX is 18,527 lines without the header comments
  (README's budget: 11,500 left); docs/loc.md has a row.
  - **Checked**: mini-mk in `tiny/` builds the twelve host programs on
    `lib_core/` (a private B, in 11 s), and their tests pass on those
    (tiny-build, -shell, -editor, -db, -vcs, -c, -ml, -cpu, -machine;
    tiny-utils but its `du` case, the host's order, as with dune's);
    compile_ix.sh: 48 of 48 of `tiny/`; dune's tiny-shell, -editor.
  - **tiny-shell on `lib_core/` is 676,910 bytes**, 570,574 on
    TinyLibHost (docs/projects.md, "What is in an executable"; its
    picture, `anatomy.svg`, stays the measure of 2026-10, TinyLibHost's
    column with it: redrawing it needs mini-rc's two builds too).
  - **Not run**: tests/lite.sh's and mkfiles/check.sh's whole builds.
- 2026-10-19: t-IX's budget back to 25,000 (the author: "I think we
  can restore the budget to 25000 LOC with those simplifications");
  README's table: 18,500 of it, 6,500 left.
- 2026-10-19: step 3 done, tiny-assembler and tiny-linker.
  `TinyAssembler.ml` (205 lines) is the assembler that was in
  `TinyMachineCPU.ml`, its items now saying the kind of each place an
  operand goes (a word, an immediate, a half, a branch's offset), and
  the machine's own instructions (csrr...) from
  `TinyMachineDevices.ml`'s extension; `TinyLinker.ml` (135) lays the
  objects out as `assemble_files` did and fills each place by
  decoding the word, setting its immediate, encoding again (encode's
  range checks hold, no table of fields). `TinyMachineCPU.ml` is the
  CPU, the encoding (its instructions now in its .mli) and the
  listing, 270 lines where 440; tiny-cpu and tiny-machine run images
  only (no `-o`, no `-a`, no `.tm`).
  - **The object is text**, a line an item: `label`, `align` (kept:
    v0 aligns on 64 KB, an address's matter), `code HEX` (bytes in the
    memory's order), `reloc OFF KIND TARGET`, `space N`
    (TinyAssembler.mli). Text, for the dialect tiny-ml shares (no
    Marshal) and for reading one.
  - **The symbols are beside the image**, `-map` writing `out.map`
    ("address label" lines), not after it as §6 proposed: after it,
    every image and a.out would have changed, and `boot.img` with them
    (its files' sizes are in `check.expected`). tiny-prof reads the
    maps (`-k kernel.img.map -u bin/www.map`); tiny/TinyKernel's
    Makefile links all with -map. plan_tiny_debugger.md's §4 can put
    them after the image later.
  - **No archive yet**: step 5 needs one (TinyLibCore/), not this one.
  - **Checked, byte for byte** against images made by the old
    assembler (HEAD's tools, in a worktree): tiny-kernel's
    `kernel.img`, its 21 programs and `boot.img`; the steps' hello,
    v0's kernel.img, t6's kernel.img, its nine programs and `fs.img`.
    With tiny-assembler and tiny-linker built by mini-mk too: the same
    `boot.img`. Every tiny/tests/*_test.sh that ran a `.tm` links it
    now by `tiny/tests/link.sh`'s `link_tm`, and passes, with dune's
    tools and (tiny-cpu, -machine, -c, -ml, -prof) with mini-mk's;
    tiny-prof's expected outputs unchanged.
  - **mini-ml's `&&` and `||` are no tail calls** (bugs/ix.md): the
    mini-mk build of tiny-assembler overflowed its stack in
    `String.for_all` on a `.space 262144`; `.space` is now an item of
    its own, and the bug is recorded, not fixed (it changes every
    program mini-ml compiles).
  - **Not run**: make check's sessions (the images are the same
    bytes), tests/lite.sh and mkfiles/check.sh whole.
