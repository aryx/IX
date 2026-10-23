# lib_audio: the author's playground's synthesizer, and the formats of sound

A software synthesizer and the decoders of the files sounds and songs
are kept in, from the author's playground (`~/playground`,
[ocaml-elm-playground](https://github.com/aryx/ocaml-elm-playground)):
its `libs/audio`. What mini-play (`apps/music/play/`) is written with,
and what the games' sounds will be
([`plan_audio.md`](../docs/plans/done/plan_audio.md), whose stage 1 this
is). Pure OCaml, floats, 44,100 samples a second; nothing here knows a
device.

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_audio`'s, against
the playground at `ff335663` (2026-10-23).

## What was copied

94 files, 9,684 lines there and 9,791 here, in the playground's
folders:

| here | there | what |
|---|---|---|
| `signal/` | `libs/audio/signal` | the samples, and what is computed on them: `Signal`, `Mix`, `Resample`, `Spectrum` |
| `synthesis/` | `libs/audio/synthesis` | the building blocks of a sound: `Oscillator`, `Noise`, `Fm`, `Pluck`, `Envelope`, `Filter` |
| `Synth`, `Sfx`, `Pitch_effect`, `Music`, `Space`, `Mixer`, `Instrument`, `Control` | `libs/audio` | the engine: a sound as a tree rendered ahead, tunes, stereo, the sounds playing, what is played live |
| `instruments/` | `libs/audio/instruments` | what is played live, as mini-rebirth asks: `Vco`, `Voicing`, `Sequencer`, `Moog_ladder`, `Diode_ladder`, `Svf`, `Modal` |
| `effects/` | `libs/audio/effects` | `Effect`, `Delay`, `Drive`, `Dynamics` |
| `formats/abc/` | `libs/audio/formats/abc` | `Abc`, `Doremi`: a tune as text |
| `formats/wav/` | `libs/audio/formats/wav` | `Wav` |
| `formats/midi/` | `libs/audio/formats/midi` | `Midi`: a Standard MIDI File's notes |
| `formats/mod/` | `libs/audio/formats/mod` | `Mod`, `Mod_player`, `Paula`: the Amiga's modules |
| `formats/vorbis/` | `libs/audio/formats/vorbis` | Ogg Vorbis: `Ogg` (a file's packets), `Vorbis` (codebooks, floors, residues, the inverse MDCT): LibreQuake's music, mini-quake's |
| `formats/mpeg_audio/` | `libs/audio/formats/mpeg_audio`, and `libs/compression`'s `Bits` and `Vlc` | MP2 and MP3: `Mpeg_audio`, its header, `Layer2`, `Layer3` and its tables, `Imdct`, `Polyphase`; `Bitstream` (the playground's `Bits`: `machine/` has a `Bits`) and `Vlc` |

## What changed

Most files only by their header line. The others, because mini-ml has
not what the playground's OCaml uses, because an int is 31 bits on
arm, or because a song is not a game's sound:

- **Optional arguments are said** (mini-ml has none), each definition
  saying what the default was (stage 6's: `Vco.fill`, `Sequencer.note`
  and `create`, `Voicing.create` and `glide`, `Moog_ladder.process`,
  `Dynamics.process`, `Spectrum.of_signal`; `Vco`'s inner function
  takes three of its arguments as one, mini-ml's arm having seven
  parameters at most; `Float.nan` and `infinity` are the stdlib's): `Oscillator.next` and `render`
  (`band_limited`), `Pluck.render` (`decay`, `tuned`), `Noise.render`
  (`mode`), `Mix.limit` (`soft`), `Synth.reverb` (`mix`),
  `Mixer.keep` (`filter`, an option; `pan`), `Mod_player.create`
  (`loop`), `Midi.of_tune` (`program`). `Filter.biquad` and `response`
  are at `Signal`'s rate, `biquad_at` and `response_at` at another:
  their optional `rate`.
- **Written otherwise**: `Array.map2`, `Option.value ~default`, `for
  _`, `Fun.id`, `Buffer.add_int16_le` and `String.get_int16_le`
  (through the unsigned ones); `Midi`'s events a type, where
  polymorphic variants; `Layer3`'s lazy tables made when first asked,
  by hand; `Music`'s constructors of `Synth` said with their module.
- `Sfx`: `vary` and `random` draw their numbers from `Lehmer`
  (`lib_playground/random`), where the stdlib's `Random.State`: other
  sounds for a seed than the playground's, the same on every compiler.
  The presets are the playground's.
- `Wav`: **no file read or written** (`write`, `read`, `write_stereo`:
  the caller's, through its capabilities); `stereo_to_string` in their
  place, and `stereo_of_string`, which keeps a file's two channels
  (`of_string` mixes them down: a game's sound is one channel until
  panned); 8-bit files read too, unsigned (mini-quake's sounds,
  LibreQuake's).
- `Synth.louder`: a recording (`Samples`) louder too, its samples times
  k; the playground's leaves it as it is (`map_voices`), and mini-doom's
  sounds were as loud far as near (docs/plans/bugs/ix.md).
- `Mpeg_audio_header`: the header's 32 bits read as two halves (`byte
  0 lsl 24` is past an int of 31 bits: no frame was found on arm).
- `Midi`: a track cut short is read to zeros, where an index past the
  string's end was caught (mini-ml's strings do not raise).
- **`Mpeg_audio`, a frame when asked** (`create`, `next`, `header`,
  `samples`): what goes from a frame to the next is in its state.
  `decode`, the whole file, is over it.
- **`Music`, a score a block at a time** (`play_score`, `fill_score`,
  `score_finished`): a note rendered when its time comes, added to
  the blocks it sounds in, dropped. `render_score`, the whole song, is
  kept.

- **A loop rendered as it is played** (stage 4): `Synth.length` and
  `pieces` (a sound's voices, each with the sample it starts at),
  `Mixer.loop_prepared` and `change_prepared` (a function called
  before a stretch of a loop is read). `lib_playground`'s `Audio.loop`
  renders a tune's notes as the loop comes to them, the first time
  around: Tetris's theme whole, before its first sample, is 7 seconds
  of a Pi 1. `Mixer.change`'s place in the new loop is computed in
  floats (a place times a length is past an int of 31 bits).
  `Synth.voice_steps`: a voice's samples one at a time, so that a note
  is rendered as far as the mixer reads and not whole at its first
  sample (a long note was a quarter of a second of a Pi in one tick);
  `render` of a voice is all of them, the same samples.

- **`Vorbis`, for ints of 31 bits and for mini-ml** (2026-10-23,
  mini-quake's music): a float32 of a codebook read as its three parts
  (`read_float32`: 21, 10, 1 bits), not as one number of 32 bits; the
  codes aligned to the book's longest code, not to bit 31 (a book whose
  codes pass 30 bits refused on arm, none of LibreQuake's); `several`
  a function of the unit, not a local one annotated `'a.`; an array's
  pattern (`[| Some whole |]`) written out; `Float.ldexp`, which ix's
  stdlib has not, a power of two; `Fun.id`, `for _`. And the codes'
  tree two slots a code, not two a bit of every code (a size the
  playground's had too large; no other change).

## What is ix's own

`Player`: a file of sound played a block at a time, by its name's end
(`.mod`, `.mid`, `.mp3`, `.mp2`, `.wav`, `.ogg`, `.abc`); an MP3 at
another rate than 44,100 resampled as its frames come.
`Vorbis_player`: an `.ogg` decoded a packet at a time as it is played,
cut at the length its last page says, looping or not (the playground
decodes a file whole: six minutes of LibreQuake's music would be 250
MB of floats); `Audio.play_ogg` and `Player`'s `.ogg` are it. And the tests:

- `tests/play.sh`: mini-play on a file of each format (`tests/data/`),
  its samples against `play.expected`; in `make test`, and by
  mini-ml's build in `tests/lite.sh`.
- `tests/costs.sh`: what a second of each costs on arm, below.

The files of `tests/data/` are the playground's (`tests/data/`,
`libs/audio/formats/tests/mpeg/`); `korobeiniki.abc` is Tetris's theme
as its `games/puzzle/Tetris.ml` has it, `korobeiniki.mid` that tune
through its `Midi.of_tune`; `stereo.ogg` is the playground's
`formats/tests/vorbis/stereo.ogg` (14 KB).

## Checked against the playground

Each file of `tests/data/`, decoded whole by the playground's own
code (its `Mod_player.fill` in one block, `Music.render_score`,
`Mpeg_audio.decode` then `Resample.to_rate`, `Synth.render_stereo`),
against mini-play's blocks: **the same samples, to the bit**, in the
three builds (dune's; mini-ml's for arm64, run here; mini-ml's for arm
under mini-5i, a second of each). So the block players add nothing
and lose nothing. The 8 presets of `Sfx`, rendered: the same too.
`stereo.ogg` against libvorbis's own decoding of it (the playground's
`stereo.expected.wav`, not copied): within 1 of 32,768 everywhere, as
many samples, silence after; the three builds the same bytes, and
LibreQuake's `track06.ogg` (10 s of it) by mini-ml's arm the same bytes
as OCaml's.

