# mini-rebirth: the author's playground's TinyReBirth

A studio in a computer, after Propellerhead's ReBirth RB-338 (1997):
two TB-303 bass lines, a TR-808 and a TR-909 on one clock, a mixer, a
distortion, a delay, a compressor and a filter driven by a pattern.
From the author's playground (`~/playground`,
[ocaml-elm-playground](https://github.com/aryx/ocaml-elm-playground)):
its `apps/music/TinyReBirth.ml` and what it stands on there. Over
`lib_audio/`'s `instruments/` and `effects/`, `lib_gui/` and
`lib_playground/`'s `Audio`. The plan:
[`plan_audio.md`](../../../docs/plans/done/plan_audio.md), stage 6.

    dune exec mini-rebirth            a window on Linux, with its sound (sdl/)
    rebirth                           on mini-9pi, from the card
    space  start, stop      k  the next skin      skin=night, skin=plain  (flags)

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The numbers below are
`scripts/playground_copies.sh apps/music`'s, against the playground at
`028d8abf` (2026-10-06).

## What was copied

10 files, 1,990 lines there and 2,170 here:

| here | there | what |
|---|---|---|
| `ReBirth.ml` | `apps/music/TinyReBirth.ml` | the program: its panel, a strip a machine |
| `Studio_rebirth` | the same | the four machines on one clock, the mixer, the effects |
| `Voice_tb303`, `Voice_tr808` | the same | the bass line's voice; the two drum machines' (the 909 is the 808's with other circuits and three recordings) |
| `Voice.mli` | the same | what a voice is |
| `Patch_text` | the same | a patch as text |

## What changed

- **Optional arguments are said** (mini-ml has none):
  `Voice_tb303.note_on`, `Voice_tr808.pattern` and `start_hit`, and
  the calls of `lib_audio`'s (`Vco.fill`, `Sequencer.note` and
  `create`, `Voicing.create` and `glide`, `Dynamics.process`,
  `Spectrum.of_signal`), of `Gui.button` (`enabled`).
- `Voice_tr808`: its three recordings (the 909's cymbals, computed)
  are made when first asked, by hand (lazy values there); **a hit that
  names itself** (`let rec h = { ...; add } and add ...`, a recursive
  value) is kept in a reference its `add` reads; `sweep_drum`'s three
  numbers are one argument (mini-ml's arm takes seven parameters at
  most).
- `ReBirth.ml`: its last line is ix's; **the section "The skins" is
  ix's own**, below.

## What is ix's own: the skins

The playground draws its machines with flat rectangles and its
toolkit's widgets. ReBirth was a photograph of a rack, and its
pictures could be replaced: a skin. Here (`Skin`, 264 lines):

- the pictures are **computed, from a palette**: a plate of brushed
  metal for each machine (noise stretched along a row, lit from above,
  bevelled), a knob shaded as a cone with its pointer (a picture an
  angle, 64 of them, made as asked), the 808's coloured keys and the
  909's with their lamps, a 303's step window, switches, buttons,
  rails with their screws, windows of black glass for the texts. No
  file, nothing of the original's artwork;
- **a skin is a palette**: `rb-338` (silver 303s, a black 808 with its
  three stripes, a pale 909: the usual) and `night`; `plain` is the
  playground's own view, kept as it is. The flag `skin=NAME`, the key
  `k` and the button SKIN go through them;
- the playground's `update` is not changed: the toolkit's widgets
  still take the mouse, their flat pictures are covered by the plates,
  and what they say is drawn again from the model. An open menu's
  items stay on top (`Gui.draw_layers`, new).

Not done, and what "closer to the original" asks next: a layout of
its own (the 303's six knobs and its keyboard, the 808's row of
levels: the strips are the playground's, 80 units high, and its
`update` places every widget), skins read from picture files as the
original's mods were (`lib_graphics` reads PNG), a logo.

## The tests

- `../tests/frames.sh`: six sessions; the three of the playground's
  (`skin=plain`) are **its golden frames, pixel for pixel** (by
  mini-ml's code a few edge pixels a grey level apart, as the games').
- `../tests/audio.sh`: two sessions of four seconds, each WAV **byte
  for byte the playground's own `-dump-audio`**, by dune's build and by
  mini-ml's.

## What remains in the playground

Its other studios and instruments (`TinyReason`, `TinyOp1`,
`TinyOpxy`, `TinyReface`, `TinyMinimoog`, `TinyDX7`, `TinyHammond`,
`TinyJuno`, `TinyCS80`, `TinyRhodes`, `TinyTB303`, `TinyTR808`,
`TinySoundtracker`), their voices and their parts: 80 files. Its unit
tests of these voices (`apps/music/tests`).
