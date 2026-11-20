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
[notes_tiny_spirit.md](../../notes/notes_tiny_spirit.md): arm64 kept (its §3) and
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
   the disk) under `/src` (not Plan 9's `/sys/src`: `/sys` is
   principia's devsys, the system's state, as Linux's); tiny-build's mkfile for
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
- 2026-10-19: step 4 done, units in tiny-ml, as decided with the
  author (an interface the compiler writes, the link's sweep, the
  sums recorded again where they move):
  - **A file is a unit**: its symbols prefixed with its name
    (TinyLibGUI.f12_layout, TinyLibGUI.L40, TinyLibGUI.s3), its
    toplevel in <unit>.init, its computed values in <unit>.globals.
    `tiny-ml -c [x.tmi...] f.ml` writes f.tm and f.tmi, the interface
    (OCaml's .cmi: the program's types, constructors, labels so far;
    each name, where its value is and its type, f.mli's when there is
    one, its vals read and the rest skipped; the curry functions it
    needs; its globals' count). `tiny-ml -o main.tm x.tmi...` writes
    the main: ml_start, the prelude (Stdlib, compiled in every run of
    tiny-ml the same way, so its labels agree), each unit's init in
    order in the handler of uncaught exceptions, the curry functions,
    the tables one after the other as ml_globals (core.c's roots).
    `tiny-ml -o prog.tm a.ml b.ml`, the old command line, is the same
    in one run: the units, then their main.
  - **Names stay one name space**, as when a program was its files
    compiled whole: `M.x` is a name (TinyLibStd's `String.trim`,
    libml's `TinyLibSystem.fork`), `open M` is read and left, a
    record's label is the latest record's unless the type says which
    (OCaml's rule; it was an error), and `M.t` in a type is `t` when M
    is a unit read. Not done: M's names visible only as `M.x` or after
    `open M` (§6's "open M really opens"); OCaml checks the scopes of
    the files both compile, and the files only tiny-ml compiles
    (libml/, user/, memory.ml) would need their opens. So a unit sees
    exactly the units its program had before it: tiny/TinyKernel's
    Makefile gives each its list (I_<unit>, the shortest of its
    programs': TinyLibGUI after Calls, TinyLibDraw, TinyLibPlayground)
    and each program its units in their old order (UNITS_<program>).
  - **The link leaves out what nothing reaches** (TinyLinker's sweep):
    tiny-ml marks each function and static block `.piece`; a piece is
    kept when an object without pieces (the C runtime, the start, a
    main's start) reaches it, through the relocs. It replaces prune:
    without either, calc was 213 KB, emacs 299 KB, www 391 KB and
    office over 384 KB, where mlsys.c's heap starts; with the sweep,
    each program is within 1.2% of its pruned size (calc 154,572
    bytes, 153,768 before; www 324,152, 323,252; office 363,548,
    362,704; troff 266,340, 263,100), what prune dropped and the sweep
    keeps being a unit's constants and the values its init computes.
  - **tiny-kernel's 14 programs in ML are built a unit at a time**
    (_make/ml/, each unit once, shared: TinyLibGUI's object is calc's,
    temp's, emacs's...); the kernel stays a program compiled whole (one
    program, nothing to share). mlsys.c calls ml_start by a jal, 128
    KB: a program's main is linked right after it.
  - **Tests**: TinyML_test.sh's units (TinyML_tests/units/: Shapes,
    with an .mli, and Main, compiled apart, linked, their output; and
    whole; Shapes's unused function not in the map), its forgotten
    check compiling both files as x.ml (a unit's name is in its
    symbols); every tiny/tests/*_test.sh that runs tiny-ml passes;
    with mini-mk's tiny-ml too.
  - **make check**, on tiny-kernel built this way: its 23 screens the
    same; check.expected the same but the programs' sizes in its ls -l
    lines (recorded again); the two sounds recorded again: play's the
    same samples, 5 later (a program's instructions are others), and
    tetris's the same length, its first sound at the same sample, all
    the same but two stretches of 687 and 643 samples (86 ms each),
    where a sound effect meets the tune a little later.
  - **Lines**: TinyML.ml 1,753 (+177), TinyLinker.ml 166 (+31); t-IX
    18,880 without the header comments (README's budget: 6,100 left).
- 2026-10-19: step 5, its first half: a unit is a module (the author:
  "let's do it", on scoping first, as a commit of its own). A unit's
  names are M.x in the units after it, x after open M (for that unit
  alone: what it opens it does not export); a name with a dot already
  is as written (TinyLibStd's String.trim, libml's TinyLibSystem.fork:
  they go with step 5's modules); Stdlib is open in every unit, and
  TinyLibStd until it is TinyLibCore/'s modules. The types, the
  constructors and the labels stay the program's, one name space. The
  interfaces carry M.x. Two files renamed to the modules the others
  open, as the host's are named: TinyKernel/memory.ml is
  TinyMemory.ml, libml/calls.ml is TinyCalls.ml; libml/TinyLibSystem.ml
  opens TinyCalls; the browser's test says TinyBrowser.create (it
  could not before); tiny/TinyKernel's Makefile names each unit as a
  static pattern's target (make uses an implicit rule once in a chain,
  and a unit's interface is another's prerequisite). Every other file
  already had the opens OCaml asks for. tiny-kernel's kernel and 12
  of its programs the same bytes as at step 4; TinyML_test.sh checks
  Shapes.area, and area unbound without open Shapes.
- 2026-10-19: step 5 done, TinyLibCore/ as modules. Stdlib (the
  operators and the runtime's externals, option, the exceptions,
  failwith..., int_of_string_opt), Char, List, String, Bytes, Array,
  Option, Filename, Buffer, Hashtbl, and ix's Common (|||, which OCaml's
  files get from lib_core's) and Sha1 (lib_crypto's string and to_hex,
  for tiny-build and tiny-vcs): a file and its .mli each, from
  TinyLibCore.ml and TinyLibStd.ml, which are gone, as is the scoping's
  exception for a name with a dot (libml/TinyLibSystem.ml defines fork,
  not TinyLibSystem.fork). The compiler carries their text
  (TinyMLPrelude.ml's modules, tiny/dune's and tiny/mkfile's rule) and
  compiles them as the first units of every program, in every run the
  same way, so their labels agree; each main has them, and the sweep
  keeps what the program calls: §6's lib.a, without an archive (the
  linker has none yet: not needed while the library is in every main).
  - **Hashtbl** is an array of buckets, a key's by core.c's ml_hash
    (its integers, its strings' bytes, its blocks' tags and fields, ten
    values at most; never an address, which the collector changes),
    twice as many when twice as many bindings; add and remove as
    OCaml's (a binding hidden, then shown again). **Buffer** is bytes
    that double, from 256 at most (create's size is a guess, and a
    partition 1 MB). **Sha1** computes on words as two halves of 16.
  - **The API is OCaml's, checked by OCaml**: TinyLibCore_test.sh
    (TinyLibStd_test.sh before) has OCaml compile module _ : sig <the
    .mli> end = struct include List end for each module but Common and
    Sha1 (Hashtbl's create without its ?random); std.ml's lines on
    both (Buffer past its bytes, Hashtbl past its buckets, add and
    remove), and Sha1's digests against sha1sum's (the padding's edges,
    a long text): all the same, the first time.
  - **make check**: the screens the same but tetris's, whose pieces
    come from u_ticks at its start: the modules' inits make it start a
    tick later, another seed, other pieces (the same score and rows);
    its sum, the two sounds' (play's samples later), the programs'
    sizes (1% to 3% larger: the inits, the real Hashtbl and Buffer;
    office 368 KB of its 384) and the trace of get on a wire that loses
    its 7th packet recorded again: get starts later, the machine sends
    its sync twice before the answer, and the 7th is then the second
    sync, not a data packet (the same transfer, nothing sent again).
  - **Lines**: TinyLibCore/ 558 (TinyLibCore.ml and TinyLibStd.ml were
    280); t-IX 19,164 without the header comments (README's budget:
    5,800 left).
  - **Not done**: archives in tiny-linker (with the library in every
    main, nothing needs one yet).
- 2026-10-19: step 6 done, the small ports. tiny-prof, tiny-db,
  tiny-vcs and tiny-build are each one file that OCaml and tiny-ml
  both build, on TinyLibSystem's two sides, and tiny-kernel's `/bin`
  has them as `prof`, `db`, `vcs` and `build`. Each has a line of
  `make check`: prof on `spin.prof`, a profile tiny-cpu writes when
  the image is made; the other three a session typed at the console
  (`TinyKernel_tests/db.keys`, `vcs.keys`, `build.keys`).
  - **What the dialect asked of the four files**: no Printf (a format
    is a concatenation), no `{|...|}`, no character ranges in a
    pattern, no or-pattern with names in its alternatives, no inline
    record, no labels (each written again plainly, `(* old: *)` saying
    what it was); tiny-db's 8-byte integers by hand (Int64's before:
    a number past 31 bits that OCaml wrote is read as its low bits on
    tiny-ml); **no Zlib in tiny-vcs**, whose store is the objects'
    text (a repository of the old tiny-vcs is not read).
  - **tiny-ml**: a type abbreviation with parameters (Seq's `'a t`;
    one is known by its name and its number of parameters, so Sha1's
    `t` and Seq's `'a t` are two), `M.C` read as `C` (constructors are
    one name space), and a closure of more than eight names made
    blank, then filled a field at a time (tiny-db's `parse`: ten
    names, more than the registers; bugs/ix.md). TinyML_test.sh's
    units have all three.
  - **TinyLibCore/**: `Seq` (lazy: a `take` stops tiny-db's walk of
    its tree), and what the four call, each line in std.ml, OCaml's
    output and tiny-cpu's the same: List's find_opt, mem_assoc, iter2,
    rev_map, stable_sort, remove_assoc, sort_uniq, memq, partition,
    filter_map, to_seq, of_seq; Array's init, sub, copy, map, append,
    concat, iter, of_list, to_list, to_seq; Hashtbl's find_all, copy;
    Bytes's blit, sub_string; String.iteri; Option's iter, map,
    to_list; Filename.dirname (OCaml's, its slashes); int_of_string.
    `stable_sort` is a function, not `= sort`: a value computed at
    the init kept `sort` in every program (2.8 KB).
  - **TinyLibSystem**: open_rw, seek, seek_end, time, is_executable,
    set_executable, wait_any, shell; `main` says a Failure after the
    program's name and exits 1 (tiny-prof ended on an uncaught
    exception for a missing file). On tiny-kernel: `>>` works (an
    open, then a seek to the end; rc said "tiny-kernel has no >>"),
    `time` is 0 (no clock of the day: commits are dated 0), no file
    is executable, and `shell` runs a recipe by rc -e, from a file
    that rc reads whole and removes first (an argument has 64 bytes
    at most, and there is no environment: the variables are rc's
    assignments before it). A recipe is in its system's shell.
  - **tiny-kernel**: a call 24, `seek`; ^D ends a read of the console
    with nothing read, unless the console is raw (emacs's C-d); a file
    in memory is bytes that double, not a string made again at each
    write: tiny-db took a second of the machine's time a statement,
    found with tiny-prof (40 inserts: 302 million instructions, 67% of
    them the kernel's copies; 65 million after, with `seek` reading a
    file's size, not its contents); the kernel's map 3 MB higher, the
    image's limit 7.5 MB (it is 4.7 MB with the four programs).
  - **What they print differently**: tiny-vcs's log takes commits of
    the same date breadth first (a branch's first commit came before
    its second; on tiny-kernel all the dates are 0); tiny-db refuses
    a short file that is not a database (it wrote its header over a
    file under 16 bytes; bugs/ix.md); tiny-build gives a recipe the
    Buildfile's variables before the environment's.
  - **Checked**: the host's tests of the four (tiny-db's 40 sessions
    against SQLite, tiny-vcs's, tiny-build's, tiny-prof's), built by
    dune and by mini-mk (mini-ml); TinyML_test.sh, TinyLibCore_test.sh
    and every tiny/tests/*_test.sh (but TinyUtilities' `du`, the
    host's order, as before); the network's Linux checks on the new
    image; db's rows on tiny-kernel and its file (36,352 bytes) the
    host's, vcs's hashes the host's (date 0, author nobody). make
    check's text recorded again: the four's lines, `>>`, /bin's
    programs and sizes, a trap's address, the lossy wire's trace (its
    other variant: which packet is the 7th moves with the programs'
    sizes). The 23 screens the same but tetris's (its seed is u_ticks
    at its start: other pieces, a sane game); its sum and the two
    sounds' recorded again, from a fresh build (they move with the
    timing: two builds 3 KB apart gave two others).
  - **TinyKernel/Makefile**: what tiny-ml compiles (the kernel, each
    unit, each main) depends on tiny-ml itself when TML is a path, as
    ../../tiny-machine gives it: its binary carries TinyLibCore/, and
    a change there left a program's units made before on the old
    library (found when emacs came out 2.9 KB larger in a build made
    over an older one than in a fresh one).
  - **Open**: `build -j 3` on tiny-kernel hangs when the 8 process
    slots run out under recipes that are pipelines (bugs/ix.md); `-j
    3` with recipes of one command builds.
  - **Lines**: TinyLibCore/ 703 (+145); TinyML.ml 1,812; the four
    files 1,803 (+93: Printf, the help strings and Int64 written out); t-IX
    19,863 without the header comments (README's budget: 5,100 left).
  - **Not run**: tests/lite.sh and mkfiles/check.sh whole.
- 2026-10-19: step 7 done, the toolchain on tiny-kernel. tiny-assembler,
  tiny-linker, tiny-c and tiny-ml are each in the dialect OCaml and
  tiny-ml share, and tiny-kernel's `/bin` has them as `as`, `ld`, `cc`
  and `ml` (16 MB each, `ml` 32). Each makes the host's files, byte
  for byte: `/bin/ping` from ping.c (cc, as, ld), core.c's runtime,
  libc.c, and TinyML.ml compiled by `ml` itself (its `.tm` of 1.3 MB
  and its `.tmi`, 11 minutes of the machine's time). The check:
  `TinyKernel_tests/toolchain.keys`, ping made again from `/src`, and a
  unit (TinyMachineISA) compiled by `ml` and assembled by `as`, against
  the host's `.tm`, `.tmi` and `.o` in `/examples`.
  - **tiny-cpu is not ported.** Its CPU is 32-bit arithmetic on ints
    and OCaml's 32-bit loads, the machine's speed; on tiny-ml's 31
    bits it would be another interpreter, and nothing of steps 7 and 8
    runs it. The words tiny-assembler and tiny-linker make are now
    `TinyMachine/TinyMachineISA.ml`'s (the instructions, encode,
    decode, the registers of control's names), a file of the dialect;
    `TinyMachineCPU.ml` keeps the interpreter.
  - **32 bits on 31.** The assembler reads a number as its word's two
    halves of 16 (tiny-ml's code has 2147483647, a tagged max_int,
    and its strings' words); the linker writes a word from an int by
    its bytes. tiny-c's constants are Int64's, a new module of
    TinyLibCore (four pieces of 16, a type named `int64` as OCaml
    names it: `t` is Sha1's, see bugs/ix.md); tiny-ml's are Int64's
    too, a word printed as its low 32 bits (old: Int64.to_int32).
  - **tiny-ml**: `{|...|}` read (the author: "I'd rather add 10 lines
    in tiny-ml ... than having all those horrible help string
    concatenation expressions"), so every help is one again, step 6's
    four included, and the prelude's rule is as before; `fun x ->
    function ...` one function of both, as OCaml's (List.length's
    `len n = function`, a closure an element: half the time of `ml`
    on tiny-kernel); the names a let adds counted once, not at each
    name (quadratic in the prelude's names); an interface's
    constructors and labels by name (two builds gave two orders);
    Stdlib's `'a ref` is OCaml's record `{ mutable contents }`, which
    its type checker matches on; or-patterns with names, Printf (a
    script turned 176 of them into concatenations, tiny-ml evaluating
    right to left as OCaml), Queue (two lists), character ranges,
    `assert` written again.
  - **TinyLibCore**: Int64, List's find, find_map, rev_append, combine,
    for_all2, String.index, Filename's basename, chop_suffix,
    remove_extension, is_relative, Bytes.of_string, Division_by_zero
    (each in std.ml, OCaml's output and tiny-cpu's the same). Faster
    for every program: String.concat and String.init make their
    result once (they joined two by two), Buffer copies once when it
    grows, libml's read_all joins its pieces at the end.
  - **tiny-kernel**: its heap two halves of 8 MB at 16 MB (they were 1
    MB at 8 MB: a file written lives there, and TinyML.ml's object is
    1.3 MB), the partitions from 32 MB (95 MB for 8 processes);
    mlsys.c's stack of values after the program when it is past 384
    KB (end.tm's `_end`, linked last: `ml` is 534 KB; the Makefile's
    384 KB limit gone), a sixteenth of a larger partition, and its
    overflow said (`Fatal error: stack overflow`; it ran into the heap
    unseen: bugs/ix.md); `cmp` reads its files a piece at a time
    (whole, it needed more than utils's 1 MB for a compiler's output);
    tiny-machine writes its `-prof` at a SIGTERM too, to profile a run
    of minutes.
  - **make check**: check.expected recorded again (95 MB, `/src`, the
    programs' sizes, the toolchain's lines, the lossy wire's trace in
    a third variant); the screens of windows and nested (`ls` shows
    `/src`), play (its square blinks by frames: another frame) and
    tetris (another seed), and the two sounds, recorded again. The 19
    other screens the same.
  - **Checked**: every tiny/tests/*_test.sh but TinyUtilities' `du`
    (as before), the network's on the new image; TinyCPU_test,
    TinyC_test, TinyML_test and TinyLibCore_test on mini-mk's builds
    too; compile_ix.sh tiny 51 of 51.
  - **Lines**: t-IX 20,345 (+482: Int64, TinyMachineISA, the
    assembler's numbers, the overflow check); README's budget: 4,700
    left.
  - **Not run**: tests/lite.sh and mkfiles/check.sh whole.
- 2026-10-20: step 8, the system from its sources: tiny-kernel builds
  its own image. The sources are in the image under `/src` (1.1 MB,
  every file the build reads and the `.mli` beside each `.ml`; not
  `/sys/src`: the author, "let's not use /sys under t-ix", `/sys` being
  principia's devsys), the library's interfaces and objects under
  `/lib/ml`, and `/src/TinyKernel/Buildfile`, tiny-build's rules, which
  `TinyKernel/Makefile` writes from its own lists (one description of
  the build; rc's recipes, `/bin`'s ml, as, ld and cc). `make self`
  boots on a blank 64 MB disk, builds the image in `/usr/glenda/self`
  (`self.keys`), then a comment added to a module and a line to calc,
  and reads the image off the disk (`TinyKernelFS_tests/Cat`) to
  compare it with the host's.
  - **TinyLibCore compiled once**, as units (§6's design; the author
    chose it over the embedded library): tiny-ml reads its interfaces
    from `/lib/ml` (`-L`, `-nostdlib`); TinyMLPrelude.ml gone.
  - **tiny-ml made faster, by root causes** (the author: "let's
    speedup tiny-ml if most of the time is spent there"; "do not add
    optimisation hack for things that are not the root cause"):
    the toplevel's names in hash tables, the locals a list (Stdlib's
    names were at the end of one list: "using Hashtbl instead of List
    makes sense"); keywords and symbols in tables; an interface with
    its unit's own types only, as OCaml's `.cmi` (each repeated all
    the program's: 310 KB of interfaces to 152 KB); the interfaces
    marshalled (TinyLibCore's Marshal, OCaml's format, in C in the
    runtime: the host's OCaml and tiny-kernel write the same bytes;
    the author: "maybe we should add one (in C or whatever) to
    tiny-ml ... if it helps improve the speed of the program and also
    clarity"); a function's text into one buffer. A unit of one line:
    47 s on tiny-kernel at the step's start, 2.2 s now; TinyML.ml:
    11 minutes (step 7), 151 s before Marshal.
  - **Printf in tiny-ml again**, read by the parser as the
    `String.concat` it makes (the type checker sees no format); 145
    chains of `^` written as Printf again ("the code is clearer
    indeed"); String.concat a primitive of the runtime (in ML it cost
    more than the `^` it replaced).
  - **tiny-kernel**: the image up to 10 MB (the value stack, the frames
    and the packet above it); names of 64 bytes and a date on each file
    (the author: "the filesystem should have dates, and allow filenames
    of 64 characters"), in memory and on the disk (TinyKernelFS: the
    inode's date, 68-byte entries, a new magic); a date at -56(r0)
    (seconds since 2000: 31 bits hold them until 2034), calls 25 `time`
    and 26 `stat` (`ls -l /bin` read its directory three times a name:
    7 minutes once the entries doubled, 4 s now, with a listing made
    once and not quadratically); exec takes 64 arguments, paths of 1
    KB, and zeroes no partition (only the image written; a comment
    says it shows another process's bytes, to revisit for security,
    "zero what's needed"), its arguments' ending 0 written (it had
    come from the zeroed partition: bugs/ix.md); `k_copy` and `k_zero`
    in memory.tm ("so entry.tm remain small"); ld 32 MB (office's link
    needs 8 MB).
  - **tiny-build** reads a file once a run, and not at all when its
    size and date are those it recorded with its digest (git's index,
    its "racy" rule).
  - **make check**: the machine's date fixed (`-date`); what moves with
    the code and the timing masked before the diff (a program's size,
    a trap's address, a ping's time, tiny-vcs's hashes; the lossy
    wire's trace kept as the fact that a packet was lost); the author:
    "if those tests constant change because the size of binaries
    constantly change, maybe we should just mask those size". Still
    recorded again at most builds: tetris's screen (its seed is the
    clock) and the two sounds' sums.
  - **The first build on tiny-kernel** (the tree before the dates and
    Marshal): 94 files made, the kernel's image, the C runtime, the
    library, the units and mains it reached and sh, rc and emacs, each
    the host's byte for byte; then ld ran out of memory at office (16
    MB, now 32). The whole build on the final tree: below.
  - **What the whole builds found** (the author: "What other things
    we could do to significantly reduce this 5h 30 time?"): SHA-1 in
    the runtime, in C (tiny-build digests every file, and in ML, a
    word as two halves of 16, it ran at 2.6 KB a second: about 3.8 of
    the 5.5 hours); interfaces marshalled with `No_sharing` (which of
    two equal names is one string depends on a table's order, and 3 of
    the 40 interfaces differed from the host's; lib_core's Marshal
    honours it too, its reader no more out of bounds); as 32 MB
    (TinyML.tm's assembly); tiny-build's stamps saved after each recipe
    (a build killed began again from nothing); a file digested as it
    is read, 4 KB at a time (`Sha1.reads`: tiny-build, in 16 MB, read
    boot.img's 8 MB whole and ran out of memory after the image and in
    every build after it: bugs/ix.md); `-t`, each recipe's time.
  - **The whole build on tiny-kernel** (2026-10-20, the tree of
    a2da2e93): the 29 programs and the image in about 2 h 16 of the
    host's time (the session 2 h 36 with the builds after it); the
    image read off the disk the host's byte for byte (7,938,333
    bytes), and of the 261 files it made 258 the host's, the 3 others
    calc's, changed by the test on purpose. Its later builds stopped
    on the digest's out of memory (above). With the fix, `make self`
    whole (2026-10-21, 2 h 57 of the host's time): the image again the
    host's byte for byte (8,001,567 bytes); the comment made the unit
    compiled again and the image made again (the sources are in it),
    nothing else; calc's line its unit compiled, assembled, calc linked
    and the image made; then "boot.img is up to date". `self.expected`
    recorded from it.
  - **Where the time goes** (`build -t`, 2026-10-21, tiny-kernel's
    clock: 3 h 10 of the machine's, 2 h 20 of the host's): the links
    33% (29, ml's 646 s, troff's 420), the assembly 31% (TinyML.o 357
    s, twice its compilation), tiny-ml's compilations 16%, tiny-build
    itself between recipes 12% (23 minutes: digests, the graph, forks),
    the two images 7%. tiny-ml is no longer the first cost: ld and as
    are, each link reading the library's 16 objects again.
  - **Left**: as and ld made faster, by their root causes (to be
    profiled first, `prof` on one link); tiny-build's 23 minutes;
    several cores (plan_tiny_multicore.md). (Done since: make check's
    `printf '\x27'` lines, which needed bash, `\047` now, ad781950;
    tetris's screen and the two sounds' sums, which make check recorded
    again at most builds, steady now: the machine's `-seed` for the
    game, `-audio` from the first sound to the last.)
  - **Bugs** (bugs/ix.md): a name of more than 19 bytes hung `ls`;
    exec's arguments past 15 dropped unsaid; the arguments' ending 0.
  - **Checked**: every tiny/tests/*_test.sh (TinyUtilities' 166 cases
    all, its `du` failure gone), TinyML's, TinyC's and TinyLibCore's
    tests on mini-mk's build too (its `bin/mini-ld` link is broken in
    this checkout, another session's: dune's linker given instead),
    compile_ix.sh tiny 51 of 51, the network's Linux checks, make
    check's text, 23 screens and sounds, run in parts on the final
    image.
  - **Lines**: t-IX 21,003 (+658 since step 7: Marshal's C, the dates,
    stat, the Printf expansion, the tables); README's budget: 4,000
    left. Several cores: plan_tiny_multicore.md, written.
- 2026-10-21: **done**, the eight steps: t-IX on tiny-machine alone,
  and tiny-kernel building its own image, the host's byte for byte
  (`make self`). What is left is step 8's **Left** above: as and ld
  faster, tiny-build's time between recipes, several cores.
