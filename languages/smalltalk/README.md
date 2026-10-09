# languages/smalltalk: mini-smalltalk

Smalltalk-80 from the Blue Book, after the author's playground's
`languages/smalltalk` (`~/playground`): the virtual machine in OCaml
(`St_*`: the text read, the chunk format, the object table, the
bytecodes, the compiler, the interpreter, the primitives, the image
saved and loaded, BitBlt in black and white and in colour) and the
system in Smalltalk (`kernel/*.st`, with Squeak's Morphic in
`kernel/squeak/` and a smaller one in `kernel/morphic/`). A command on
Linux (`mini-smalltalk`), Squeak in a window there (`mini-squeak`,
`hosts/sdl/`), under mini-9pi (`hosts/draw/`), and on the bare board:
[`kernels/squeak/`](../../kernels/squeak/README.md). The plan:
[`plan_system_squeak.md`](../../docs/plans/done/plan_system_squeak.md).

Each copied `St_*.ml` says at its top what it is of the playground's
("The playground's, as it is but for its header", or "After the
playground's, made what mini-ml takes:" and what). The lists and the
numbers below are `scripts/playground_copies.sh languages/smalltalk`'s,
against the playground at `028d8abf` (2026-10-06);
`kernels/squeak/survey.sh` has the same count.

## What was copied

65 files, 13,763 lines there and 13,687 here:

- the virtual machine: 15 modules, `St_ast` to `St_primitives`, and
  `St_kernel.mli`;
- the system's text: the 16 files of `kernel/`, 6,547 lines of
  Smalltalk;
- its tests: `tests/Unit_*` (7), `Testutil_morphic` and `Test`.

## What changed

The system's text is the playground's byte for byte, but for one line
of `kernel/Numbers.st`: SmallInteger's largest, 30 bits.

The virtual machine, so that mini-ml compiles it and an arm of 32 bits
runs it (323 lines are not the playground's):

- optional arguments said, or made two functions (`St_interp`'s `run`
  and `run_until`, `evaluate` and `evaluate_with`; `call`'s budget);
- polymorphic variants made one variant (`St_primitives`'s
  arithmetic), `Option.value` written out, `Float`'s functions by
  Pervasives' names, a `String.fold_left` a loop;
- SmallIntegers of 30 bits on every host (`St_lexer`'s bounds), where
  they were 31: an OCaml int of an arm has 31;
- `St_bitblt`, `St_colorblt`: what a copy is asked with is a record
  (mini-ml's functions have seven parameters at most on arm); a pixel
  of 32 bits is held in 31, its alpha on 7.

`St_memory`, `St_chunk`, `St_class` and `St_parse` are the playground's
but for their header. The tests: the license block is ix's two lines,
and what they call is said as above.

## What is ix's own

16 files, 827 lines:

- `CLI`, `Main`: the command.
- `Squeak`: what the three hosts share (the system brought up over a
  host, the world's cycle, the Display's pixels when they changed),
  after the playground's `apps/devtools/TinySqueak.ml`, whose start it
  is.
- `hosts/sdl/`, `hosts/draw/`: a window on Linux, and under mini-9pi.
- `tests/Unit_world`, `tests/differential.sh`, `tests/bench/`.

## What remains in the playground

- `Highlight_st`: Smalltalk's text coloured, for its editors.
- `tests/bench/St_bench`, `tests/js/Test_js`, `tests/Unit_highlight_st`.
- The programs on it: `apps/devtools/TinySmalltalk80.ml` and
  `TinySqueak.ml`, on the playground's library.
