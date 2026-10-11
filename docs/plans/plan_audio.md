# Plan: sound on mini-9pi: `/dev/audio` on the Pi's own jack, a synthesizer in OCaml, the games' sounds, `.mod` `.mid` `.mp3` played, a studio (`kernels/9pi/devices/audio/`, `raspberry/`, `lib_audio/`)

The author (2026-10-07), of [`plan_playground.md`](done/plan_playground.md)'s
question on Tetris's sound: "does the pi1 and pi4 have an audio device?
Then maybe we could start a plan for that too so we can have tetris
playing sound! We probably need a toplevel lib_audio/ which would be a
cut-down version of the playground (~/playground/libs/audio and the
Audio.mli in the playground/ subfolder)".

The author again (2026-10-11), starting it: "mostly with the target of
being able to play .mid, .mod, .mp3 under m-ix, the ability to have
games like TinyMissileCommand ported which use Audio.mli playground
audio API, and possibly a mini-rebirth that can do synthesis/mixing";
and: "Can we get this running under mini-qemu (qemu has no sound for
the pi) and for the real Pi1 ? (and later Pi2, Pi4)". The plan of
2026-10-07 stopped at Tetris and left the three formats and the live
instruments to "later": **[The targets of 2026-10-11](#the-targets-of-2026-10-11)**
below says what they add, and the decisions and stages are changed for
them (each change dated).

The short answer: **yes, both boards have one, and the simplest is the
same on both**: the 3.5 mm jack, which is two PWM channels of the SoC
behind a filter of resistors and capacitors. No codec, no firmware: a
clock, a FIFO, and DMA to keep it fed. Neither ix nor principia has a
line for it yet, and **QEMU does not emulate it**: mini-qemu, ix's own
emulator (mini-pi when this was written), would be where it is first
heard.

Its numbers are `games/survey.sh`'s (its "sound" sections; run
2026-10-07). **The hardware below is from memory** (the BCM2835 ARM
Peripherals manual, Circle's and Linux's drivers): every address and
pin is to be checked against the manual before it is code.

## The survey (2026-10-07)

### The boards (from memory, to check)

| way out | Pi1 | Pi4 | what a driver is |
|---|---|---|---|
| **the jack: PWM** | PWM0 and PWM1 (base + 0x20C000), on GPIO 40 and 45 | the same controller's second instance, on GPIO 40 and 41 | the PWM's clock from the clock manager (PLLD, 500 MHz, divided), a range that makes the rate (250 MHz / 5,669 = 44,100 a second, about 12 bits), samples in a FIFO of 8 words, filled by DMA at the PWM's request (DREQ 5), an interrupt at the end of each block |
| HDMI | by the firmware: a service of VCHIQ's | the same, or the HDMI's own registers | VCHIQ is a protocol of thousands of lines (Linux's, which Circle carries whole) |
| I2S (the PCM block) | on the header | on the header | short, but there is nothing to hear without a DAC board bought and plugged |
| USB audio | a device plugged | a device plugged | isochronous endpoints, the audio class: over `Devusb`, in the way of mini-usbd |

So the jack. Its sound is not a DAC's (the Pi1's is known for its
hiss), but it is what a program on the bare board can do in a hundred
lines, and it is on both boards. The author has a Pi1, a Pi2, a Pi4.

### What is there (checked)

- **Plan 9's interface is `/dev/audio` and `/dev/volume`**: a write is
  samples, 16 bits signed, little-endian, two channels, 44,100 a
  second. principia's kernel has it for the PC only (`devaudio.c`,
  a SoundBlaster 16's); nothing for arm. It has the Pi's DMA
  (`bcm/dma.c`).
- **mini-9pi**: no file names PWM or audio; no DMA module (its SD
  driver moves its words polled, and says principia uses DMA there).
  The GPIO's functions are set somewhere for the UART and the card: to
  find.
- **mini-qemu** (`raspberry/`): no PWM, no clock manager's PWM clock;
  the GPIO is registers that remember. It has the DMA controller
  (`Dma`), whose transfers are immediate: "the DREQ pacing [is] not
  modelled". A sound is exactly what paces.
- **QEMU** 8.2: for a raspi machine, one audio device, `usb-audio` on
  the USB bus; no PWM (a kernel writing there would write to nothing).
- **The playground's synthesizer** (`libs/audio`), by its layers: the
  samples (`signal/`, 181 lines), the building blocks (`synthesis/`:
  `Oscillator Noise Fm Pluck Envelope Filter`, 408), the engine
  (`Synth Sfx Pitch_effect Music Space Mixer Tape Instrument Control`,
  1,069), ABC's notation (372), WAV (77); and what a Tetris does not
  touch: the live effects (1,113), the live instruments (1,074), MIDI,
  MOD, MP3, Vorbis (2,769). Over it `Audio` (248 lines, an interface
  of 431 and 67 values), the playground's API. All of it floats, at
  44,100 a second.
