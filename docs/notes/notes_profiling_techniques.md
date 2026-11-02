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
| Is it the tool's algorithm, or mini-ml's code? (mini-ml, mini-ld, mini-asm: programs dune also builds) | the same command by `./bin`'s (OCaml's build) and by `_mk/7`'s; then callgrind on OCaml's | 2, then 10 | "mini-ld's link of mini-ml: 8.2 s by OCaml's build, 11.6 by mini-ml's: the algorithm" |
| How far is mini-ml's code from OCaml's? | `tests/icount.c` on the arm64 host, both builds of the same program; `mini-5i -prof` and callgrind by function | 10 | "a frame of mini-doom: 16.25 million, 7.59 by OCaml 4.14" |
| A command's time at rc's prompt | `tests/perf/timecmd.py CMD -- EMULATOR...` | 5 | wall time, N times |
| The boot, the collector's parameters | `tests/perf/gc_boot.sh` | 5 | seconds, collections |
| Which part of a .NET program? (mini-ml -dotnet's, on Microsoft's dotnet) | its stages timed (`Sys.time`) in a small program of the same units, compiled the same way | 5 | "the facts parsed: 0.36 s; loaded: 4.8 s"; then one function at a time |
| Which method, on mini-dotnet? | `mini-dotnet -profile -s prog.dll args` | 1 to 5 | each method's own IL instructions (its calls' not), the costliest first |

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

    cd apps/media/play && mini-mk O=5
        ... mini-ld -m 5 -H7 -nofollow -o ../../../_mk/5/.../mini-play A.5 B.5 ...

    # the same command, -v added, another output: the listing
    mini-ld -v -m 5 -H7 -nofollow -o /tmp/play5 A.5 B.5 ... > /tmp/play5.lst
    cmp /tmp/play5 _mk/5/apps/media/play/mini-play        # the same link

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

## callgrind on a tool OCaml built, step by step

