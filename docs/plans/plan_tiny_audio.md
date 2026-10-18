# Plan: sound in t-ix, a speaker and a sound chip in about 200 lines

The author (2026-10-17): "now let's add audio to t-ix"; then "one of
the first milestone could be TinyAppTetris playing sounds".

m-ix has sound from one end to the other
([plan_audio.md](done/plan_audio.md), [notes_audio.md](../notes_audio.md)):
mini-9pi's Devaudio, a ring a DMA goes around; `/dev/audio`, 16 bits in
two channels at 44,100 Hz; lib_audio's synthesizer (Synth, Sfx, Music)
in floats; the playground's `Audio`; and tetris with its theme and
sfxr's sounds. t-ix had none. This plan is the idea of each of those
stations kept, and the rest dropped.

## 1. The idea: the speaker is memory, the kernel has the samples

```
    a game's sound: what changed between two models
    (TinyLibPlayground's game.sound; TinyAppTetris: a piece landed, rows)
        |  a message of 11 bytes: s wave hz to_hz ms volume
        v
    /audio, a voice (each open): TinyKernel.ml
        |  TinyKernelAudio.mix: the samples made where they are played,
        |  added to what the other voices put there
        v
    the ring: 8,192 samples, a byte each, at 0xc00000 (the kernel's choice)
        |  tiny-machine's speaker: 8,000 a second of the machine's time,
        |  each made 0 when played
        v
    the host: -audio a WAV; -window SDL's queue (a line "A n", n bytes)
```

- **The speaker is memory, as the screen is.** tiny-machine has a word,
  `-52(r0)`: written, the ring's address; read, the samples played.
  The speaker plays the ring at 8,000 samples a second of the machine's
  time, one every `rate` / 8,000 instructions. No DMA, no FIFO, no
  interrupt: the kernel writes ahead of the place it reads, up to a
  ring (a second) ahead, and looks again at its clock's ticks.
- **A sample played is made 0.** notes_audio.md's D (*a ring plays what
  is in it*): mini-9pi's clock tick silences what the DMA played. Here
  the device does it, so a ring nobody writes is silence, and the
  kernel needs no clock to clean behind the speaker.
- **Nothing happens at each sample.** The samples due are played when
  somebody looks, the kernel by reading the word, the host by taking
  them (a window at each of its turns, a WAV at the halt). The speaker
  costs no instruction of its own, `ticks`' batches stay as long, and
  a run is the same every time: `make check` compares a session's WAV
  by its sum, as it does a screen.
- **The kernel has the samples, a program says what**, as for the
  pixels. A program writes sounds to `/audio`, each sfxr's recipe cut
  to five numbers (a wave, a pitch that slides from one frequency to
  another, a length, a volume that falls to nothing); the kernel makes
  them into the ring (`TinyKernelAudio.ml`). A sound chip's bargain,
  the SID's and the NES's: their CPUs could not afford samples, and
  neither can tiny-ml's (section 3).
- **The kernel mixes.** Each open of `/audio` is a voice: its sounds
  follow one another, and what it makes is added (kept from -128 to
  127) to what is there. Two programs are heard at once and neither
  waits for the other, as two windows are drawn on one screen.
- **A sound is what changed.** A game of TinyLibPlayground has a
  fourth function, `sound`, given the model before and the model after
  (Elm's view is a function of the model; the sound is one of a
  change). The game keeps nothing of what it played, and its sounds
  are tested as its rules are, with two models and no speaker.

## 2. The steps

