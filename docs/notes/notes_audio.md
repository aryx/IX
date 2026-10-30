# Notes on the sound: where it was late, cut, slow or never heard

The author, 2026-10-12, mini-rebirth's tune halting in its window on
Linux while the playground's played: "I feel like sounds has lots of
quircks like the keyboard, maybe we can write a similar note".

Nineteen problems in the five days of
[`plans/done/plan_audio.md`](../plans/done/plan_audio.md), in the kernel's device,
the emulator, the playground's loops, the synthesizer. Most were found
by a count (a sum of samples, the times a buffer ran empty); the one
that started this note was found the first time somebody listened.
Here they are side by side, by what was wrong, and what they have in
common, as [`notes_keyboard.md`](notes_keyboard.md) does for the keys.

## In plain words

For a reader who has not made a computer play anything (the tutorial,
[`tutorials/notes_audio_device.md`](../tutorials/notes_audio_device.md), takes its
time over each of these):

- **Sound cannot be late.** A loudspeaker takes 44,100 numbers a
  second, at its own pace, like a conveyor belt that cannot be
  slowed. A picture drawn late stays on the screen a moment longer
  and nobody sees it; a number handed over late is an empty place on
  the belt: a click, or a stutter.
- **So one works ahead, and pays in delay.** The program keeps a
  stock of numbers ready (a buffer). A large stock survives the
  program looking away; but a new sound goes to the back of the
  stock, and is heard when its turn comes. Safe and late, or prompt
  and fragile: every problem of the kind "it crackles" or "the shot
  is heard after the hit" is this one number.
- **A gap makes the music slow, not only rough.** The program counts
  its time in numbers handed over. When the belt ran empty the
  program did not notice, and goes on from where it was: behind the
  world, by every gap so far.
- **Making the numbers is work.** A second of a synthesizer is
  hundreds of thousands of multiplications. A machine that needs more
  than a second for a second of sound cannot play it, whatever the
  buffer: a small Pi with our own compiler is there for the richest
  sounds.
- **A test does not listen.** It compares numbers with numbers. The
  right numbers at the wrong time are a wrong sound, and only an ear
  (or a count of the empty places) says so.

## The path of a sample

    a program's sound: a file's decoder (mini-play), or Audio's mixer
    over Synth's voices (a game, mini-rebirth), floats at 44,100 a second
      -> the platform's loop pulls what it wants ahead (Audio_source):
           Plan 9: Plan9_loop writes 16 bits, two channels, to /dev/audio
           Linux:  SDL's queue (the window), or a WAV (-dump-audio)
      -> the kernel (Devaudio): a ring of 16,384 pairs, 371 ms, that a
           DMA channel goes around for ever, feeding the PWM's FIFO
      -> the board: two pins, a filter, the jack
           (under mini-qemu: -audiodev wav, a file)
      -> an ear

Four stations, each with a buffer, and one clock that nobody in the
program owns: the card takes 44,100 pairs a second whether they are
there or not. A key that is late is honored late; a sample that is
late is a hole, and what comes after it is late for ever. Every
problem below is one of: a buffer too short for the slowest thing
before it, a count that is not the clock's, a sound made before it is
wanted, or a check that is not an ear.

## What happened

| | where | what one saw (or counted) | what it was |
|---|---|---|---|
| 1 | Devaudio, the PWM's range (stage 3) | the rate is 44,107, not 44,100 | 250 MHz divided by 44,100 is not whole; the range rounded to 5669 is 7 parts in a million off, truncated it was 160 |
| 2 | Devaudio, the ring's count (stage 3) | "empty" counted when the ring was not | the silence put ahead of the first write (the lead) was not counted as what is in the ring |
| 3 | Devaudio, a write (stage 3) | 1,700 instructions a sample in the kernel | a division for each sample's place and its volume; sizes a power of two, shifts, the volume in 256ths, a page at a time |
| 4 | Devaudio, a ring that is never stopped (stage 3, by design) | (would be) the last third of a second again and again | the DMA goes around whether written or not: the clock's tick reads where it is and makes silent what was played |
| 5 | the Pi's two pins (stage 3) | (not heard) left and right the other way on the first boards | which pin is the left changed with the board's revision: asked of the firmware, `Machine.board_rev` |
| 6 | mini-qemu's board, 30 million instructions a second (stage 3) | the ring empty many times a second, the test fails | the emulated board is twenty times slower than a Pi 1: the checks say `-ips 700` or `1000`, and say so |
| 7 | the test's harness, `session.py` (stage 3) | no WAV after the session | the emulator was killed, and a WAV's header is written when it ends: asked to end first |
| 8 | Tetris's theme (stage 4) | 7 seconds of a Pi 1 before the first sample | the loop was rendered whole, then played; now each note when the loop comes to it, the first time around |
| 9 | `Mixer.change` (stage 4) | a wrong place in the tune on arm | a place times a length is more than an int of 31 bits holds: in floats |
| 10 | every program on the playground (stage 4) | a program with no sound carries the synthesizer | the platform called `Audio`; now `Audio` says itself to the platform when it is linked (`Audio_source`) |
| 11 | `Plan9_loop`, the write (stage 4) | a frame that waits in the kernel for room in the ring | written is what is missing of three frames ahead of the clock, or of twice the last frame's time, a third of a second at most: a write never waits |
| 12 | a scripted session (stage 6) | mini-rebirth's "running" frame is not the playground's | the sequencer moves by the samples pulled: a session that draws and does not pull stands still. Every scripted frame pulls its 735 |
| 13 | a game alone on the console, in a recorded session (stage 4) | the session's next commands are eaten | the game reads the keyboard: with `-frames n -dump-audio` it writes its samples and ends |
| 14 | the Pi 1's speed (stages 4 to 6) | a stereo MP3 empties the ring 10 times a second; Tetris's theme does not hold while first rendered; mini-rebirth is twenty times too slow | some 4,000 instructions a voice's sample in mini-ml's code, its floats each a block of memory. Not solved |
| 15 | SDL's loop, on Linux (2026-10-12) | mini-rebirth "too slow and the music does not play very well" | 50 ms queued ahead, the playground's number, whose frames are Cairo's; ix draws its pixels itself, a frame is now and then 30 ms, and the loop slept 5 ms each time. The queue ran empty: a gap, and the tune as much later |

