# editors/drscheme: mini-drscheme

DrScheme in small: a program's text above, a prompt below, Run, and
Beginning Student's stepper. The author's playground's
`apps/devtools/TinyDrScheme.ml` (`~/playground`), on mini-scheme
(`languages/scheme/`), `lib_gui/` and `lib_playground/`. Its name here
is ix's: a mini-xxx, as mini-squeak (a tiny-xxx of ix's is one of
`tiny/`'s files), its main `DrScheme.ml`, its parts the `DrScheme_*`
units (`DrScheme.mli` draws them).

On Linux it is built by dune twice: `bin/mini-drscheme`, in a window
(`sdl/`: the same text with `lib_playground/platforms/sdl`), and
`DrScheme.exe`, with the platform that writes a frame to a file
(`tests/frames.sh`), both over the library of its parts. On mini-9pi it
is built by the `mkfile`, `drscheme` there, in a window of mini-rio's or
on the bare screen.

    bin/mini-drscheme            a window of 1000 by 1000 (the screen's height if less), which may be given another size
    bin/mini-drscheme size=1000  the playground's own size

Control-T or the Execute button runs the definitions, Enter at the
prompt evaluates what was typed, Step opens the stepper; Control-Q or
closing the window ends it (`-h` says them). The plan:
[`plan_scheme.md`](../../docs/plans/done/plan_scheme.md).

The numbers below are `scripts/playground_copies.sh editors/drscheme`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

One file, the playground's `TinyDrScheme.ml` (783 lines), split in six
by its sections, past the 700 lines of a module: `DrScheme.ml` and
`DrScheme_{model,draw,run,update,view}.ml`, each `ix:` line saying which
part is there. Its text is the playground's, the code's lines moved and
not changed: what it leaves unused stays. The script compares each file
with the whole of the playground's, so its numbers of lines gone say
only how much is elsewhere.

## What changed

What is not the playground's (the files' `ix:` lines say them):

- its last lines are ix's: `Playground_platform.run_app` given the
  flags and the capabilities, `-h` and its help (the header's sentences
  on the keys, moved there), a wrong word on the command line said in a
  line;
- the machine's fuel and the stepper's limit are said, where they were
  optional;
- a string's characters are taken without a `Seq`, an `Option.value` is
  written out, `text_view`'s x and y are a pair;
- Enter at the prompt takes the frame's typed text with it.

## What is ix's own

`tests/frames.sh` and `frames.expected`: its frames' sums and, where
the playground is there, its golden frame pixel by pixel. `mkfile`,
`sdl/dune`. The `.mli` files: `DrScheme.mli`'s header is the playground
file's, extended; the others' are new.

## What remains in the playground

The other programs of `apps/devtools`: `TinyTurboPascal` (mini-pascal's
window, [`plan_pascal.md`](../../docs/plans/done/plan_pascal.md)), `TinyBasic`,
`TinyEmacs`, `TinyVi`, `TinyScratch`, `TinySnap`, `TinySmalltalk80`
and `TinySqueak` (whose start is `languages/smalltalk`'s `Squeak`).
