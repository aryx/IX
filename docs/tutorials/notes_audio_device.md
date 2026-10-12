# Sound, from a program to the jack: a tutorial for `/dev/audio` and the loops that feed it

How a number in a program becomes a movement of air: the sound
card's clock, the buffers between a program and it, the Pi's jack
(which has no sound card: a pin switched very fast), the kernel's
device, and the loop of a game that must draw a picture and keep the
sound fed at once. It is written for **a reader who has never made a
computer play anything**, and explains the ideas in the order a
sample travels, from the program down to the ear.

What it does not explain is how the samples are *made*: what a
waveform, an envelope, a filter, a synthesizer's voice are. That is
the playground's four tutorials, which `lib_audio`'s interfaces cite
by their names (`~/playground/docs/claude_notes/tutorials/`):
`notes_audio.md` (sound from scratch), `notes_synth.md` (the
synthesizer), `notes_audio_formats.md` and `notes_audio_midi.md` (the
files). `lib_audio` is that code, copied; what is ix's own is
everything after the samples exist, and it is where the trouble was:
[`notes_audio.md`](../notes_audio.md) is the list of what went wrong.
The plan: [`plan_audio.md`](../plans/plan_audio.md).

## 0. Where the code is, and a reading order

| where | what | section |
|---|---|---|
| `kernels/9pi/devices/audio/Devaudio` | `/dev/audio`: the ring, the DMA, the PWM | §4, §5, §6 |
| `kernels/lib_machine` (`Machine.board_rev`) | which pin is the left ear | §4 |
| `apps/music/play` | mini-play: a file's samples to `/dev/audio` | §7 |
| `lib_audio` | the decoders, the synthesizer, the mixer | §7 |
| `lib_playground/apis/Audio` | a game's sounds: `play`, `loop`, `stop` | §7 |
| `lib_playground/Audio_source` | where a platform finds a program's samples | §7 |
| `lib_playground/platforms/Plan9_loop` | a game's loop on mini-9pi | §8 |
| `lib_playground/platforms/sdl` | the same on Linux, SDL's queue | §8 |
| `lib_playground/platforms/Session` | a scripted run: frames and samples with no card | §11 |
| `kernels/9pi/tests/audio.py`, `games/tests/audio.sh`, `apps/music/tests` | the checks | §11 |

Read §1 to §3 for why sound is harder than pictures, §4 to §6 for the
kernel, §7 to §9 for a program, and §10 to §12 for what it costs, how
it is checked, and what is missing.

## 1. A sound, for a computer

A sound is air pushed and pulled, some hundreds or thousands of times
a second; a loudspeaker is a membrane that a voltage moves. So a
sound, for a computer, is a list of numbers: where the membrane
should be, at one instant after another. Each number is a **sample**.
A CD has 44,100 of them a second for each ear, each a whole number
from -32,768 to 32,767 (16 bits), and that is the one format this
system speaks everywhere:

    one second of sound = 44,100 pairs (left, right) of 16 bits
                        = 176,400 bytes

A minute is ten megabytes, which is why files are compressed (an
MP3 is a tenth of it) and why tunes are also kept as notes, a few
bytes each, and made into samples when played (a MOD, a MIDI file).

## 2. The clock nobody can stop