| 16 | mini-play, a MOD on the real Pi 1 (2026-10-13) | "tune.mod is not playing smoothly", where the emulator at a Pi 1's speed had counted no empty ring | 47 parts in a hundred of a Pi 1 by the count, a third of it the collector copying the song's samples (floats, a block each) at every collection, a twelfth a `k mod 4`. A count is one instruction a cycle; the board's cache makes it more |
| 17 | `Audio.play` (2026-10-13) | TinyMissileCommand "extremely slow" on the Pi 1 | each play rendered the whole sound again, in the tick that asked: an explosion at every burst. Kept now, by the sound's value |
| 18 | `Audio_source.s16`, the samples made 16 bits (2026-10-13) | a fifth of a game's instructions on mini-9pi, sound or silence | a function called twice a pair, `Bytes.set` and `Char.chr` in it, each a checked call |
| 19 | the mixer's soft limit (2026-10-13) | a tenth more | a tanh for each sample, the runtime's being four exponentials; two now, the same bits, and none for a sample of 0 |

## The patterns

**A. A buffer is as long as the slowest thing before it, not as the
usual one (11, 15; 6).** Fifty milliseconds ahead is right when a
frame is always 16; one frame of 40 (a picture made for the first
time, a large window, the collector) and the card has nothing. And a
gap is not only a click: the mixer's time is the samples it was
asked for, so the tune is now behind the clock by the gap, and each
gap adds: *slow* is what one hears. The answer in both loops: measure
the longest frame of late, queue twice that, with a floor (three
frames) and a ceiling (a third of a second). The price is the other
end of the same number: a key's sound comes that much later. A buffer
is latency; one chooses.

What was not done, and is the usual answer: *a thread*. The card (or
SDL) calling for samples when it wants them, the game's frames
nowhere in the sound's path. The playground has none and neither has
mini-9pi's program (decision 6 of the plan): one loop, simple, and a
margin.

**B. The sound's clock is the count of samples, and nothing else
agrees with it by itself (1, 2, 9, 12).** The card's rate is not
quite 44,100; the system's clock is another crystal; a frame is a
sixtieth by one and 735 samples by the other. Whoever counts must
count everything (2: the silence too), in a number that holds it (9:
a minute of samples times a length is past 31 bits), and a program
whose state moves by samples (a sequencer, 12) only moves when
somebody pulls. A session without a card must pull as if it had one.

**C. A sound made before it is wanted is time taken from the frame
(8, 14).** Rendering a tune whole is the simple way and seven seconds
on a Pi 1. Rendered as played, the cost is spread, and it is still
there: the theme is 64 parts in a hundred of a Pi 1 more while its
notes are first made. What a board cannot do in real time it cannot
do lazily either; it can only do it once and keep it.

**D. A ring plays what is in it (2, 4).** A device that goes around
by itself has no "nothing to play": it has old samples. Whoever fills
it must also empty it behind the reader, and must know full from
empty by a count, not by two places being the same.

**E. An emulator is not a card, and a sum is not an ear (5, 6, 7,
15).** Every check here compares samples: mini-qemu's WAV against
Linux's, ours against the playground's, byte for byte. That says the
right samples were made; it does not say they came in time (the WAV
of an emulator has no clock but its own instructions' count, 6), on
the right pin (5), or that anybody would call it music. Fifteen was
in the tree, with every check passing, until the author listened.
What a count can say about time: the times the buffer ran empty
(Devaudio's `empty`, in the checks since stage 3), and the queue's
low mark in a loop; both are cheap and both should be in a test.

**F. Floats are the cost (3, 14, 16).** A sample is a few multiplications
in a filter, per voice, 44,100 times a second: 3.5 ms a frame for
mini-rebirth by OCaml's compiler, 34 by mini-ml's, where each float
made is a block. The kernel's part went from 1,700 instructions a
sample to a few by leaving divisions out (3); the synthesizer's has
no such trick found yet, and no profile that works on mini-ml's code
to look for one.

**G. What is linked for one program is linked for all (10).** Sound
is large (the synthesizer, the decoders). A platform that calls it
gives it to every program; a hook the sound sets when it is there
gives it to those that ask.

**H. Silence costs what sound costs, unless somebody says otherwise
(18, 19).** The loop pulls 44,100 pairs a second whether anything
plays; each goes through the mixer, its limit, the conversion, the
kernel's ring. On a slow board that floor is paid before the game
has drawn anything, and a profile of a game with sound is first a
profile of its silence.

## What to check in a new program, loop or device

- How far ahead is queued, and what is the longest frame? Measure it
  with the window large and the mouse moving, not the mean.
- What happens when the buffer runs empty: silence, or old sound? Is
  it counted, and does a test read the count?
- Does anything move by the samples pulled? Then who pulls in a
  scripted session, and in a session with no card?
- What does a second of silence cost? And is a sound played twice
  rendered twice?
- Is anything rendered before it is played? How long is that on arm
  under mini-5i, of a Pi 1's 700 million instructions a second?
- Every product of two counts of samples: does it hold in 31 bits?
- A program with no sound: is the synthesizer in it?
- Listen. On Linux first, ten seconds, with the window as one would
  have it; then the board. A check that passes is where to start.
