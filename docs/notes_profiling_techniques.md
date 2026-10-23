# Profiling techniques: which tool says where the time goes, layer by layer

The author, 2026-10-13, a MOD stuttering on the Pi 1 that an Atari ST
played in 1985: "please maybe add a notes_profiling_techniques.md
document".

[notes_performance.md](notes_performance.md) is the cases (what was
slow, what each fix saved);
[notes_debugging_techniques.md](notes_debugging_techniques.md),
section 16, is the night the tools were found. This is the tools
themselves, side by side: what question each answers, what it costs
to ask, and how each one lies. The rule that runs through it: **a
number first, a guess never**. Twice in the sound's work the cost of a
voice was written down as "not found: no profiler works on mini-ml's
code" while two of the tools below were in the tree.

## The questions, and the tool for each

| the question | the tool | minutes | what it gives |
|---|---|---|---|
| Is it slow, and how much? | `mini-5i -s program args` | 1 | instructions, exactly; two runs (n and 2n) and their difference is the steady part |
| Is that too much? | a division: instructions a second against the board's | 0 | "47% of a Pi 1" (700 million a second, at best: see below) |
| Which function? (a program alone) | `machine/tests/profile.sh listing program args` | 2 to 10 | every instruction charged to its function |
| Which function? (on mini-9pi, kernel and all) | mini-qemu `-prof F`, `kernels/9pi/tests/perf/steady.sh game [symbols]` | 5 | samples (one instruction in 1,024) of the steady frames, by the kernel's functions or the program's |
| Which part of a frame? | `game stats=on` (`Plan9_loop`'s meter), `tests/perf/frames.sh game` | 5 | update, view, show, in ms, every 40 frames |
| Which part of the kernel's drawing? | the timers by message and stage, on the serial line | 5 | `d:255x14390us p:43x2569us` |
| Is it the collector? | `ML_HEAP=n program`; `Gc.set` of `space_overhead`; `copy<>` and `collect<>` in a profile | 1 | the same run with a larger heap: what changes is the collector's |
| What does one operation cost? | ten lines compiled as the program is, 100 turns and 1,100 under `mini-5i -s` | 2 | "a float multiplied: 65 instructions; an integer division: 200" |
| On Linux, with OCaml's compiler? | timers in the loop (`Unix.gettimeofday`), then `perf`, then callgrind | 1 to 5 | ms a part; functions. Not mini-ml's code: callgrind stops at an instruction of its |
| How far is mini-ml's code from OCaml's? | `tests/icount.c` on the arm64 host, both builds of the same program; `mini-5i -prof` and callgrind by function | 10 | "a frame of mini-doom: 16.25 million, 7.59 by OCaml 4.14" |
| A command's time at rc's prompt | `tests/perf/timecmd.py CMD -- EMULATOR...` | 5 | wall time, N times |
| The boot, the collector's parameters | `tests/perf/gc_boot.sh` | 5 | seconds, collections |

Everything in `kernels/9pi/tests/perf/` and `machine/tests/` says its
usage at its top.

## In plain words: three ways to measure, and when each is right

- **Count** (`mini-5i -s`, `profile.sh`): an emulator runs the program
  and counts its instructions. Exact, the same on any day and any
  host, and blind to time: it does not know a memory access that
  misses the cache costs fifty times one that does not, or that a
  float is slow on one emulator and fast on a board. Right for *what
  to change*, and for comparing before and after.
- **Sample** (mini-qemu's `-prof`): now and then, note where the
  program is. Cheap enough to leave on for a whole system, kernel and
  programs; coarse (a function with few samples is noise), and it
  sees everything from the boot on unless two runs are subtracted.
  Right for *which layer*.
- **Time** (a meter in the program, a stopwatch): what the user feels,
  on the real thing. Noisy (the host, a clock of 10 ms), and under an
  emulator it is a count multiplied by a rate that depends on what is
  counted. Right for *is it fixed*, on the board, last.

One starts at the top (is it slow: a count or a time), goes down with
a sample or a count by function, changes one thing, and counts again.

## The profile by function, step by step (`profile.sh`)

For a program that runs alone on Linux's arm as mini-ml makes it
(mini-play, a game with `-dump-frame`: the platform that draws to a
file).

    cd apps/music/play && mini-mk O=5
        ... mini-ld -m 5 -H7 -nofollow -o ../../../_mk/5/.../mini-play A.5 B.5 ...

    # the same command, -v added, another output: the listing
    mini-ld -v -m 5 -H7 -nofollow -o /tmp/play5 A.5 B.5 ... > /tmp/play5.lst
    cmp /tmp/play5 _mk/5/apps/music/play/mini-play        # the same link

    mini-5i -s /tmp/play5 -c -s 1 tune.mod > /dev/null    # how much
    mini-5i -s /tmp/play5 -c -s 2 tune.mod > /dev/null    # ... a second of it
    machine/tests/profile.sh /tmp/play5.lst /tmp/play5 -c -s 0.2 tune.mod

(mini-mk prints the link's command when it links; remove the linked
program to see it again. A games' mkfile prints one with a piece of
its recipe's shell in it, `$stem | tr A-Z a-z\``, to take out.)

What comes back, for a MOD of four channels (2026-10-13):

    88712264 instructions
     26.3%    23314949 copy<>          the collector, copying
     16.4%    14531511 f8_next<>       Paula.next: a channel's sample
     11.0%     9793539 f31_fun<>       the function given to Array.iteri in fill
     10.5%     9333303 collect<>       the collector
      8.6%     7655122 div<>           the runtime's integer division
      3.2%     2839537 f24_fill<>

Reading it:

- `name<>` is a function local to its file: `copy<>` and `collect<>`
  are the runtime's collector, `div<>` its division (arm has no
  instruction for it), `ml_alloc` a block taken the slow way.
- `f8_next` is unit 8's `next`; which unit is 8 is the order of the
  link's command. `f31_fun` is an anonymous function of unit 31.
- `ml_curry2_1`, `ml_apply2`: a function of several arguments called
  through a closure, or given fewer than it takes.
- The start is in it (the file read, tables made): for the steady
  part alone, profile a run twice as long and compare, or look at
  shares that grow.

What it said here, and no reading of the code had: over a third was
the collector, and one line (`k mod 4`, twice a channel a sample) was
a twelfth.

## A game on mini-9pi, kernel and all (`steady.sh`)

TinyMissileCommand "extremely slow" on the Pi 1 (2026-10-13), where
cameltry was fine. Three measures, each saying a different thing:

    tests/perf/steady.sh missilecommand            the kernel's functions
     55.3% (user)    7.1% memmove    4.8% phys_set32    4.5% mark_slice ...

    # the game's own: its link's listing (mini-mk -n -a O=5 OS=plan9
    # prints the command; -v added, another output)
    tests/perf/steady.sh missilecommand mc9.lst.txt
     24.5% f3_put<>   10.1% f3_chr<>   6.4% exp   5.2% f18_map<> ...

    IPS=700 tests/perf/steady.sh missilecommand mc9.lst.txt
     10.7% f3_put<>    5.6% f5_long<>   5.1% div<>   4.5% f3_chr<> ...

- The first says the program is more than half, and the kernel's part
  is no one thing.
- The second seemed to say the game is all sound: the samples made 16
  bits (`put`, `chr`: `Audio_source.s16`), the mixer's tanh (`exp`).
  It is the emulator's speed that says so: at mini-qemu's 30 million
  instructions a second the game draws a frame now and then, and what
  is done *by the second* (44,100 samples, played or silent) is
  nearly everything. `IPS=700` was added for this.
- The third is the board's proportions: the sound's fixed cost still
  first (a fifth), then the display's messages, a division.

And none of the three showed the worst, because the session held the
right arrow and fired nothing: each `Audio.play` rendered its whole
sound again, an explosion at every burst. That was found by a count,
not a profile: `mini-5i -s` on `-dump-frame n` for n of 35, 65 and
95, the frames from 65 to 95 (the explosions) costing 8.5 million
instructions each against 6.2 before them; 1.9 after the fix. **A
profile says where a session's time went; the session has to do what
the user did.**

## mini-ml's code against OCaml's (the arm64 host)

The question "is it the compiler or the program?" has a reference
on the host: it is aarch64, and OCaml 4.14's ocamlopt compiles ix's
sources to arm64 (dune's build) as mini-ml does (`mini-mk`, `_mk/7`),
from the same files, to the same platform (ppm's, `-dump-frame`).
ocaml-light, OCaml 1.07, is not that reference: ix's programs use what
it does not have (`1_000_000`, labels, `Option`).

- **The count.** `tests/icount.c`: the processor's counter of user
  instructions on a command (perf_event_open; there is no `perf` on
  the host). Exact for mini-ml's code, within 0.2% for OCaml's. A
  frame: the run to frame 61 less the run to frame 31, by 30.
- **By function.** mini-ml's: `mini-5i -prof` (it runs arm64 Linux
  executables) and `mini-prof -diff` of the two runs (a few minutes).
  OCaml's: callgrind on the two runs, the functions' counts
  subtracted. Not callgrind on mini-ml's: valgrind stops at an
  instruction mini-ld emits (LDRSW of a literal). Ubuntu's qemu-user
  has no `-plugin`.
- **The frames are not the same bytes** across the two compilers on
  arm64 (OCaml fuses a multiplication and an addition; a few % of
  mini-doom's pixels): compare each compiler's frames with its own.
- Build both in a worktree of HEAD (other sessions change the tree),
  with `MKSHELL=mini-rc` for mini-mk by hand.

What it found the first time (2026-10-23, mini-doom, a frame): mini-ml
17.87 million, OCaml 7.13: 2.5 times. And something of the program,
not of either compiler: about half of OCaml's frame was its runtime's
polymorphic compare, most of it the renderer's `min` and `max` on
ints (Stdlib's are polymorphic: a call to compare each time, in each
column and span). With `Int.min` and `Int.max`, OCaml's frame 27% fewer
instructions, mini-ml's 1% (its compare was cheaper, and most of its
`cmp` is elsewhere, likely the floats' comparisons it does not type).
Comparing with another compiler finds what neither profile alone
says.

## The collector, which is in every profile

mini-ml's collector copies everything alive at each collection, and a
collection comes when as much has been made as is alive (twice, with
the default `space_overhead` of 100). So its cost is (what is alive)
times (how often): a program that keeps a megabyte and makes floats
in a loop copies that megabyte many times a second.

- A float made is a block (16 bytes on arm) unless the compiler made
  it in place; a `ref` of a float in a loop, a float field of a
  record assigned, a float returned: a block each.
- Seen as `copy<>`, `collect<>`, `obj_block` high in a profile, or by
  the run with `ML_HEAP=4194304` being much shorter.
- The cure that costs a line: `Gc.set { (Gc.get ()) with
  Gc.space_overhead = 700 }`, a heap eight times what is alive,
  collected an eighth as often (`Plan9_loop` does it for every game;
  mini-play now). It costs memory, eight times what is alive, twice
  (the two halves): not for a program that keeps megabytes.
- The cure that costs work: do not keep what need not be kept (a
  song's samples as floats are four to eight times its bytes), and do
  not make what need not be made.

## How each tool lies

- **A count is not a time.** 700 million instructions a second is a
  Pi 1 doing one instruction a cycle, which no program does: a load
  that misses the cache (16 KB of data cache, and a heap that is
  megabytes of fresh blocks misses all the time) is tens of cycles.
  "27% of a Pi 1" by count is a floor. The emulator said a MOD held
  (`-ips 700`, the ring never empty); the board stuttered.
- **An emulator's time is a count times a rate.** mini-qemu's clock is
  its instructions (`-ips`); QEMU runs integers at a thousand million
  a second and floats at a quarter of that. Neither is the board's
  mix.
- **An emulator slower than the board changes the proportions.** What
  a program does by the clock (sound, a timer) grows against what it
  does by the frame. Profile at the board's speed (`IPS=700`).
- **A session that does not do what the user did.** A key held is not
  a game played.
- **A sampled profile starts at the boot.** Subtract a short run from
  a long one (`steady.sh`).
- **A profile read with another build's symbols names the wrong
  functions**, a few off, plausibly. The listing and the program are
  one link's: `cmp` them.
- **A change measured that was not built.** mini-mk rebuilds a unit
  when its source changes, not when the compiler or a library's
  interface does; a count that does not move at all is a reason to
  look at the build.
- **A micro-benchmark never fills the heap.** A thousand turns of ten
  lines say what an operation costs and nothing of the collector.
- **A frame counted that was not drawn; a clock of 10 ms.** Section 16
  of the debugging notes has both.
- **A test that passes says nothing of speed** unless it reads a count
  (the kernel's `empty`, a queue's low mark:
  [notes_audio.md](notes_audio.md), pattern E).

## What usually is it (so far)

By how often it was the answer in ix, for mini-ml's code on arm:

1. The collector copying what is alive (floats made in a loop; a
   large structure kept). The MOD: 37%.
2. An integer division or `mod` in an inner loop: 200 instructions,
   a call. A power of two is a shift or a mask. The MOD: 9%; the
   kernel's sound device: 1,700 instructions a sample; its pixels.
3. A call through a closure: a function of another unit given two
   arguments (`ml_curry2`), a function given to `Array.iteri` or
   `List.iter` in the innermost loop.
4. A structure made again that was there (a screen, a message's
   bytes, a string by `^` in a loop).
5. A stdlib function that is a call into C for something small
   (`Float.min`: 360 instructions; `Float.round`; `Buffer.add_char`:
   258).
6. Work done before it is wanted (a tune rendered whole, a table
   made at the start), or done again each time (a sound rendered at
   each play).
7. A cost paid by the second whatever happens (a sample of silence
   through the mixer, its limit, the conversion, the kernel's ring).

## What to do, in order

1. Say the number and the budget: instructions for a second of sound,
   for a frame; of the board's.
2. Profile by function before reading the code. Ten minutes.
3. Is the collector in the first lines? Try the heap first: one line,
   one run.
4. Take the first line that is not the collector's; read that
   function only. Change one thing; keep the old line as `old:`.
5. Count again, with the tests that compare the output (a sum of
   samples, a frame's): faster and wrong is the usual first result.
6. Write the before and after where the change is, and the case in
   [notes_performance.md](notes_performance.md).
7. On the board, last, by ear or by eye: the count was a floor.