- **Tetris.ml asks 9 of `Audio`'s 67 values**: `abc louder faster
  arpeggio sfx powerup play loop change_loop`, and `Sfx`'s `step`,
  `coin`, `powerup`. 53 of the playground's 153 game files use
  `Audio`, 14 `Sfx`.
- **How the playground plays**: a sound is a tree, rendered ahead to
  samples when first played; the `Mixer` adds what is playing; the
  platform pulls a frame's worth each frame (`Audio.pull`: 735 samples
  at 60 frames a second) and keeps the device about three frames
  ahead.

## The targets of 2026-10-11

Is the plan of 2026-10-07 enough for them? **For the device, yes; for
what plays on it, no.** By target (`games/survey.sh`, "what each
target stands on": a target's own files, then the files of
`libs/audio` they name and those name, to the end):

| target | its own lines | of `libs/audio` | the plan of 10-07 |
|---|---:|---:|---|
| TinyMissileCommand | 256 | through `Audio` only: `play laser explosion hit` | **covered** by its stage 4 (three sounds rendered ahead, as Tetris's); the game also asks `Scene2d` and the mouse, which are here |
| a `.mod` | `Mod_player` 274 | 624 in 5 files | left to "later" |
| a `.mid` | `Midi` and `Music` 259 | 1,423 in 15: the synthesizer itself, which the plan copies | `Midi` left out |
| an `.mp3` | `Mpeg_audio` 40 | 1,418 in 8, nothing of the synthesizer but `Signal` | left out ("the formats that are decoders") |
| TinyReBirth | 1,507 (the panel 363, `Studio_rebirth` 178, `Voice_tb303` 336, `Voice_tr808` 586, `Patch_text` 44) | 2,473 in 28: of `instruments/` `Sequencer Vco Voicing Diode_ladder Svf Modal`, of `effects/` `Delay Drive Dynamics Effect`, `Spectrum`, `Instrument`, `Control` | left out ("the live instruments and effects") |

What they change, beyond more files copied:

- **Two of the three formats are decoded whole before a sample is
  heard.** `Mpeg_audio.decode` is a file's bytes to all its samples;
  `Audio.midi` is `Music.render_score`, the whole song rendered ahead.
  Samples are a `float array`: a song of 4 minutes is 21 million
  floats, 170 MB where a float array is flat, and more than a process
  of mini-9pi may have (352 MB) where each float is a block of its
  own, as mini-ml's are. Only `Mod_player` is block after block
  (`fill`, pulled by the mixer as an instrument). **So an MP3 and a
  MIDI file need here a player that gives a block at a time**, which
  the playground has not: code that is ix's own (and could go back).
- **The cost of a float, which the plan asked of the theme alone, is
  now the question of each target.** mini-ml's float is boxed; an
  addition in place is 20 instructions, 63 by the runtime's call
  ([`plan_playground_speed.md`](plan_playground_speed.md)'s table). A
  second of sound is 44,100 samples, twice. *Estimated, not measured*:
  sounds rendered ahead are added by the mixer, a few operations a
  sample (Tetris, TinyMissileCommand: cheap everywhere, the rendering
  paid once at the start); a MOD is four channels read between two
  samples, tens of operations; an MP3 is, by sample and channel, about
  150 multiplications and additions (the polyphase's 64 by 32 matrix
  and its window of 512, the IMDCT of 36), so some 6,000 instructions
  where a Pi1 has perhaps 8,000 for it (700 MHz, one instruction a
  cycle at best); ReBirth is two diode ladders, two drum machines and three
  effects computed live, probably more than the MP3. **The MP3 and ReBirth are
  the two that may not hold on a Pi1 at 44,100**; stage 1 measures
  each before anything is decided for them.
- **mini-qemu runs 20 to 30 million instructions a second**
  ([`plan_mini_qemu_speed.md`](plan_mini_qemu_speed.md)): 450 to 680
  for a sample, the kernel and the picture included. So what is heard
  *while it runs* (SDL) is right only for what is cheap; what is
  written to its WAV is right always, being the board's time and not
  ours. The WAV is the check, and for the MP3 and ReBirth probably the
  only way to hear them under an emulator.
- **Nothing in the decoders asks what an int of 31 bits has not**: no
  `Int64`, `Int32` or `Bigarray` in `formats/mod`, `midi` or
  `mpeg_audio` (the survey). What the Huffman reader shifts is to be
  looked at when compiled (the survey's mini-ml column, stage 1).
- **A Pi 2** (the author's 2B V1.2, [`plan_pi2.md`](plan_pi2.md)) *from
  memory*: the Pi1's jack, PWM0 and PWM1 on GPIO 40 and 45, the
  peripherals at 0x3F000000: the same driver, one more row in the
  board's table. Its cores are each faster than the Pi1's one, and
  mini-ml's code for it may use what ARMv7 has (a division).

## Decisions (proposed, for the author)

1. **The jack's PWM, on both boards**; HDMI, I2S and USB audio not in
   this plan.
2. **Plan 9's interface as it is**: `/dev/audio` (written: 16 bits,
   two channels, 44,100) and `/dev/volume`. A WAV's samples copied to
   it play; nothing in it knows the playground.
3. **mini-qemu first**: the PWM and its clock in `raspberry/`, the DMA
   paced by the PWM's request, and two places for the samples: a WAV
   file (an option of the command line: what a test compares, no SDL),
   and SDL's audio device where the window is SDL's. Then the real
   boards, by the author. QEMU stays without sound; its sessions go on
   checking the rest.
4. **The mixing is the program's**, in floats, as in the playground;
   the kernel is given integers and does no arithmetic on them but the
   16 bits to the PWM's range.
   *2026-10-11*: the WAV is in the board's time, SDL's sound in ours:
   when the board is slower than the clock, SDL is given what there is
   and silence for the rest (said once on the console), never the
   emulator made to wait.
5. *(2026-10-11: replaced by 5b; kept for what it said.)*
   **`lib_audio/`, cut down, its interfaces kept**: `Signal Mix
   Resample`, `Oscillator Noise Envelope Filter Pluck Fm`, `Synth Sfx
   Pitch_effect Music Space Mixer`, `Abc`, `Wav`: about 2,000 lines of
   the playground's 6,900. Not: the live instruments and effects, the
   formats that are decoders. `Audio` in `lib_playground/`, **its
   interface the playground's less what was not copied** (the effects'
   functions, `wav`, `midi`, `play_module`, the instruments), so that
   another of the playground's games compiles here as it is or says by
   an unbound name what it misses.
5b. *(2026-10-11)* **`lib_audio/` is most of the playground's
   `libs/audio`, in its folders** (`signal/ synthesis/ formats/{abc,wav,midi,mod,mpeg_audio}/
   instruments/ effects/` and the engine at its top), copied by stage
   as each target asks, with a README.md saying what was copied, what
   changed and what remains
   (`scripts/playground_copies.sh`). Not: Vorbis, `Leslie`,
   `Modulated_delay`, `Phaser`, `Reverb`, `Eq`, `Rack`, `Sampler`,
   `Fm_algorithm`, `Dx_envelope`, `Tape`, until a program asks.
   `Audio` in `lib_playground/apis/`, its interface the playground's
   less the effects not copied. This answers the second open question
   (`formats/` under it, as the playground).
6. **The platform plays**: `Playground_platform` pulls a frame's
   samples after each frame and writes them. A write to `/dev/audio`
   waits when the kernel's buffer is full: so a thread of its own (as
   `Mouse`'s and `Keyboard`'s readers), or a buffer in the kernel long
   enough that a frame's write never waits; to choose in stage 4, by
   the measure. The `ppm` platform writes a WAV.
7. *(2026-10-11)* **A player is a filter, as Plan 9's**: `mini-play
   file` reads a `.wav`, `.mod`, `.mid`, `.abc` or `.mp3` and writes
   samples (16 bits, two channels, 44,100) to its standard output, a
   block at a time: `mini-play song.mod > /dev/audio` on mini-9pi,
   `| aplay -f cd` or `> song.pcm` on Linux, where it is tested with
   no device at all. It does not link the playground. (9front's are
   `audio/mp3dec`, `audio/wavdec`, `games/midi`, and `play` over
   them; one program here, by the file's suffix. The name is the
   author's to choose.)
8. *(2026-10-11)* **Each format's player gives blocks**: `Mod_player`
   as it is; `Mpeg_audio` gains a decoder with a state (`create`,
   `fill`: a frame's 1,152 samples when asked), `decode` kept over it;
   a MIDI file is played by a sequencer over voices that start and end
   (`Polyphony` or the engine's `Synth` a note at a time), not
   rendered whole. `Audio.play_module` and a new `Audio.play_file` use
   them through the mixer's instruments, as the playground's MOD does.
9. *(2026-10-11)* **The rate is the device's to be told**: `/dev/volume`
   takes `speed 22050` (Plan 9's own word for it), which is the PWM's
   range doubled; `Signal.rate` stays one number a program is built
   with. Used only if stage 1's measures ask for it.
10. *(2026-10-11)* **mini-rebirth is the playground's TinyReBirth, in
   its own folder** (`apps/music/rebirth/`: the panel, `Studio_rebirth`,
   the two voices, `Patch_text`), over `lib_audio/instruments` and
   `effects`, `Gui` (its `knob`, `rocker`, `button`, `menu` are here)
   and `Audio.instrument`. Last, since it is the dearest a sample.

## The stages (each checked before the next)

*(2026-10-11: stages 1 and 4 widened, 5 to 8 new; the stages of
2026-10-07 were 1 to 4 and a "later".)*

1. **`lib_audio/` on Linux, and what a second costs.** The engine and
   the three formats copied, changed where mini-ml asks
   (`games/survey.sh` extended to say where, as for the library),
   built by dune and mini-mk; the block players of decision 8;
   `mini-play` to a file. Check: Tetris's theme, the same samples as
   the playground's own `-dump-audio` (or the difference said); the
   playground's `tiny_soundtracker.mod` and `lame_encoded.mp3` and a
   MIDI file, the same samples as the playground's decoders give; and
   **the instructions a second of each costs** when mini-ml compiled
   it, arm, under mini-5i (a table: the theme mixed, a MOD, a MIDI
   file, an MP3, by `-calls` and in place): that says what holds at
   44,100 on a Pi1, what is halved, and what waits for
   [`plan_playground_speed.md`](plan_playground_speed.md)'s M4 (floats
   not boxed) or a Pi 2.
2. **mini-qemu's PWM.** The device, the clock, the DMA's pacing; the
   WAV out, then SDL's device. Check: a bare-metal program of a few
   lines (a square wave through the FIFO, then by DMA) and its WAV.
3. **`/dev/audio` in mini-9pi.** `Devaudio`, a DMA module (principia's
   `dma.c` is the reference), the pins' function. Check: `make
   check-audio`: a WAV copied to `/dev/audio` under mini-qemu, the
   emulator's WAV the same samples; then **the author's Pi1** and a
   pair of headphones.
4. **The games' sound**: `Audio` in `lib_playground/`, the platforms'
   pull (SDL's on Linux), Tetris's "Sound" section back as the
   playground has it ([`plan_playground.md`](done/plan_playground.md),
   decision 6), and **TinyMissileCommand** copied (`games/shmup/`).
   Check: a session's WAV under mini-qemu; the frames a second with
   the sound and without.
5. **`mini-play` on mini-9pi**: in the image, a `.mod`, a `.mid` and
   an `.mp3` on the card. Check: each one's WAV under mini-qemu
   against Linux's; on the Pi1, heard, and whether the kernel's buffer
   ever ran empty (a count in `/dev/volume`'s read).
6. **mini-rebirth**: `instruments/` and `effects/` as it asks, the
   program on Linux (SDL) first, its cost a second as stage 1's, then
   mini-9pi. Then, if wanted, the playground's TinySoundtracker (321
   lines over what stages 1 and 6 brought).
7. **The Pi 2 and the Pi 4**: the PWM's address and pins by board (the
   Pi 4's from the survey's table), after
   [`plan_pi2.md`](plan_pi2.md) for the first.
8. Later, each its own decision: HDMI, a USB sound device (and with it
   QEMU's `usb-audio`), Vorbis, the effects not copied.

## Open questions

- A Pi1's floats: if stage 1 says the synthesizer is too slow there,
  the rate halved (22,050), or the sounds all rendered before the game
  starts (they are trees rendered ahead already: the theme is the long
  one)?
- `Wav` and `Abc`: in `lib_audio/`, as proposed, or a `formats/`
  under it as the playground has? (2026-10-11: `formats/`, decision
  5b.)
- (2026-10-11) An MP3 on a Pi1, if stage 1 says it does not hold: the
  rate halved (decision 9), one channel, mini-ml's floats not boxed, or
  the decoder's arithmetic in integers (fixed point, as the decoders
  written for such processors: a second `Polyphase` beside the first,
  the playground's kept)?
- (2026-10-11) A collection in the middle of a song: the playing
  process stops for it. How long, against the kernel's buffer? To
  measure in stage 5; the buffer's length is the answer or a part of
  it.
- (2026-10-11) Two programs with a sound at once under mini-rio: Plan
  9's `/dev/audio` is one opener's. Left so, or a mixer in the way of
  rio's files?
- (2026-10-11) `mini-play`'s name, and whether the three decoders are
  programs of their own as 9front's.

## Status

2026-10-07: plan written, after the survey. Nothing built. Waits for
[`plan_playground.md`](done/plan_playground.md)'s stage 1 only for its
stage 4.

2026-10-11: the author's targets (the three formats, TinyMissileCommand,
a mini-rebirth; mini-qemu, the Pi1, then the Pi2 and the Pi4) written
in: "The targets of 2026-10-11", decisions 5b and 7 to 10, the stages
widened to 8. From `games/survey.sh` (run that day) and from reading;
the costs a sample are estimates, the Pi 2's addresses from memory.
Nothing built. plan_playground.md is done since, so stage 4 waits for
nothing; mini-pi is mini-qemu.

2026-10-11, **stage 1 done but for the games' side** (the author:
"let's start!"; and, of the copies: "remember when you copy code from
the playground to possibly adjust the .mli to be consistent with the
rest of ix"). What is there:

- **`lib_audio/`**: the engine and the formats (`abc`, `wav`, `midi`,
  `mod`, `mpeg_audio`), 66 files copied, in the playground's folders,
  one library; its [README.md](../../lib_audio/README.md) says what
  changed (14 optional arguments said, `Sfx`'s numbers from `Lehmer`,
  `Wav` without file access, ...). Built by dune and by mini-ml (34 of
  34 files; `languages/ml/tests/compile_ix.sh lib_audio`).
- **The block players** of decision 8: `Mpeg_audio.create` and `next`
  (a frame when asked, `decode` over it); `Music.play_score` and
  `fill_score` (a note rendered when its time comes); `Player`, ix's
  own, a file by its name's end, an MP3 at another rate resampled as
  its frames come.
- **mini-play** (`apps/music/play/`, 84 lines; decision 7): by dune
  and by mini-mk (O=7, O=5).
- **The samples are the playground's, to the bit**: each file of
  `lib_audio/tests/data/` (Tetris's theme as ABC and as MIDI, the
  playground's `tiny_soundtracker.mod`, `lame_encoded.mp3`, an MP2,
  an MP3 at 22,050) decoded whole by the playground's own code against
  mini-play's blocks; and the three builds agree (dune's, mini-ml's
  arm64 run here, mini-ml's arm under mini-5i for a second of each).
  `lib_audio/tests/play.sh` holds them (`make test`, `tests/lite.sh`).
- **Two bugs of an int of 31 bits and of mini-ml's strings**, found by
  the arm build and by reading: an MPEG header's 32 bits in one int
  (no frame found: now two halves); a MIDI track cut short, which
  counted on an exception mini-ml does not raise.

**What a second costs** (`lib_audio/tests/costs.sh`: mini-ml's arm
code, instructions counted by mini-5i; "of a Pi1" against 700 million
a second, the most it could do):

| file | what | start | a second | of a Pi1 |
|---|---|---:|---:|---:|
| `tiny_soundtracker.mod` | a MOD, 4 channels | 3,452,182 | 304,592,548 | 43% |
| `korobeiniki.mid` | a MIDI file, two voices | 2,647,539 | 395,781,252 | 56% |
| `bell.mp2` | Layer II, 44,100, stereo | 2,699,605 | 455,174,124 | 65% |
| `lsf_mono.mp3` | Layer III, 22,050, one channel | 17,417,917 | 533,678,292 | 76% |
| `lame_encoded.mp3` | Layer III, 44,100, stereo | 2,801,048 | 1,381,794,996 | 197% |
| `korobeiniki.abc` | the same tune rendered ahead, 12.8 s of it | about 4,700,000,000 | (its samples copied) | 7 s before the first sample |

"Start" is what is paid before the first sample; "a second", twice
the second half second's instructions. The `.abc`'s row is one run of
a second (4,748,705,754 instructions in all), not `costs.sh`'s three.

So, against the estimates above: **nothing is cheap**. A MOD is
6,900 instructions a sample, not "tens of operations": its inner loop
is some 30 float operations a channel, each a block allocated, and
`k mod 4` twice a channel (8 divisions a sample, 200 instructions
each on a processor without one: a quarter of it). A MOD and a MIDI
file should hold on a Pi1, with little left for a game beside them;
**an MP3 does not**, by two times; an MP2 is at the edge. And **a
tune rendered ahead is paid at the start**: Tetris's theme, 12.8
seconds of two voices, is 4.7 billion instructions, 7 seconds at best on a Pi1 before the first frame
(the playground renders it so; stage 4 has to do otherwise: the block
player of a score, as mini-play's MIDI, or the theme rendered while
the game's first screen shows).

What follows from it, to decide (each beside the simple version, as
the cryptography's: `plan_playground_speed.md`'s way):

1. the cheap ones first, in the library: no division in a loop of
   samples, a channel's step computed once a tick and not once a
   sample, the bit reader a byte at a time where it is a bit;
2. mini-ml's floats not boxed (its M4), which every row above waits
   for;
3. the MP3 on a Pi1: 22,050 or one channel (decision 9), or the Pi 2.

Not done of stage 1: the survey's mini-ml column for the library
(`compile_ix.sh` says it instead); the costs by `-calls`. Not checked: a
MOD of more than 4 channels, a MIDI file that is not `Midi.of_tune`'s
(tempo changes, running status, drums); `Sfx.vary` and `random` against
anything (their numbers are not the playground's). By hand and not in
`play.sh`: the playground's `bell.wav` and an MP3 with an ID3 tag before
it, the same samples. Not heard: anything (no device yet; on Linux
`mini-play x.mod | aplay -f cd` was not run). `make loc` does not count
`lib_audio/` (its `GROUPS` has not `lib_physics/` either): the author's
to say.

2026-10-11, **stage 2 done** (the author: "let's commit and move
forward!"). mini-qemu's Pi 1 has the jack:

- `raspberry/Pwm` (new): the PWM's registers, its FIFO of 8 words, the
  two channels by turns, and the clock manager's two registers for it
  (source and divisor: the rate is the clock over the range). A
  sample is its word over its range, as 16 bits; it does not draw the
  pulses.
- `raspberry/Dma`: a block to a peripheral that asks (DEST_DREQ, a
  PERMAP said by `Dma.pace`) is no longer moved at once: its words
  are `Dma.pull`'s, the channel active to its last, then its
  interrupt and the next block. `Board` moves the PWM's time with the
  system timer's, and an idle processor's skip stops at the block's
  end.
- `Board.set_audio`: the left ear's and the right one's samples (the
  A+'s wiring: the left is the PWM's second channel). `mini-qemu
  -audiodev wav,path=F` writes them at exit; in a window they also go
  to SDL's queue.
- **The hardware was checked against Circle's driver**, read from its
  repository (`lib/sound/pwmsoundbasedevice.cpp`, `lib/gpioclock.cpp`,
  `include/circle/dmacommon.h`, `lib/machineinfo.cpp`), not the
  manual, which is not on this machine. It corrects the survey's
  table: the Pi 4's jack is its second PWM (base + 0x20C800) on
  request line 1, its clock 125 MHz for the same code (PLLD is 750
  MHz there); the ears are GPIO 40 (left) and 45 on the first Model B,
  45 (left) and 40 on the A+ and after, 41 (left) and 40 on the Pi 4,
  all alternate function 0; the rate of a range of 5,669 is
  44,099.49.
- The check: `raspberry/tests/pwm/tone.c`, bare-metal, by mini-cc
  (over step 0's start): a tenth of a second of square wave written
  to the FIFO by hand, then one of sawtooth by DMA, each timed by the
  board's clock: **100 ms and 100 ms**; the WAV has the 4,410 periods
  of each, the right ear upside down in the first.
  `raspberry/tests/pwm.sh` holds the two lines and the WAV's MD5.
- One thing found: time passes a batch of 4,096 instructions at a
  time (136 microseconds: 12 words), and the FIFO is 8: a guest
  writing by hand could not keep up (151 ms for the 100). The PWM now
  ends the batch when the guest finds the FIFO full.

Checked too: xv6's boot as under QEMU (`raspberry/tests/xv6.sh
arm-pi1-bis`), mini-9pi's boot to its banner, with the changed `Dma`.
Not run: `make -C kernels/9pi check` (principia's kernel reads its
card by DMA: that path is the old one, a block moved at once, but it
was not run); the page (`raspberry/web`) built, not opened. Not
heard: the SDL queue was run (no error, with a card and with SDL's
dummy driver), by nobody with ears. Not done: the Pi 4's board
(stage 7); the pins' function looked at; `pwm.sh` in `make test` (it
asks mini-mk).

2026-10-11, stage 3, under mini-qemu: **`/dev/audio` in mini-9pi**
(`kernels/9pi/devices/audio/Devaudio`, the device `#A`, bound in
`conf/boot.rc`). To hear on the author's Pi 1 still.