1. **TinyAppTetris playing sounds** (the author's milestone). **Done
   (2026-10-18)**: the speaker (TinyMachineDevices, about 30 lines; its
   word below the network's, the devices from `-64(r0)` now),
   `-audio file.wav`, the window's `A n` lines and SDL's queue
   (TinyMachineSDL's `play`); `/audio` in TinyKernel.ml (about 25
   lines); `TinyKernel/TinyKernelAudio.ml` (about 45 lines: the five
   numbers made into samples, in fixed point, and the messages read);
   TinyLibPlayground's `sound` (a type, a field, the message, about 10
   lines); tetris's sounds, m-ix's (games/puzzle/Tetris.ml) as few
   numbers: a piece landed (a thud, 120 Hz sliding to 60), rows gone (a
   coin's G and C), four at once (C E G C), a level (a slide up), the
   game over (a triangle sliding down). tiny-tetris on the host plays
   them too, by the kernel's TinyKernelAudio (one after the other, not
   mixed). Tests: TinyKernelAudio_test.sh (sounds counted: a square's
   crossings of zero, a slide's halves, two sounds at one place
   clipping, the ring going round, messages, bad ones);
   TinyAppTetris_test.sh's scripts say each step's sounds (landings,
   a row, the game over, a new game silent); make check's
   tetris.events with `-audio`, its WAV against a sum. Found on the
   way:
   - **Samples made by the program were too dear.** The first version
     had the playground make samples (a string a sound) and `/audio`
     take them, as Plan 9's `/dev/audio` and m-ix's do. Counted on
     tiny-cpu: 2,750 instructions a sample, nearly all allocation
     (tiny-ml has no `Bytes`: a string of one character and a cons
     for each sample, then joined); the game over's 0.7 s was 15
     million instructions, two seconds of an 8 MHz machine. Fixed
     point and no division made no difference: the cost was not the
     arithmetic. So the kernel makes them, a sound crossing the pipe
     as 11 bytes: 230 instructions a sample, all of it, in tetris's
     session (0.9 million for its 3,840 samples), and the program's
     instructions back to what they were without sound.
   - The recorded tetris session has other pieces now: the open of
     `/audio` moved the clock at which the game takes its seed. The old
     kernel on the new machine gives the old screen's sum exactly (the
     device changes nothing for who does not use it); every other
     screen of `make check` is the same.
   - emacs is 100 bytes larger (the playground's sound type and its
     speaker's descriptor, linked with run_canvas); `ls /` has `audio`.
   - The window path, checked with SDL's disk driver
     (`SDL_AUDIODRIVER=disk`): 26 s of the session at 8 MHz, its
     3,762 sounding samples those of the WAV. Not heard by a person
     yet: notes_audio.md's E, *a sum is not an ear*.
2. **The web page's sound**: TinyMachineWeb's `hear`, the samples to
   Web Audio (an AudioBuffer a turn, scheduled one after the other,
   with the window's margin). About 20 lines.
3. **Music**: tetris's theme, Korobeiniki. A tune is notes with their
   times; written as sounds to a voice of its own it is a stream that
   waits when a second ahead, so the playground needs to write it a
   little at a time (a voice's place, as its frames), or the kernel
   keeps a voice's tune and makes it a tick at a time (a sequencer in
   the kernel: the chip's other half). To choose; a voice of two notes
   at once (the theme's bass) is a second voice.
4. **Samples from a program**: a message `p n` and n bytes (as `/draw`'s
   row of pixels), for what is not a recipe: a WAV played (`play
   file`), a voice recorded. Needs the samples cheap on the program's
   side, which is tiny-ml's Bytes (the general fix, in the runtime),
   or a program in C.
5. **Sound elsewhere**: a click for calc's buttons, a bell for the
   console's ^G, tiny-windows' windows each heard (nothing to do: every
   program opens `/audio` itself, the kernel mixes).

## 3. What is dropped, and why

- **Floats.** lib_audio's synthesizer is in floats; tiny-machine has
  none, and tiny-kernel's ML has no float. A sound is integers: the
  phase in 65,536ths of a period, a slide's step in 256ths of those,
  the volume in 65,536ths (`TinyKernelAudio.ml`).
- **44,100 samples a second in two channels of 16 bits.** 8,000 in one
  of 8, the telephone's rate and Sun's `/dev/audio`'s: enough for a
  game's beeps up to 4,000 Hz, and five times fewer samples to make on
  a machine of 8 million instructions a second.
- **Filters, echo, reverb, vibrato** (Sfx's other sliders): the five
  numbers are the sounds games need most (sfxr's "pickup", "jump",
  "hit", "explosion" are a wave, a slide and a decay).
- **A thread for the sound.** As in m-ix (notes_audio.md's A): a voice
  is written up to a second ahead, from the program's loop.