## What a second costs (`tests/costs.sh`)

mini-ml's code for arm, counted by mini-5i (no clock: the same numbers
on any host). "Of a Pi1" is against 700 million instructions a
second, the most its processor could do; a cache miss and the kernel
are not in it, so what is past 50% is not to be trusted to hold.

| file | what | start | a second | of a Pi1 |
|---|---|---:|---:|---:|
| `tiny_soundtracker.mod` | a MOD, 4 channels | 3,452,182 | 304,592,548 | 43% |
| `korobeiniki.mid` | a MIDI file, two voices | 2,647,539 | 395,781,252 | 56% |
| `bell.mp2` | Layer II, 44,100, stereo | 2,699,605 | 455,174,124 | 65% |
| `lsf_mono.mp3` | Layer III, 22,050, one channel | 17,417,917 | 533,678,292 | 76% |
| `lame_encoded.mp3` | Layer III, 44,100, stereo | 2,801,048 | 1,381,794,996 | 197% |
| `stereo.ogg` | Ogg Vorbis, 44,100, stereo, 1 s | 41,321,146 | 543,142,782 | 77% |
| LibreQuake's `track06.ogg` | Ogg Vorbis, 44,100, stereo, 96 kb/s, 6 min (3 MB) | 116,819,153 | 592,620,748 | 84% |
| `korobeiniki.abc` | the same tune rendered ahead, 12.8 s of it | about 4,700,000,000 | (its samples copied) | 7 s before the first sample |

"Start" is what is paid before the first sample; "a second", twice
the second half second's instructions. The `.abc`'s row is one run of
a second (4,748,705,754 instructions in all), not `costs.sh`'s three.

## What remains in the playground

- **The other live blocks**: `instruments/`'s `Lfo`, `Drift`,
  `Polyphony`, `Sampler`, `Fm_algorithm`, `Dx_envelope`, and
  `effects/`'s `Eq`, `Leslie`, `Modulated_delay`, `Modulation`,
  `Phaser`, `Reverb`, `Rack` (so `Audio`'s `chorus`, `flanger`,
  `phaser`, `rotary`: about 490 lines of modules, none a game's sound
  needs; its `drive` and `compressed`, over `Drive` and `Dynamics`, are
  in).
- `Tape`.
- (`playground/apis/Audio`, the games' API over this library, is in
  `lib_playground/apis/`: the plan's stage 4.)
- Its tests (`libs/audio/tests`, `formats/tests`: Testo, and golden
  WAVs).