- **No DMA module and no interrupt**, against what the stage said: a
  ring of 32 pages (16,384 pairs, 371 ms), a control block a page, the
  last one's next the first, so the DMA plays the ring for ever; a
  write puts each sample as a PWM word after the last one written and
  sleeps (10 ms) while the ring is full; the kernel's tick reads where
  the DMA is (its SOURCE_AD register) and writes silence over what was
  played. When the ring runs empty the next write starts 256 pairs
  ahead of the DMA. (principia's arm `dma.c` is its SD card's, a block
  at a time with an interrupt; its `devaudio.c` is the PC's
  SoundBlaster: neither was the reference. The registers and their
  order are Circle's.)
- `/dev/volume`: `audio out N` (0 to 100) and `speed out N` (4,000 to
  48,000: the PWM's range), read back in Plan 9's words;
  `/dev/audiostat`: the ring's bytes, those still to play, how many
  times it ran empty under an open file. One opener, as Plan 9's.
- **The ears by the board**: `Machine.board_rev` (new: the firmware's
  tag 0x00010002; the Pi 4's a constant) says whether the first PWM
  channel is the left ear (the Model A and B of 2011 and 2012) or the
  right one (the A+ and after, and the emulators' 0x900021). The
  author's board, asked: "2011 1.2", read as the first Model B's
  marking ("Raspberry Pi (C) 2011.12"): left on GPIO 40.
- Nothing of the board is touched before `/dev/audio` is first opened:
  QEMU has no PWM, and its sessions never open it.
- **The check, `make -C kernels/9pi check-audio`** (27 s; in
  `check-all`): `tests/tone` (half a second, 441 Hz left and 882
  right, integers) written to `/dev/audio`, then again at volume 50,
  in `make ix`'s image with `tone` in its bootdir; mini-qemu's WAV
  against `tests/audio.py`'s own computation of the two tones: **every
  sample the same, silence around, the left ear the left**. Not a WAV
  copied, as the stage said: there is no file in that image, and the
  tone says which ear. `session.py` now asks the emulator to end
  before it kills it (the WAV is written at the end).
- **mini-qemu's board is 30 million instructions a second of its own
  time, a Pi 1 some 700**: at 30 the first tone had 100 ms of silence
  in its middle (the writer stopped that long, by what not looked
  into; the ring ran empty and recovered, as designed). The check runs
  `-ips 700`. So **what stage 1 measured as 43% of a Pi 1 and more
  will not play whole under mini-qemu at its default**: its WAV, in
  the board's time, needs `-ips 700`; what SDL plays at the host's
  pace will have gaps. To say in stage 5.
- A sample cost about 1,700 instructions at first, three divisions a
  pair being three calls on this processor; the ring's sizes are
  powers of two now and the volume is in 256ths. What it costs now was
  not measured (the simple way is kept: a call of `Phys.set32` a
  word).
- Also tried by hand: `tone > /dev/audio` from the SD card's image
  (`tone` is in its `/progs/examples`): the 22,050 pairs in the WAV;
  `speed out 22050`: the WAV at 22,050, the tone's samples for a range
  of 11,338.

Builds: ocaml-light's (the Makefile's, the Pi 1), mini-ml's (`mini-mk
O=5`, and `O=7`, the Pi 4's, where opening `/dev/audio` says "no audio
on this board yet"). Not run: `make check`, `check-ix`, `check-card`
and the windows' sessions (`conf/boot.rc` has one more bind, the card
one more program: `/bin/tone` was added by hand to
`tests/session-card-ix` and `-ixk`'s listings; `tests/session-ix-b`,
which lists `/dev`, has the three files' lines, from its session run
under QEMU, where `/env/cpu` still differs as before this); the
Makefile's Pi 4
build (no arm64 ocaml-light on this machine); the kernels that share
`lib_machine` (xv6, oberon, singularity, squeak: `board_rev` is one
more function in their `machine.c`). **Not heard.** On the real
board, unknown until tried: whether the cut-down firmware
(`start_cd.elf`, `gpu_mem=16`) leaves PLLD running at 500 MHz, and the
step from the pin's low to the middle at the first open (a click,
once).

For the author's Pi 1: `make -C kernels/9pi card`, the card written
as before, then `tone > /dev/audio` at the prompt: half a second, the
lower note in the left ear.

2026-10-11, stage 4: **the games' sound**, on Linux and on mini-9pi
under mini-qemu. Not heard yet, by anyone.

- **`Audio` in `lib_playground/apis/`**, the playground's, less its
  six live effects (decision 5b). `Audio_source` (ix's own) is where a
  platform finds a program's samples: `Audio` says there that it is
  linked, so a program without sound is not linked with the
  synthesizer (Tetris with it is 1.79 MB for mini-9pi, 1.34 without;
  the games without sound 13 KB more).
- **The platforms.** `ppm`: `-dump-audio file.wav`, a sixtieth of a
  second a frame (the playground's word). `sdl`: SDL's queue, three
  frames ahead (its `Native_loop_2d`'s way). Plan 9's two
  (`Plan9_loop`): `/dev/audio`, what is missing of three frames ahead
  of the clock written after each frame (or of twice the last frame's
  time when frames are slow, a third of a second at most), so a write
  never waits in the kernel: **no thread of its own**, decision 6's
  question. A scripted session there (`-frames n -dump-audio
  /dev/audio`) writes each frame's samples and ends.
- **Tetris's "Sound" section is back as the playground has it**, and
  **TinyMissileCommand** is copied (`games/shmup/`, with its kit's
  `Shots` in `games/shmup/kit/`); both on the card (`tetris`,
  `missilecommand`, `missile-soft`). On Linux with sound: `dune exec
  games/puzzle/sdl/Tetris.exe`, `games/shmup/sdl/TinyMissileCommand.exe`.
- **A loop is rendered as it is played** (ix's own: `Synth.length` and
  `pieces`, `Mixer.loop_prepared`, `Audio.loop` and `change_loop` over
  them): a tune's notes each rendered when the loop comes to it, the
  first time around, where the playground renders the tune whole
  before its first sample (7 seconds of a Pi 1 for Tetris's theme, and
  again at each level). This answers the first open question. The
  samples are the same.
- **Checked against the playground**: `games/tests/audio.sh`, five
  sessions of the two games (10 seconds of Tetris's theme, a game
  played, `music=off`, TinyMissileCommand's explosions, 10 seconds of
  it): each WAV **byte for byte the playground's own `-dump-audio`**,
  by dune's build and by mini-ml's (arm64). TinyMissileCommand's three
  frames are its golden frames, pixel for pixel
  (`games/tests/frames.sh`, 23 lines ok on both builds).
- **On mini-9pi under mini-qemu**: `make -C kernels/9pi
  check-audio-game` (3 minutes, by hand): TinyMissileCommand's
  "explosions" session from the card, its sound to `/dev/audio`:
  mini-qemu's WAV has **the session's 47,039 samples as Linux's**,
  silence around. Tetris run live there (`tetris 'seed=1'`, `-ips
  700`, 200 seconds of the host for 3.2 of the board): the theme comes
  out, with 0.2 s of gaps in those 3.2 s.
- **What it costs** (arm, mini-ml's code, mini-5i, 300 frames without
  drawing; of a Pi 1's 700 million instructions a second):

  | | instructions a second | of a Pi 1 |
  |---|---:|---:|
  | Tetris, no sound pulled | 238 million | 34% |
  | its sounds and the mixer, `music=off` | + 47 million | + 7% |
  | **the theme, while it is first rendered** | **+ 450 million** | **+ 64%** |
  | TinyMissileCommand, no sound pulled | 356 million | 51% |
  | its sounds | + 88 million | + 13% |

  So **the games' own sounds hold on a Pi 1, and Tetris's theme does
  not while it is being rendered** (its first 13 seconds, and 13
  seconds again after each level: the sound will have gaps and the
  frames will be late; once around, it is the mixer's 7%). A
  voice's sample is about 4,000 instructions (stage 1's number for a
  MIDI file is the same thing). Where they go was not found: no
  profiler ran on mini-ml's code here (callgrind stops at an
  instruction it does not know, mini-5i has no profile). What would
  answer it: mini-ml's floats not boxed
  ([`plan_playground_speed.md`](plan_playground_speed.md)'s M4), or
  the oscillator's inner loop written for it; `music=off` until then
  on a Pi 1 if the gaps are unpleasant.
- `make loc` counts `lib_audio/` now (the author: "audio like graphics
  is pretty important for the user; it is a core part of the OS
  experience of m-ix"): m-ix 167,985 lines, 160,965 before.

Checked besides: `dune build` of `lib_audio`, `lib_playground`,
`lib_core`, `games`; the games by mini-mk for arm64, arm, and Plan 9's
two platforms; `languages/ml/tests/compile_ix.sh` (935 of 937, the two
that fail are `utilities/`'s, not this stage's); the SDL build run 5
seconds with SDL's dummy drivers, and its `-frames 600 -dump-audio`
the same WAV. Not run: `make test`, `tests/lite.sh` whole (the games'
job has `audio.sh` now), `check-audio` again after the card's change,
the recorded card and window sessions (`/bin/missile-soft` and
`/bin/missilecommand` added by hand to two listings; every program
linked with `lib_playground` has `Audio_source` and a changed
`Plan9_loop`). Not done: `Audio.play_file` (decision 8: a MIDI or MP3
file through the mixer), the frames a second with the sound and
without on the board, mini-qemu's own SDL window with a game.
