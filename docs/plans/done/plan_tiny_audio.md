# Plan: sound in t-ix, a speaker and a sound chip in about 200 lines

The author (2026-10-17): "now let's add audio to t-ix"; then "one of
the first milestone could be TinyAppTetris playing sounds"; then
(2026-10-18) "let's commit; no need for sound in the web page. let's
support raw samples and have a tiny-play command that can play a wav
file (that we can also add on the virtual disk as an example to
test)".

**Status: done** (2026-10-18; moved to done/ on 2026-10-23): steps 1,
3 and 4 done, 2 dropped by the author (no sound in the web page), 5
nothing to do (every program opens `/dev/audio`, the kernel mixes).
What is left are section 3's drops (floats, 44,100 samples in 16 bits,
filters and echo, a thread for the sound), each a choice, not a gap.

m-ix has sound from one end to the other
([plan_audio.md](plan_audio.md), [notes_audio.md](../../notes/notes_audio.md)):
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
    /dev/audio, a voice (each open): TinyKernel.ml
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
  pixels. A program writes sounds to `/dev/audio`, each sfxr's recipe cut
  to five numbers (a wave, a pitch that slides from one frequency to
  another, a length, a volume that falls to nothing); the kernel makes
  them into the ring (`TinyKernelAudio.ml`). A sound chip's bargain,
  the SID's and the NES's: their CPUs could not afford samples, and
  neither can tiny-ml's (section 3).
