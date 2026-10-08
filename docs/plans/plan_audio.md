# Plan: sound on mini-9pi: `/dev/audio` on the Pi's own jack, a synthesizer in OCaml, Tetris's theme (`kernels/9pi/devices/audio/`, `raspberry/`, `lib_audio/`)

The author (2026-10-07), of [`plan_playground.md`](plan_playground.md)'s
question on Tetris's sound: "does the pi1 and pi4 have an audio device?
Then maybe we could start a plan for that too so we can have tetris
playing sound! We probably need a toplevel lib_audio/ which would be a
cut-down version of the playground (~/playground/libs/audio and the
Audio.mli in the playground/ subfolder)".

The short answer: **yes, both boards have one, and the simplest is the
same on both**: the 3.5 mm jack, which is two PWM channels of the SoC
behind a filter of resistors and capacitors. No codec, no firmware: a
clock, a FIFO, and DMA to keep it fed. Neither ix nor principia has a
line for it yet, and **QEMU does not emulate it**: mini-pi, ix's own
emulator, would be where it is first heard.

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
- **mini-pi** (`raspberry/`): no PWM, no clock manager's PWM clock;
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

## Decisions (proposed, for the author)

1. **The jack's PWM, on both boards**; HDMI, I2S and USB audio not in
   this plan.
2. **Plan 9's interface as it is**: `/dev/audio` (written: 16 bits,
   two channels, 44,100) and `/dev/volume`. A WAV's samples copied to
   it play; nothing in it knows the playground.
3. **mini-pi first**: the PWM and its clock in `raspberry/`, the DMA
   paced by the PWM's request, and two places for the samples: a WAV
   file (an option of the command line: what a test compares, no SDL),
   and SDL's audio device where the window is SDL's. Then the real
   boards, by the author. QEMU stays without sound; its sessions go on
   checking the rest.
4. **The mixing is the program's**, in floats, as in the playground;
   the kernel is given integers and does no arithmetic on them but the
   16 bits to the PWM's range.
5. **`lib_audio/`, cut down, its interfaces kept**: `Signal Mix
   Resample`, `Oscillator Noise Envelope Filter Pluck Fm`, `Synth Sfx
   Pitch_effect Music Space Mixer`, `Abc`, `Wav`: about 2,000 lines of
   the playground's 6,900. Not: the live instruments and effects, the
   formats that are decoders. `Audio` in `lib_playground/`, **its
   interface the playground's less what was not copied** (the effects'
   functions, `wav`, `midi`, `play_module`, the instruments), so that
   another of the playground's games compiles here as it is or says by
   an unbound name what it misses.
6. **The platform plays**: `Playground_platform` pulls a frame's
   samples after each frame and writes them. A write to `/dev/audio`
   waits when the kernel's buffer is full: so a thread of its own (as
   `Mouse`'s and `Keyboard`'s readers), or a buffer in the kernel long
   enough that a frame's write never waits; to choose in stage 4, by
   the measure. The `ppm` platform writes a WAV.

## The stages (each checked before the next)

1. **`lib_audio/` on Linux.** Copied, changed where mini-ml asks
   (`games/survey.sh` extended to say where, as for the library),
   built by dune and mini-mk. A command that renders a sound to a WAV
   (an ABC tune, an `Sfx`). Check: Tetris's theme, the same samples as
   the playground's own `-dump-audio` (or the difference said); and
   **the seconds a second of the theme costs** when mini-ml compiled
   it, on arm under mini-pi: that says whether 44,100 holds on a Pi1
   or the rate is to be halved.
2. **mini-pi's PWM.** The device, the clock, the DMA's pacing; the
   WAV out. Check: a bare-metal program of a few lines (a square wave
   through the FIFO, then by DMA) and its WAV.
3. **`/dev/audio` in mini-9pi.** `Devaudio`, a DMA module (principia's
   `dma.c` is the reference), the pins' function. Check: `make
   check-audio`: a WAV copied to `/dev/audio` under mini-pi, the
   emulator's WAV the same samples; then the author's boards and a
   pair of headphones.
4. **Tetris with its sound**: `Audio` in `lib_playground/`, the
   platforms' pull, the game's "Sound" section back as the playground
   has it ([`plan_playground.md`](plan_playground.md), decision 6).
   Check: a session's WAV under mini-pi; the frames a second with the
   sound and without.
5. Later, each its own decision: HDMI, a USB sound device (and with it
   QEMU's `usb-audio`), the live instruments, the MOD player.

## Open questions

- A Pi1's floats: if stage 1 says the synthesizer is too slow there,
  the rate halved (22,050), or the sounds all rendered before the game
  starts (they are trees rendered ahead already: the theme is the long
  one)?
- `Wav` and `Abc`: in `lib_audio/`, as proposed, or a `formats/`
  under it as the playground has?

## Status

2026-10-07: plan written, after the survey. Nothing built. Waits for
[`plan_playground.md`](plan_playground.md)'s stage 1 only for its
stage 4.