Here is the whole difficulty. Whatever plays the samples (a sound
card, the Pi's pin) takes them at its own pace, **exactly** 44,100
pairs a second, and does not wait.

Compare with a picture. If a game draws its next picture a little
late, the old one stays on the screen a little longer; nobody
notices. If a program hands over its next samples a little late, the
loudspeaker has nothing to do for that moment: silence in the middle
of a note, heard as a **click** or a stutter. An ear notices a
thousandth of a second.

A way to see it: a conveyor belt runs past, at a fixed speed, and you
must put one box on each place as it goes by. You cannot slow the
belt. If you look away, the places go by empty.

And there is a second effect, less obvious. A program that makes
music counts its own time in samples: "the next note starts 22,050
samples from now". If the belt ran empty for a tenth of a second, the
program did not notice; it still has all its boxes, and the tune
goes on from where it was, a tenth of a second behind the world. A
few of those and the music is audibly **slow**, not only rough.

## 3. A buffer: buying time with delay

Nobody can put a box on the belt 44,100 times a second by hand, and
no program is that punctual either: it is interrupted, it draws a
picture, it reads a file. So one works ahead. There is a **buffer**
between the program and the card: a stretch of memory with the next
samples already in it. The card takes from one end at its steady
pace; the program fills the other end in bursts, when it has time.

    the program            the buffer             the card
    (in bursts)   --->  [ . . . . . . . . ]  --->  (steady, 44,100 a second)

As long as the buffer never runs empty, nothing is heard of the
program's unsteadiness. So how much should be in it? Enough to cover
the longest moment the program is away. If a game sometimes spends a
twentieth of a second on a picture, the buffer must hold more than a
twentieth of a second, or that picture is a click.

The price is **latency**. A sound the program decides to make now
goes in at the end of the buffer, behind everything already there,
and is heard when its turn comes. A buffer of a tenth of a second
means the explosion is heard a tenth of a second after the key. For
listening to a song, a second would not matter; for a game, a tenth
is the edge of what feels right; for a musician's keyboard, a
hundredth.

So every program with sound makes the same trade: a long buffer is
safe and late, a short one is prompt and fragile. Most of what went
wrong in [`notes_audio.md`](../notes_audio.md) is this number chosen
for the usual case and met by an unusual one.

This system has three buffers in a row, each chosen that way:

| buffer | whose | how long |
|---|---|---|
| the kernel's ring (§5) | `Devaudio` | 371 ms; a writer waits when it is full |
| what a game writes ahead (§8) | `Plan9_loop`, or SDL's queue on Linux | 50 ms, more when frames are slow, 333 ms at most |
| the card's own (Linux) | SDL | 1,024 pairs: 23 ms |

## 4. The Pi's jack: a pin that blinks

A sound card has a part that turns a number into a voltage (a DAC).
The first Raspberry Pi has none on its jack. It has something
cheaper: a pin that can only be on or off, and can switch very fast.

The trick is called **pulse width modulation** (PWM). Take a very
short time, a period. Keep the pin on for a part of it and off for
the rest. Seen from far enough (through a resistor and a capacitor,
which is what is soldered between the pin and the jack), the pin
seems to be at a voltage in between: on for a quarter of the period
looks like a quarter of the voltage.

    a sample of 1/4:  |##......|##......|##......     looks like  ____  (low)
    a sample of 3/4:  |######..|######..|######..     looks like  ‾‾‾‾  (high)
                       a period

So a sample is "how long the pin is on in this period", and one
period is one sample's time. The PWM counts ticks of a clock of 250
million a second; a period of 5,669 ticks comes 44,099.5 times a
second, as near to 44,100 as whole numbers allow. A sample of 16 bits
is scaled to a count from 0 to 5,669: about twelve and a half bits
are left, and the jack of a Pi 1 is known for its hiss. (The HDMI's
sound is another device altogether, not done here.)

There are two pins, one an ear. Which is the left one changed between
the first boards and the later ones, so the kernel asks the firmware
which board it is on (`Machine.board_rev`).

## 5. Who feeds the pin: the DMA and the ring

The PWM wants a new number 88,200 times a second (two ears). The
kernel looks at its devices a hundred times a second. It cannot be
the one to hand over each number.

The board has a helper for exactly this, the **DMA** controller
(direct memory access): told "copy the words from this stretch of
memory to that device, one each time the device asks", it does so by
itself, with no program running. The kernel's work becomes keeping
the memory filled.

That memory is a **ring**: 32 pages, 16,384 pairs of samples, a third
of a second, and the DMA is told that after the last page comes the
first again. It goes around for ever.

                 the program's write puts samples here
                          v
        +---+---+---+---+---+---+---+---+
        | s | s | s | s |   |   |   | 0 |   <- the ring (32 pages)
        +---+---+---+---+---+---+---+---+
          ^                           ^
          the DMA is here,            what it has played is
          going right, then           overwritten with silence
          around                      (a hundred times a second)

Two details make it correct, and both were bugs first:

- A ring that is not refilled does not fall silent: the DMA comes
  around and plays the same third of a second again. So the kernel,
  at each of its ticks, reads where the DMA is and writes silence
  over what it has just played. An empty ring then plays silence.
- "How much is in the ring" must count everything put in it,
  including the short silence the kernel puts in front of a first
  write so that the DMA does not overtake it (the *lead*, 256 pairs).

When the ring is full, the program's write sleeps (10 ms at a time)
until there is room: this is how a program that makes samples faster
than they are heard is slowed to the card's pace. When the ring runs
empty, silence is heard, the count `empty` goes up by one, and the
next write starts just ahead of the DMA again.

## 6. `/dev/audio`: a file

To a program all of that is one file, as Plan 9 has it. What is
written to it is played:

    play /lib/sounds/tune.mod                   a tune, decoded by mini-play
    cat song.pcm > /dev/audio                   raw samples, as they are
    echo audio out 50 > /dev/volume             half as loud
    cat /dev/audiostat                          how full the ring is, how
                                                often it ran empty

No library, no setting of formats: 16 bits, two ears, 44,100, the low
byte first, always. A file of another rate or shape is the program's
to convert before it writes (mini-play does).

## 7. The program's side: where the samples come from

Two kinds of programs.

**A player** (mini-play) reads a file and writes samples to
`/dev/audio` (or, with `-c`, to its standard output), as fast as it
can; the kernel's ring slows it (§5).
A WAV's samples are copied; an MP3's are computed (decoded) from the
compressed ones; a MOD or a MIDI file is notes and instruments, and
the samples are made by adding the instruments' sounds (the
playground's tutorials say how).

**A game** has several sounds at once and a picture to draw. It says
what it wants through `Audio` (`Audio.play shot`, `Audio.loop theme`,
`Audio.stop`), and `lib_audio`'s **mixer** adds whatever is sounding
now, sample by sample, when asked for the next *n* samples. Who asks
is the platform's loop (§8), not the game.

One thing here is ix's own. Most programs on the playground make no
sound (an editor, a spreadsheet), and the synthesizer is large. So
the platform does not call `Audio`; `Audio`, when a program is linked
with it, leaves a note in `Audio_source` ("samples can be had here"),
and the platform looks for the note. A program without sound has no
note and no synthesizer in it.

## 8. A game's loop: pictures and sound in one line

A game on the playground is one loop, sixty times a second:

    read the keys -> update the world (a tick) -> draw the picture
                  -> hand over the sound that is missing

A tick is a sixtieth of a second: 735 samples. But the loop does not
hand over 735 samples a turn; that would work only if every turn
took exactly a sixtieth. It asks instead *how far ahead of the card
am I?* and fills what is missing up to a mark:

    ahead of the card now:      1,400 samples
    the mark:                   2,205 (three frames, 50 ms)
    so: ask the mixer for 805, and hand them over

After a slow turn more is missing and more is asked; after a quick
one, less. The sound follows the card's clock and not the loop's.

The mark is the buffer of §3, and three frames is right only while
no turn is longer than that. ix draws its pictures itself, pixel by
pixel, and a turn is now and then 30 or 40 ms (a large window, a
picture made for the first time). So both loops measure the longest
turn of late and keep **twice that** ahead when it is more than the
three frames, a third of a second at most. A game with quick turns
has 50 ms of latency; one with slow turns has more, and no clicks.

On mini-9pi the loop does this by the clock (it knows how many
samples it wrote and when it started), and never has more ahead than
a third of a second, less than the ring holds, so a write never
sleeps and the picture never waits for the sound. On Linux, SDL says how much is still queued.

The usual other design is a second thread that only feeds the card,
so that the picture's slowness cannot touch the sound. It is not done
here: one loop is simpler to read and to test, and the margin pays
for it.

## 9. Made when played

A tune given as notes must be turned into samples (*rendered*), and
that is the expensive part: Tetris's theme, rendered whole before its
first note, was seven seconds of a Pi 1. So a loop is rendered as it
is played: each note's samples are made when the tune first comes to
it, and kept, so the second time around costs nothing. The first
time around, the machine does two things at once, and on a Pi 1 that
is still too much for the theme (§10).

## 10. What it costs

The card's clock makes this simple to state: to play in real time, a
second of sound must take less than a second to make. On a Pi 1
(about 700 million instructions a second), with mini-ml's code, by
the emulator's count:

| what | of a Pi 1 |
|---|---|
| a MOD, a MIDI file, an MP2 (mini-play) | holds: the ring never empty |
| a mono MP3 at 22,050 | nearly: empty once in a second |
| a stereo MP3 at 44,100 | no: empty ten times in a second |
| Tetris, without its sound | 34 parts in a hundred |
| its sounds and the mixer | 7 more |
| its theme while first rendered | 64 more: over a hundred |
| mini-rebirth | about twenty times too slow |

Why so much: a sample of a synthesizer's voice is a handful of
multiplications of fractions (floats), and mini-ml's code makes each
float a small block of memory. On Linux, mini-rebirth's frame is 34
ms by mini-ml and 3.5 by OCaml's own compiler. This is open.

## 11. How it is checked, and what a check cannot say

Nobody listens in a test. What is compared is samples:

- `-dump-audio file.wav`: a scripted run of a game (so many frames,
  these keys) writes the samples it would have played; their sum is
  recorded, and they are the playground's own, byte for byte
  (`games/tests/audio.sh`, `apps/music/tests/audio.sh`).
- Under mini-qemu, the emulated jack writes a WAV, compared with
  what Linux made of the same file, and the kernel's `empty` must be
  0 (`make -C kernels/9pi check-audio`, `check-audio-game`,
  `check-audio-play`; minutes each, by hand).

A scripted run has no card, so it must pretend: each frame pulls its
735 samples. Otherwise a program whose state moves with the samples
(mini-rebirth's sequencer) stands still, and its picture is wrong.

What this says: the right samples are made, in the right order. What
it does not say: that they arrive *in time* on a real machine with a
real window, or on the right ear, or that they sound like anything.
The first person to listen found what every check had passed
(the loop on Linux, §8). The counts that speak of time (`empty`, a
queue's lowest mark) are the nearest a test gets; the rest is ears.

## 12. What is missing, and exercises

Missing: a thread for the sound; HDMI's sound; recording
(`/dev/audio` read); several programs playing at once (the kernel
mixes nothing: one writer); a faster synthesizer on the Pi 1.

1. `cat /dev/audiostat` while `play` runs, and while a game runs. How
   full is the ring in each, and why are they so different? (§5, §8)
2. Write a tone: a program that prints 44,100 pairs of a sine at 440
   Hz, twice (`kernels/9pi/tests/tone` is one). Send it to
   `/dev/audio`. Then make it sleep 400 ms in the middle and say what
   is heard, and what `empty` says.
3. In the SDL loop, set the mark back to three frames always, run
   mini-rebirth, and make the window large. Count the gaps.
4. What latency does a game have on mini-9pi when its frames are 100
   ms? Is that still a game?
5. The PWM's range could be 2,834, the clock's rate twice as fast for
   the ear: 88,200 periods a second. What would be gained and lost?

## Glossary

- **sample**: one number, the membrane's place at one instant; a
  **pair** is the two ears'.
- **rate**: samples a second, an ear; here always 44,100.
- **buffer**, **queue**, **ring**: samples made and not yet played.
- **latency**: the time from a program deciding a sound to its being
  heard; at least the buffers' length.
- **underrun**: the buffer ran empty; heard as a click, a gap, and
  then a tune that is late.
- **PWM**: a pin on for a part of each period; the part is the sample.
- **DMA**: the board's copier, memory to a device, with no program.
- **to render**: to compute a sound's samples from its description.
- **mixer**: adds the sounds playing now into one stream.
- **tick**, **frame**: a sixtieth of a second of a game; 735 samples.

## References

audio(3) of the Plan 9 manual. "BCM2835 ARM Peripherals" (Broadcom,
2012), chapters 4 and 9. `Devaudio.mli`, `Audio_source.mli`,
`Mixer.mli`. The playground's `notes_audio.md`, section 10 ("The
audio loop: latency and the two clocks"), where the three frames
ahead come from.