- **The kernel mixes.** Each open of `/dev/audio` is a voice: its sounds
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
   (TinyMachineSDL's `play`); `/dev/audio` in TinyKernel.ml (about 25
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
     had the playground make samples (a string a sound) and `/dev/audio`
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
     `/dev/audio` moved the clock at which the game takes its seed. The old
     kernel on the new machine gives the old screen's sum exactly (the
     device changes nothing for who does not use it); every other
     screen of `make check` is the same.
   - emacs is 100 bytes larger (the playground's sound type and its
     speaker's descriptor, linked with run_canvas); `ls /` has `audio`.
   - The window path, checked with SDL's disk driver
     (`SDL_AUDIODRIVER=disk`): 26 s of the session at 8 MHz, its
     3,762 sounding samples those of the WAV. Not heard by a person
     yet then: notes_audio.md's E, *a sum is not an ear*. Heard since
     (2026-10-18), after step 4; the author: "I did use play and it
     worked and played sound".
2. **The web page's sound**: not done; the author: "no need for sound
   in the web page" (TinyMachineWeb's `hear` is `ignore`).
3. **Music: tetris's theme**. **Done (2026-10-18)**. Asked how m-ix
   does it (the playground's `Audio.loop "music"` and `change_loop`, a
   mixer in the game's process, the kernel a ring of samples), the
   author: "let's do the tetris theme in the playground". So the tune
   is the program's, as in m-ix, and its samples the kernel's, as for
   every sound here: TinyLibPlayground's game has a `music` function
   (the tune a model wants playing, as `view` is the picture it wants
   shown), a tune a pace and parts, each a wave, a volume and notes
   (Hz and units); each turn of the loop gives each part, a voice of
   `/dev/audio`, its notes up to half a second ahead (about 30 lines).
   Another tune goes on from the same notes (a faster pace: m-ix's
   `change_loop`); `None` stops it. TinyAppTetris: Korobeiniki from
   m-ix's ABC, the melody on a square and the octave bass on a
   triangle, 64 eighths each, a tenth faster each level, none at game
   over, `m` to mute it (m-ix's `music=off`). tiny-tetris on the host
   plays it too: its `/dev/audio` is now the kernel's scheme, a ring
   in TinyMemory, each open a voice mixing ahead of what SDL was given,
   SDL fed by the clock (the sounds one after the other before, which
   two parts cannot share). Tests: TinyAppTetris_test.sh (each part's
   eighths; the music each script ends with: playing, none at game
   over, muted and back); make check's tetris WAV, its sum. Found on
   the way:
   - **The theme took the whole machine.** With the music, the recorded
     session landed four pieces of six: tetris handled its keys late. A
     sample cost `mix` 535 instructions, two parts 8.8 million a second
     of an 8 MHz machine. Of it, 175 were the clamp,
     `max (-128) (min 127 y)`: the prelude's min and max are polymorphic,
     each a call of the runtime's compare, which made a frame of eight
     locals before it saw two integers. The runtime's `ml_compare` and
     `ml_equal` now look for two integers first (every program's
     polymorphic comparisons of integers gain), and the clamp is two
     comparisons of integers, inlined: 227 a square's sample, 258 a
     triangle's, 3.9 million a second for the two parts, half of an 8
     MHz machine and a fifth of the window's 20. The session lands its
     six pieces again.
   - Checked by ear's stand-in: each eighth's strongest pitch among the
     melody's, by a Fourier sum, in tiny-machine's WAV of the session
     and in tiny-tetris's (SDL's disk driver): Korobeiniki's eight bars
     as written.
   - Heard (2026-10-18), the author: "I could hear the music when
     playing tetris!"
4. **Samples from a program, and play**. **Done (2026-10-18)**: `/dev/audio`
   takes a message `p n` and n samples (as `/dev/draw`'s row of pixels),
   added to the ring as a tone is (TinyKernelAudio's `Samples`);
   `tiny/TinyPlay.ml` (about 50 lines of code) plays a WAV, `play` on
   tiny-kernel (`TinyKernel/user/play.ml`, its few lines) and
   `tiny-play` on the host; `/examples/korobeiniki.wav` on the boot
   image, tetris's tune, its first four bars (6.4 s), made by m-ix:
   `mini-play -c -s 6.4` of the ABC in games/puzzle/Tetris.ml, then
   four frames of 44,100 a second averaged and the two channels mixed,
   11,025 a second in 16 bits (141 KB), so play has a rate to convert.
   Tests: TinyPlay_test.sh (the example, WAVs of other shapes, blocks
   against the file at once, the files it refuses); make check plays the
   example, its WAV against a sum, and play's three errors. Found on
   the way:
   - **tiny-ml has Bytes now** (TinyLibCore: `Bytes.make`, `get`, `set`,
     `length`, `to_string`, `blit_string`; three functions in the
     runtime's core.c), the general fix the step asked for: a block's
     samples are 420 instructions each to make, the WAV's 51,200 about
     21 million.
   - **TinyLibGUI's read_file was 600 instructions a byte**: each piece
     read was added to the text so far, a copy of all of it each time;
     the WAV of 141 KB was 85 million instructions, 13 seconds of
     silence before the first note. Now the pieces, then each copied
     once into Bytes of their size: the program went from 108 million
     instructions to 43, its first note after the shell's prompt. The
     office, emacs and troff read their files by it too.
   - The frame at each sample's time was first a step of rate / 8,000
     in 4,096ths: truncated, it drifted half a frame within a block,
     and half the samples were the frame beside. Bresenham's stepping
     (a quotient and a remainder carried) is exact: the speaker's
     51,200 samples are the file's frame at k * 11,025 / 8,000 each,
     checked on the WAV tiny-machine wrote; tiny-play's, by SDL's disk
     driver, are the same samples.
   - The machine halts when the first shell reaches its input's end,
     and the speaker with it: the second play was ahead was not heard.
     make check says `sleep 2` after play.
   - On the host, SDL's queue is the ring: a write waits while a
     quarter of a second is queued (TinyMachineSDL's play drops past
     half a second, the window's rule against falling behind, which
     first dropped tiny-play's blocks), and the program's end waits
     until all is heard (it ended after a second's writing first).
   - ML programs are a kilobyte larger (core.c's three functions);
     emacs and the editor 1.8 KB (read_file too).
5. **Sound elsewhere**: a click for calc's buttons, a bell for the
   console's ^G, tiny-windows' windows each heard (nothing to do: every
   program opens `/dev/audio` itself, the kernel mixes).

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
