# Plan: DSLs that shrink m-ix and t-ix, where one description can replace code written several times

The author (2026-11-07): "is there any DSL or use of other language
that could significantly reduce the LOC of m-ix (and t-ix)? I've
introduced ML for example because I think it uses less code that C to
express similar ideas. I've also used datalog for mini-analyze for the
same reason. Any other DSL or language that could benefit to IX?"

The short answer: **no other general-purpose language would beat
OCaml here, but three DSLs could pay off. They are a table per
instruction set, a description per byte layout, and IX's own lex and
yacc used in more places.** Each one replaces knowledge that is
written two or three times today (an encoder and a decoder, a reader
and a writer) with one description that several programs read. Each
starts as a pilot and spreads only if the pilot passes a gate. Nothing
of this plan is written yet; its line counts are `wc -l` on
2026-11-07, and its savings are estimates until a pilot measures them.

**Status: not started** (2026-11-07). 2026-11-24: a second question,
on t-ix alone (STEPS, another language, tiny-ml's features), answered
in "t-ix's size, a second look" below.

## How to choose a DSL

A DSL earns its place in IX only if it passes three tests.

1. **One fact, many readers.** The same knowledge is written twice or
   more today, or the domain is naturally rules, relations or
   grammars. Datalog passed for mini-analyze because the analyses are
   relations by nature.
2. **It lives inside IX.** Its interpreter or generator is an IX
   program that a reader can study, and its lines count in the total.
   A DSL whose engine is larger than the code it removes fails.
3. **It reads better than the code it replaces.** IX's goal is a
   system one person can understand. A table that doubles as the
   format's documentation passes. A terse language that saves lines
   but must be decoded by the reader (APL, K, point-free style) fails.

## What there is

| area | where the same knowledge is written | lines | times written |
|---|---|---:|---:|
| ARM32 encoding | `linker/Arm.ml` packs the bits from the linker's ops; `machine/arm32/Arm32_isa.ml` and `Arm32.ml` decode and print them as objdump does | 821, 180 + 700 | 2 |
| ARM64 encoding | `linker/Arm64.ml` packs; `machine/arm64/Arm64.ml` decodes | 869, 1007 | 2 |
| TinyCPU encoding | `tiny/TinyLibMachine.ml` already holds encode, decode and print together (old: `TinyMachineISA.ml`, 141 lines) | about 150 | 1 |
| byte layouts | about 160 `.ml` files read or write bytes by hand: 9P (`lib_networking/9p/P9.ml`, `kernels/9pi/files/P9.ml`, `kernels/9pi/devices/sys/Devmnt.ml`), a.out and ELF, FAT, TCP/IP, USB descriptors, image headers, the doom WAD | spread out | 2 (read and write) |
| parsers written by hand | `browsers/javascript/parsing/Js_parse.ml` 862, `tiny/TinyML/Parser.ml` 643, `tiny/TinyC/Parser.ml` 530, `languages/dotnet/csc/Csc_parser.ml` 435, `assembler/Parser_asm.ml` 349, `languages/smalltalk/compiler/St_parse.ml` 326, `shell/Parser.ml` 251 | about 3,400 | 1, but the grammar is hidden in the code |
| device registers | `raspberry/boards/Board.ml` 1010, `Emmc`, `Usbdwc`, `Devaudio`, tiny-machine's devices | to measure | 2 (the driver and the emulated device) |

IX already has `generators/lex` and `generators/yacc`, and m-ix already
uses `.mll` and `.mly` files for C, ML, Tiger, SQL and acid.

TinyCPU is not a candidate. Its encoder, decoder and printer are about
70 lines in one file, and a table plus its interpreter would not be
shorter.

## Stage 1: one table per ARM instruction set

Each instruction set gets one description, and the encoder, the
decoder and the printer are derived from it. The model is Ramsey and
Fernández's New Jersey Machine-Code Toolkit (SLED, 1997). ARM's own
ASL specifications are built the same way.

A row holds the mnemonic, its fixed bits, its fields with their bit
positions, its printed syntax, and the constraints on its operands
(for example ARM's 8-bit rotated immediates). What an instruction does
when it runs stays ordinary OCaml code in `Arm32.ml`, matched on the
decoded variant.

The table is an OCaml value with a small interpreter beside it, not a
new syntax. That way there is no generator step in the build, and the
bit diagrams in headers such as `Arm32.mli` can point at the table,
which is the layout itself.

The linker's two jobs are kept apart. Choosing which instructions
implement a Plan 9 op (`MOVW` of a large constant, `CASE`) stays in
`linker/Arm.ml`. Only the final bit packing moves to the table, so the
linker produces `Arm32_isa` values and encodes them through it.

1. Measure first. Count how much of `linker/Arm.ml` is bit packing and
   how much is instruction choice. If the packing is under about 200
   lines, the saving is too small and the stage stops here.
2. Pilot on one class, data processing (the barrel shifter included),
   in both directions. The check is that mini-cc and mini-ld still
   produce byte-identical binaries, and that `Arm32_isa`'s objdump test
   over `machine/tests/words_arm.txt` still passes.
3. If the pilot passes the gate, do the other classes, then arm64 in
   the same way.

## Stage 2: one description per byte layout

A small library of codec combinators lets one description of a layout
give both the reader and the writer. The ideas come from Kaitai Struct
and from bidirectional parsing. The saving is spread over many files.
It also removes the bugs where a reader and its writer disagree.

A layout is a value built from pieces such as `u8`, `u16le`, `u32le`,
`string16` (a 2-byte length, then the bytes), `bytes n`, lists, and a
choice keyed by a type byte. Run one way, it decodes bytes into an
OCaml record; run the other way, it encodes the record into bytes.

1. Write the library in `lib_core/`. If t-ix needs it, it gets its own
   copy in `tiny/TinyLibCore/`, because t-ix stays self-contained.
2. Pilot on 9P. Its messages are a tagged union of a few dozen
   layouts, and they are written today in the three files of the table
   above. The check is that mini-9pi still boots and mounts.
3. Then a.out and ELF (shared by the linker, the loader and the
   debugger), FAT, and the TCP/IP headers, in that order, each only
   where the description reads better than the code it replaces.

Layouts that are not plain records stay written by hand. That covers
lengths computed after the payload, checksums, and bit-packed fields.

## Stage 3: grammars through IX's own lex and yacc

Large grammars move to `.mll` and `.mly` files built by
`generators/lex` and `generators/yacc`. The generators are already
part of IX, so a reader has nothing new to learn. The payoff is
moderate, because a good recursive-descent parser is often about as
long as the grammar plus its actions, and it is easier to step
through.

A parser is converted only when its grammar has many productions and
precedence levels, as JS's and ML's do. The shell's and the
assembler's grammars are small and stay written by hand.

1. In m-ix, convert `Js_parse.ml` first. Convert `Csc_parser.ml` and
   `St_parse.ml` only if the JS conversion is clearly shorter.
2. In t-ix, make tiny-yacc and tiny-lex emit code in the subset that
   tiny-ml compiles, and that mini-ml builds too. Then convert
   `TinyML/Parser.ml` and `TinyC/Parser.ml`.
3. Error messages must be at least as good as today's. Hand-written
   parsers usually report errors better, and losing that would be a
   regression.

## The gate

Each pilot is measured before it spreads. A failed gate is a useful
result too: the code stays written by hand, and the reason goes in
this plan.

- Lines: the DSL's engine plus its tables, compared with the code they
  replace. The engine counts in full.
- Readability: the table or the grammar is the best place to learn
  the format, and it can replace the header comments that described
  the format before.
- Output: mini-cc and mini-ld produce byte-identical binaries,
  mini-9pi boots, and `make test`, `tiny_check.sh` and
  `make -C tiny/TinyKernel check` pass.

## Smaller candidates, after the three stages

These are worth trying only once the stages above show that the
approach pays off in IX.

| candidate | where | why it might pay | expected gain |
|---|---|---|---|
| device register tables, like ARM's SVD files | `raspberry/boards/Board.ml`, `Emmc`, `Usbdwc`, `Devaudio`, tiny-machine's devices | offsets, fields and access modes written once, for the driver and for the emulated device | modest |
| more Datalog | mk's and tiny-build's dependency closure, the linker's reachable symbols, a VCS merge base | the engine is already in IX, and a merge base is a two-rule program | small in lines, larger in clarity |
| BURG-style instruction selection | mini-cc's backend, TinyC's and TinyML's lowering | tree patterns with costs replace hand-ordered `match` cases | only if a backend grows (arm64, more peepholes) |
| one stack machine for tiny-cc and tiny-ml | `tiny/TinyC/Machine.ml` 472 and `tiny/TinyML/Machine.ml` 573: two stack machines turned into the same CPU's assembly, each with its stack slots in registers | tiny-cc's `Lower` would emit tiny-ml's `ir`; one `Machine` left | 300 to 400 lines, if their differences (C's variables in registers, ML's value stack for the collector) fit one `ir`; to measure by reading both side by side |

## t-ix's size, a second look (2026-11-24)

The author (2026-11-24): "is there any way we could make tiny/ use
less LOC while still maintaining the same feature set and also speed?
Should we use another language than ML? Could we add features to
tiny-ml that we could then use in the code of tiny/ to reduce overall
the LOC? any DSLs to invent or reuse to factorize code? to reduce
significantly the code? The STEPS project from Alan Kay had the goal
of 10 000 LOC with a full system".

The short answer: **at the same features and speed, about 5 to 10% of
t-ix's code can go, not more**. The rest of this plan stays the way to
get it. The numbers are `scripts/stats/loc.py` on 2026-11-24:

    40,297 lines in t-ix:  24,491 code, 12,774 comments, 3,032 blank

The comments are the teaching, not a target. The code is already
dense: the CPU, TinyLibMachine and tiny-rc, read for this answer, have
little to remove, and the instruction set is already a table.

**STEPS.** Its count was of what ran on a host (Squeak's VM, an OS
underneath), and its large ratios came from a few domains with a
mathematical core: Nile, where Cairo's rendering became a few hundred
lines of stream processing, and OMeta for grammars. As far as I know
(its reports not read again for this), it did not end with a whole
self-hosted system at its number. t-ix holds, in 24.5k lines of code, a
CPU and its machine, a kernel, two compilers, a collector, a browser
and an office. It is in STEPS' range already. STEPS' other lever was
to redefine a feature (Nile is not Cairo ported), which this question
excludes.

**Another language.** No, for the reasons of "What not to do" and one
more of t-ix's own: every tiny file builds with OCaml 4.14 and with
tiny-ml, and the kernel and the compilers are in ML. A dynamic
language would save tiny-ml's type checker (`TinyML/Types.ml`, about
500 lines) and lose speed and OCaml's check.

**Features in tiny-ml.** A file of tiny/ is also OCaml's, so tiny-ml
can only take a feature OCaml has. Those it leaves out (TinyML.mli's
list) are or-patterns that bind names, character ranges, functors,
labeled arguments, nested modules, inline records. Each would shorten
a few matches of the lexers and the kernel: under 1 to 2% together,
less what tiny-ml grows to compile them. `[@@deriving show]` would
need a ppx on OCaml's side. Not a lever.

**What can go**, in the order to try:

1. One stack machine for tiny-cc and tiny-ml (the row above, "Smaller
   candidates"): 300 to 400 lines, if the pilot shows their `ir`s can
   be one.
2. Stage 3 for t-ix, with a second way next to tiny-yacc: a Pratt
   parser for the expressions of `TinyML/Parser.ml` (781) and
   `TinyC/Parser.ml` (585), and perhaps a few combinators shared by
   the smaller parsers (tiny-rc's, HTML's, SQL's, the Buildfile's,
   troff's, about 3,000 lines with the lexers). Plain OCaml, so no new
   step in the build. Combinators make a closure per call in tiny-ml:
   tiny-ml's own build on tiny-kernel is the speed check, Pratt
   parsing (a loop and a table of precedences) the safe part.
3. Not again: the system-call glue (`runtime/c/sys.s`, about 30 stubs
   of seven lines, and `runtime/ml/mlsys.c`'s 30 `u_xxx`), proposed
   again on 2026-11-24 for 300 to 450 lines; "What not to do" below
   keeps its readable repetition, unless the author decides otherwise.
4. Not either: `runtime/ml/ml.c`'s Marshal, SHA-1, Hashtbl and compare
   (1,340 lines with the collector) are in C for speed; in ML they
   would be shorter and slower.

## What not to do

- **Another general-purpose language.** Lisp, Scheme or Haskell would
  save little over OCaml, and APL or K would fail the readability
  test.
- **Prolog or miniKanren for type checking.** The unifier in
  `TinyML/Types.ml` is already short.
- **A layout or constraint DSL for the GUI apps.** The Elm-style
  playground already carries most of that weight.
- **Generated stubs for the system-call glue** (`sys.s`, `mlsys.c`).
  Readable repetition was already chosen over that mechanism.
- **One DSL engine shared by m-ix and t-ix.** t-ix stays
  self-contained, so it gets its own copy if it needs one.

## Risks

- The engine grows to cover every exception. Odd cases stay written by
  hand instead of extending the DSL.
- tiny-ml cannot compile the generated or table-driven code. This is
  checked with mini-ml at each pilot, not at the end.
- A decoder that interprets a table is slower in mini-qemu's inner
  loop. If so, the fix is in the general mechanism (decode once and
  keep the result, as `Arm32_fast.ml` and TinyMachineCPU's
  `keep_decoded` already do), not a rewrite of one function.
- Generated parsers report worse errors. Stage 3's gate includes them.