ix's own tools (mini-ml, mini-ld, mini-asm, mini-mk...) have two
builds: dune's, by OCaml (`./bin`, `_build/default`), and mini-ml's
(`_mk/5`, `_mk/7`, what m-ix runs). First the same command by both,
timed: if OCaml's build is slow too, the cost is the tool's algorithm,
not mini-ml's code, and callgrind on OCaml's build says where (it
cannot run mini-ml's: see above).

    valgrind --tool=callgrind --callgrind-out-file=/tmp/x.cg \
      _build/default/linker/Main.exe -m 7 ... the link's arguments
    callgrind_annotate /tmp/x.cg | head -30          each function's own
    callgrind_annotate --tree=caller /tmp/x.cg       who calls whom

About fifty times slower than the program: an 8 s link takes 7
minutes. Read the functions' own counts (the first listing). The
inclusive ones (`--inclusive=yes`) go past 100% in OCaml's code,
whose recursion callgrind counts again at each level, and the caller
tree names a recursive function's callers wrongly as often as not.

The signature of a search in a list that grows: `do_compare_val`,
`caml_compare` and `caml_page_table_lookup` (compare's, in OCaml 4.14)
at the top, `List.assoc_opt`, `List.assoc` or `List.mem` under them.
A structural compare of each element passed: quadratic in the list's
length. Then grep the tool for `List.assoc`: there are few, and the
one in a loop over the input is it. Found that way, 2026-10-28
(plan_ml_speed.md): mini-asm's labels (`Parser_asm`'s fixups, every
branch looked up in all of a unit's; mini-ml compiling 0.980) and
mini-ld's arm64 literal pool (`Arm64.layout`, flushed only past 1 MB,
thousands of entries; mini-ml's link 8.1 s to 3.1, 70% of it had been
compare).

Two builds of a program compared by function mislead: OCaml numbers
its closures (`camlEmit__fun_10395`), and the numbers move from one
build to the other. Compare the totals, and the runtime's functions
(`do_compare_val`, `caml_oldify_one`), whose names hold.

## A program on .NET: two runtimes, two cost models (2026-11-02)

mini-datalog's facts read by mini-ml -dotnet's code took 4.8 s on
Microsoft's dotnet, 25 s on mini-dotnet, 0.1 s natively. One cause per
runtime, each found by the tool that sees it:

- **Microsoft's dotnet: by halves, timed.** No profiler of .NET is here
  (dotnet-trace is not installed), so the program's stages were timed
  in a small ML program (`Sys.time` around each), compiled by mini-ml
  -dotnet with the same units: parsing 0.36 s, loading 4.8 s; then the
  loading's suspects one at a time, 20,000 calls each: Hashtbl,
  Tuples, Buffer all fast, `Prolog.to_string` 230 microseconds a
  call. Its `atom_text` asked `String.contains` of each character, and
  lib_core's `contains` was `try index ... with Not_found`: an
  exception for each miss. An OCaml exception is a few instructions; a
  .NET exception is a stack walk, microseconds. lib_core's searches
  now return -1 (`String.index_or`, as OCaml's own stdlib since 4.05),
  `Hashtbl.replace` is one pass that gives the bucket back unchanged
  for a new key: 4.8 s to 0.17, the whole program 5.5 to 0.55. Each
  change to lib_core outside lib_core/dotnet/ measured natively first
  (the author: "we don't want to slow down the other programs that do
  not use dotnet"): 2 million `contains`, 0.160 s to 0.134 by mini-ml;
  2 million `replace`, 0.21 to 0.16 by mini-ml, 0.08 both by OCaml.
  Printf's own `Not_found` was left: on .NET a literal format does not
  go through it.
- **mini-dotnet: by method, counted.** Its interpreter's time is its
  instructions (about 10 million a second), and `-profile` (new)
  charges each to the method running, less its calls': `String.index_or`
  35%, `blit_string` 21%. Not exceptions there (mini-dotnet's are
  OCaml's): character classes tested by scanning a constant string
  (`String.contains "+-*/..." c`, each character read), and a string
  copied into bytes a byte at a time in ML. Matches for the classes, one
  call of .NET's (`Encoding.GetBytes` into a byte[]) for the copy:
  262 million instructions to 113, 39 s to 23.

Then, under mini-analyze's compiled rules (rc, 2026-11-02), with no
profiler of Microsoft's runtime here (no perf, no dotnet-trace): a
**microbenchmark of the operations** the compiled loops make (a million
each: get, an index's chain, mem, hash, add), the same program by OCaml
natively and by Microsoft's .NET: each 3x, nothing pathological, the
closures 8x. So the cost was mini-ml -dotnet's code shape: a local
function a closure called through a delegate once per argument; lifted
to a static method (F#'s way), rc 30.7 s of CPU to 25.5. And
`mini-dotnet -profile` on the front end showed `Lexing`'s engine asking
257 table entries at each buffer's end, which mini-cc's one-character
refills made every character: a quadratic-looking cost that natively
hid in a fast loop, found only because the interpreter counts
instructions. Fixed in lib_core (per lexer, once): ix's native mini-cc
2x faster too. A benchmark loop inside a unit's toplevel misleads on
.NET: the toplevel is the class's .cctor, and each call of the class's
own methods there goes through the class-initialization check.

The lesson: the same IL has a different cost on each runtime, and the
first profile of one says nothing of the other. A miss signalled by an
exception is the .NET case of "what usually is it" (below, 9).

Then mini-analyze's .NET road for mini-9pi's card (2026-11-02): 22 s
under mini-dotnet, 15.7 of them for an empty C file, yet `-profile`
counted 9 million instructions (a second's worth). So the time was not
the interpreter's: loading was 0.1 s (`-size`), the GC little
(`OCAMLRUNPARAM=v=0x400`: 73 million words). gdb could not attach
(ptrace refused here), perf is not installed: **callgrind on the empty
case**, 15 minutes under valgrind, said 95% in OCaml's runtime,
`do_compare_val` and `caml_page_table_lookup`, which name no ML
function. The way to the culprit, through the runtime's C:
`callgrind_annotate --tree=caller --threshold=100`, then from
`caml_equal`'s entry to its caller, `caml_c_call` (how ML calls the
runtime's C), then `caml_c_call`'s callers ranked by cost: one lambda
of mini-dotnet's Types, 40,749 calls. Its `m.def = Some (ctx.im, row)`
compared the whole assembly's image, megabytes of tables, for each
method looked up; by `==` on the image, 22 s to 2.2. A polymorphic
`=` on a structure that holds something big is invisible in the ML
profile (the time is the runtime's) and in the code (it reads as a
small test): page_table_lookup high in a profile is its sign, compare
walking values the GC does not own.

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
- **A count moved by one major collection.** mini-ml's major
  collection copies all that is alive, and when it comes depends on
  the heap's size more than on the change measured: a change that
  allocates a little more can add one, 100 million instructions in a
  compile of mini-ml's Lower (plan_ml_speed.md's 4d: 1.023 at the
  default heap, 1.000 with ML_HEAP 4M to 16M words). Measure at two
  or three heap sizes (`ML_HEAP`), or with one large enough for few
  majors, before believing a change of a few %.
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
7. A search in a list that grows with the input (`List.assoc`,
   `List.mem` of all so far): quadratic, invisible on small inputs.
   mini-asm's labels, mini-ld's arm64 pool (callgrind's signature
   above).
8. A cost paid by the second whatever happens (a sample of silence
   through the mixer, its limit, the conversion, the kernel's ring).
9. On .NET (mini-ml -dotnet's code, Microsoft's runtime): an exception
   for an ordinary miss (`Not_found` from a search, caught to say
   false or None): microseconds each, where OCaml's is a jump.
   lib_core's searches no longer raise for it (above).
10. A polymorphic `=` (or `compare`, `Hashtbl` on such a key) on a
   value that holds something big: an image, a table, a whole tree.
   It reads as a small test; the profile says `do_compare_val` and
   `caml_page_table_lookup`, the runtime's, not the ML function that
   asked (mini-dotnet's method lookup, above: `==` on the image).

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
