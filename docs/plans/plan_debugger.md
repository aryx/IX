# Plan: a program that dies says where and how it came there, and m-ix gets a debugger: the tables (`linker/`), the traces (`kernels/9pi/`, `languages/ml/runtime/`), mini-acid (`debuggers/`), and replay (`machine/`, `raspberry/`)

The author (2026-10-08), the day mini-9pi first ran on his Pi1, rio
dying there and nowhere else: "we should aim to improve the suicide
error message with an error trace or something to make it easier to
debug; this will probably be related to the debugger plan too"; and:
"we need to improve the plan debugger document to improve those stack
traces, including suicide trap, otherwise it is tedious to debug for a
human". There was no such document: this is it. It starts from the
traces, which is what was missing that day, and ends at a debugger,
which is the same knowledge (a program's symbols, its stack's layout)
used by a person and not by a message.

Rewritten 2026-10-29, after a survey of what m-ix still misses for
the whole-system teaching of Principia Softwarica (the author: "is
there any essential programs missing for m-ix? [...] anything
fundamental left to cover"): the debugger is the one book of
principia's with no program of m-ix, while t-ix has its own (`debug`
and `trace`, plan_tiny_debugger.md). The author then: "Regarding the
mini-debugger, should we do a mini-db or mini-acid or a mini-
something else? Is acid the best debugger to port to OCaml? Anything
more recent that we could steal ideas from that helps even more the
debugging process?", and of the answer: "I like your plan", "1 and 2
could go together" (the debugger and the profiler: they read the same
tables, plan_profiler.md's stage 5), "yes let's rewrite and adapt the
plan". What changed: stage 7's "mini-db, or acid's language" is
decided (decision 6: mini-acid), and three stages are new, from
debuggers more recent than Plan 9's: replay and reverse execution
(rr), the program's own tables read by its runtime (Go's pclntab, 5l's
descendant), time travel in the playground (Elm's debugger).

## What was tedious (2026-10-08, the survey)

Three messages of that day, each as it was shown, and what it took to
read it.

| the message | what it does not say | how it was read |
|---|---|---|
| `suicide: sys: trap: fault read va=0x35 pc=0x103ee4` (rio, on the board) | which function; who called it; even which program, when the line is read from a photo | mini-rio linked again with `mini-ld -v` (5l's `-a` listing: 262,312 lines), the address looked for, the last `TEXT` above it: `gc_full_major` |
| `rio: suicide: ... pc=0x10a0e0` (the same, another boot) | the same | the same: `ux_strings`, the runtime's, called when a program is started. Both in the runtime, given a value that is no pointer: the harm was done before, and where is not known. The caller would have said more |
| `Fatal error: uncaught exception Unix_error(_, "open", "/dev/bintime")` (TinyCameltry in a window, under QEMU) | the error (`_`); where `open` was called from | the kernel's `sysopen` given a print, twice, a kernel built each time; `gettimeofday` found by reading the game's loop |

The second line is the hardest kind: the crash is where a bad value
is used, the bug where it was written, earlier. Names and an exact
stack say where it was used; only a debugger that goes back in time
says where it was written (stage 10).

And what there is to build on (2026-10-29):

- **The kernel knows the stack and the registers** at a trap, and a
  process's segments. A second line follows a suicide (`Syscall.trace`,
  stage 0): `trace: lr=0x1698 sp=0x1fffff10: 0x1698 0xe010 0x4274
  0x87a8`, the stack's words that are addresses of the program's code.
  Numbers, and a guess: a word that looks like a return address is
  taken for one.
- **The linker knows every name**, its address, its frame's size and
  the file and line of each instruction (`Program.prog`: `where`,
  `frame`), and writes none of it in the executable: a Plan 9 a.out's
  symbol table is empty (`Exe`, its header's `syms` 0), `-s` does
  nothing. It writes `program.map` beside it (`-map`, since 2026-10-13:
  a function's address and name a line), read by `scripts/where.sh`
  and by mini-prof.
- **Plan 9 has the formats and the method**: the a.out's symbol table
  (a value, a type, a name; a function's frame size as a symbol of its
  own, `.frame`; the files' names as `z` entries) and its pc/line
  table, written by 5l (goken's: the reference for the bytes), read by
  libmach, whose `ctrace` walks a stack exactly with them. Principia's
  `debuggers/`: libmach (9,800 lines of C, all the machines), `db`
  (3,800, its book `db.nw`), `acid` (7,600, a yacc grammar and an
  interpreter) and `ratrace`, the two last the subject of the book
  `Debugger.nw`: its chapters are the kernel's support (`/proc`'s
  `ctl`, `mem`, `regs`, the breakpoint's instruction, broken processes),
  ratrace, then acid. xix's `debugger/` has `ksym.ml` only.
- **mini-9pi's `#p` lists the files a debugger reads, and serves few of
  them** (`Devproc`): `status`, `args`, `fd`, `ns`, `segment`, `noteid`
  read; `ctl` takes `kill` alone, `note` and `notepg` are written; `mem`,
  `regs`, `text`, `profile`, `kregs`, `fpregs`, `syscall` refuse.
- **mini-ml's runtime** prints `raised at:` and addresses after an
  uncaught exception (2026-10-13, a guess as stage 0's), an argument
  that is not a string or an integer as `_`.
- **t-ix has done it small** (plan_tiny_debugger.md, done): `debug`
  (breakpoints, steps, registers, a backtrace by the ML value stack,
  db's road: commands, no language) and `trace` (a process's system
  calls, ratrace's), over a trace descriptor of tiny-kernel's.
- **ix's emulators are the CPU**: mini-5i (a program, Linux's or Plan
  9's calls) and mini-qemu (a board, the kernel with it) run every
  instruction themselves and are deterministic but for what comes from
  outside: what no debugger of a real machine has for free.
- **The card has the sources**: `make card-self`'s `/src` is the
  repository (plan_self_hosting.md), the everyday card five examples.

## Principles

- **A trace is read by a person, on a screen, maybe from a photo**:
  names, not addresses to look up; the program's name on each line;
  short enough for a console of 80 columns.
- **One source of names that is always right: the executable's own
  symbol table**, Plan 9's, written by the linker. The kernel, a tool
  on the host, the runtime, mini-acid and mini-prof read the same
  bytes. The map may say more beside it (decision 7).
- **mini-ld's bytes are 5l's** where 5l writes them (the twin's rule):
  goken's 5l and 7l say what a symbol table is, byte for byte. What is
  ours alone (mini-ml's names, its frames) goes in the same format.
- **Nothing is paid when nothing dies**: the table is not loaded with
  the program; a trace reads it from the image when it is wanted.
- **9pi's words stay 9pi's**: the trace is a line more, taken out of
  the sessions recorded from the C kernel (`Syscall.traced`, the
  Makefile's filter), not a change of the `suicide` line.
- **mini-acid is acid's twin**: its language, its commands and its
  library (`port`, `arm`), principia's acid the reference, run on
  mini-9pi on the same programs. What is ours (OCaml's values, replay)
  is added in acid's own way: acid code, and builtins.
- **The emulator is the debugger's best friend**: what needs every
  instruction or every write (replay, going back, a watchpoint) is done
  in mini-5i and mini-qemu, not asked of the kernel.

## Stages

The traces first (0 to 6), then the debugger on them (7 to 9), then
what the emulators make possible (10, 11), the playground's (12).

| | what | who uses it | state |
|---|---|---|---|
| 0 | **The kernel's line of addresses** after a suicide: lr, sp, the stack's words that are in the text (16 at most) | a person with `mini-ld -v`'s listing | done 2026-10-08 (`Syscall.trace`) |
| 1 | **mini-ld writes the symbol table**: Plan 9's, for `-H2`; ELF's for `-H7`; `-s` leaves it out. Text, data and bss names, a function's frame (`.frame`), the files and the pc/line table. The bytes compared with goken's 5l and 7l on the recorded programs (`linker/tests`) | everything below, and mini-prof (plan_profiler.md) | |
| 2 | **`mini-nm`, and a tool that names addresses**: an executable and addresses (or a `trace:` line pasted) give `name+offset file:line` each; `where.sh` goes | a person, from a photo of the board | |
| 3 | **The walk is exact**: from the pc, its function and its frame's size give where its return address is, and so the caller, to the program's start (libmach's `ctrace` for arm, then arm64). A leaf's caller is in lr. The guess of stage 0 goes | the tool of 2 given `sp`, `lr` and the stack's bytes; then the kernel | |
| 4 | **The kernel prints names**: at a suicide the table is read from the process's image (its text segment's channel is open) and the line is `trace: ux_strings+0x10 < exec+0x44 (Sys_plan9) < start+0x90 (Rio) < ...`, one more with the files and lines if asked (`#c` or a boot variable). No table: stage 0's addresses | the author at the board | |
| 5 | **An uncaught exception says more** (its first half done 2026-10-13, by a guess and a side file: Status): every argument printed (a constructor's name, `Unix_error`'s error as its message: no `_`), and where it was raised and through whom, by the same walk from inside the runtime. The names: stage 9's descriptions of the types, read by the runtime | whoever runs an ix program, on any system | half |
| 5a | **The names said by the program itself, on the board**: the runtime reads its own image's table (Plan 9: `/proc/$pid/text`; Linux: `/proc/self/exe`) and prints `raised at: Tilemap.get+0x48 < Breakout.brick_at+0x30 < ...`, the unit's name and not `f27_get<>` (decision 2). Go's way (its pclntab, 5l's table grown up): a program that names its own frames needs no debugger and no host | the author at the board, from a photo | arm |
| 5b | **The line of code in the trace**: with the pc/line table, `Tilemap.ml:137  let get t col row = t.cells.(row).(col)`, the text from `/src` when it is there and is the program's (`/src/VERSION`; card-self's `/src` is the repository) | the author at the board; a reader of the system on the system | |
| 6 | **The kernel's own panic**: `panic:` and a guard's message (`Main.guard`) with the kernel's stack walked; its names from `kernel.elf` on the host first (stage 2's tool), in the kernel later if wanted | who debugs mini-9pi | |
| 7 | **The kernel's support, Debugger.nw's chapter**: `#p`'s `mem` and `regs` read and written, `text` the image, `ctl`'s `stop`, `start`, `startstop`, `waitstop`, `hang`, `kill`; the breakpoint's instruction (a trap the kernel turns into a stop); a process that died kept Broken to be looked at (a limit on how many). Then `syscall` and ctl's `startsyscall`: **mini-ratrace**, t-ix's `trace`'s twin, as small, the first user and the test of the device | mini-acid; a person tracing a program's calls | |
| 8 | **mini-acid**: acid's language (lists, strings, integers, its C-like statements and its `defn`), its builtins (`print`, `mem`, `map`, `symbols`, `new`, `start`, `stop`, `bpset` underneath), its library in acid (`port`: `stk()`, `lstk()`, `bpset()`, `cont()`, `step()`; `arm` for the registers), over stage 1's table and stage 7's `#p`. Principia's acid run on mini-9pi on the same program the reference: the same answers (decision 11) | the author, at mini-9pi's console, in a window of rio | |
| 8a | **mini-acid on this machine's programs**, not only mini-9pi's (the author, 2026-10-29: "It would be great if the debugger mini-acid could also debug binaries for this machine; the one produced by mini-c and mini-ml -a, with extra info, but maybe regular gcc binaries too with DWARF [...] plan9port already ported acid to also work on macos and Linux thx to an extended libmach. We could maybe imitate that too"). A third side of decision 12's interface: **Linux by ptrace**, as plan9port's libmach (`Linux.c`: `PTRACE_ATTACH`, the memory and registers by ptrace, `/proc` for a process's status), arm64 first (this machine), the registers by `PTRACE_GETREGSET`. The names: mini-ld -H7's ELF symbol table (stage 1's ELF part), then **DWARF read** for gcc's and clang's programs (plan9port's `dwarf*.c` and `symdwarf.c`: `.debug_line` for the lines, `.debug_info` for the functions, their variables and types, `.debug_frame` for the walk): what a debugger of today reads, beside Plan 9's two tables, for its teaching value. **macOS**: Mach-O read (plan9port's `macho.c`, `symmacho.c`), its processes later: plan9port's `Darwin.c` is `nosys.c`, no process control (macOS asks a signed debugger for `task_for_pid`) | the author, debugging ix's programs and gcc's on Linux | |
| 9 | **OCaml's values in mini-acid**: as `5c -a` writes acid's definitions of a C program's structs, mini-ml writes those of a unit's types (`mini-ml -a`): a constructor's name by its tag, a record's fields, a list as a list. A value printed by its type, where a debugger of mini-ml's code would print words; the same descriptions read by stage 5's runtime | mini-acid; stage 5 | |
| 10 | **Replay, and going back** (rr, Mozilla 2014; Pernosco; and before them ocamldebug's checkpoints, Vouillon, 1990s): mini-5i records what comes from outside (each system call's results, the signals' instants), and plays a run again exactly; snapshots along the way, and a run played to an instant from the nearest. Then going back: `reverse-continue` to the last write of an address (a watchpoint over the run played again), which is the question of the survey's second line: who wrote the bad value. mini-acid drives it by builtins | whoever debugs a crash whose cause was earlier: the collector's, the kernel's | |
| 11 | **The board's run played again**: the same in mini-qemu, the whole system (its interrupts' instants, the keyboard's, the card's, the network's bytes recorded), so a kernel's panic is replayed and gone back from; and a gdb remote stub, QEMU's `-s`, for the host's gdb on mini-9pi's kernel meanwhile | who debugs mini-9pi | |
| 12 | **Time travel in the playground** (Elm's debugger, 2016): a program of lib_playground is a model, an update and messages; the messages recorded, any instant is the first model updated by them. A slider over a game's past, its model shown | a reader of a game; the playground's teaching | |

Stages 1 to 4 are the first request; 5 is the same work for the third
message of the survey; 6 may wait. 7 and 8 are the debugger; 9 is
what makes it OCaml's; 10 to 12 are ix's own, what a debugger of today
does that Plan 9's did not, and can be had small because ix has its
own emulators.

Its order with plan_profiler.md (the author, "1 and 2 could go
together"): stage 1's table is mini-prof's names too (its maps then
the table, decision 7), stage 7's `#p` has the profiler's `profile`
file (plan_profiler.md's stage 5: Plan 9's tprof, the clock's samples
of a process's pc) beside the debugger's. One kernel stage serves the
two programs.

## Decisions to take

1. **Are symbols on by default?** 5l writes them unless `-s`. TinyCameltry's
   text is 1.5 MB; its table would be some tens of KB of names and as
   much of lines (to measure at stage 1). The card's programs are in
   the kernel's image, which is loaded whole at boot. Proposed: on, and
   measured. Measured (2026-10-29): mini-tar's a.out 20.2% larger with
   its tables, mini-ml's lines a function's (38% with the assembly's).
   **Decided** (the author, 2026-10-29: "let's not generate them by
   default for now"): off, mini-ld -g asks for them; scripts/where.sh
   and the maps stay meanwhile.
2. **mini-ml's names in the table**. Today a function of a unit is a
   symbol local to its object, numbered: `f27_prio<>` in that day's
   listing, and a unit's start `Rio.Init`. A trace wants `Rio.start`.
   Either the tools print what the linker has (the unit found by the
   symbol's file, `z` entries), or mini-ml names its functions by
   their unit (`Lower.mangle`). Proposed: the first, no change to the
   compiler, and see whether it reads well enough.
3. **Lines of which file?** mini-ml's objects carry a line an item;
   whether it is the `.ml`'s line or the generated assembly's is to
   check first. The `.ml`'s is what a person wants.
4. **How exact can the walk be in mini-ml's code?** A function's frame
   is fixed (the linker has it), which is all `ctrace` needs; a tail
   call leaves no frame, and its caller is then missing from the
   trace, as in any compiler. The runtime's C and assembly follow the
   same convention or the walk stops there: to check, function by
   function, at stage 3.
5. **Where the kernel reads the table**: from the image's channel at
   the suicide (a read that may sleep, in the process's own context:
   it is still there), not kept from exec. Proposed, as the principle
   above.
6. **The debugger's shape**. Plan 9 has two: `db`, adb's line (Unix's
   db of 1971, then adb, 1979): commands of a letter, a machine's view,
   small and known; and `acid` (Phil Winterbottom, 1994): a small core
   (a process's memory and registers, the symbols) and a language in
   which the rest is written, the stack's walk, the breakpoints, each
   machine's registers, the printing of a C program's types, which the
   compiler writes as acid code (`5c -a`). **Decided** (the author,
   2026-10-29, "I like your plan"): mini-acid. db's road is t-ix's
   already (`debug`); acid's is the idea worth a book, it is
   principia's (Debugger.nw), and its way of printing types is how
   OCaml's values get printed (stage 9). Its size: acid's 7,600 lines
   of C and the arm part of libmach, some 2,500 to 3,000 of OCaml with
   mini-yacc, within m-ix's budget (130,000 of 150,000).
7. **The map, or the table?** (5a) Since 2026-10-13 mini-ld writes
   `program.map` beside every program (`-map`: a function's address
   and name a line; mini-stats's is 35 KB for 698 KB of program), read
   on the host by `scripts/where.sh`. It is the side file the
   principles refuse: right only for the binary it was written with.
   **Decided** (the author, 2026-10-13: "we can support both the table
   in the binary and an external Map possibly with more info"): both.
   The table in the program is what a trace needs and is always
   there; the map stays, beside the program, for what the table has
   no room or no place for (to say at stage 1: each function's size
   and frame, its unit and its file, the lines, what mini-ml knows of
   a function's arguments). A reader takes the table first and the
   map when it is there and is the program's (the two are to say
   which link they are of: a stale map is not read).
8. **What is `/src`?** (5b) **Decided** (the author, 2026-10-13: "yes,
   I like your suggestion and /src/VERSION"): all of the tree, from
   what is committed, with `/src/VERSION`. Since done for card-self
   (plan_self_hosting.md: the repository but docs/); the everyday card
   has five examples; `/src/VERSION` is to do.
9. **Whose file and line, when the table says an address?** (5b) The
   table gives the line of the instruction; an exception's trace has
   return addresses, whose line is the call's (the address less one
   instruction: what `exceptions.c` already prints). A function
   inlined or a tail call has no line of its own: the caller's is
   said, as decision 4.
10. **Still a guess, or the exact walk?** **Decided** (the author,
   2026-10-13: "ok, but at some point we can probably imitate more
   what principia/goken are doing for the debugger (and profilers)"):
   the guess for now in mini-ml's code (its values are on a stack of
   their own, the machine's has little but return addresses: the guess
   is nearly exact there, wrong mostly in the runtime's C frames); later
   their way, stage 3's exact walk (libmach's `ctrace`, by each
   function's frame), stage 8's acid, and for the profilers what Plan 9
   has and ix has not, `prof` over `#p`'s profile and the kernel's
   `kprof` (plan_profiler.md's stage 5).
11. **How mini-acid is tested against acid.** Principia's acid runs on
   Plan 9; mini-9pi is one once stage 7 serves `#p`. Proposed: a
   program of C (by mini-cc, 5c's bytes) stopped at a breakpoint, the
   same script of acid commands given to both on mini-9pi under
   mini-qemu, their outputs compared (a recorded session); mini-ml's
   programs then by mini-acid alone (acid knows nothing of them).
   Until stage 7, mini-acid on a core file or under mini-5i (decision
   12).
12. **Where the process lives while mini-acid is written.** Acid's
   core asks of a process: read and write its memory and registers,
   start, stop, step. Behind one interface (libmach's `Map` and its
   procedures), three sides: `#p` on Plan 9, mini-5i (a debugging
   protocol of its own, or mini-5i and mini-acid linked in one process
   for the tests), and ptrace on Linux (stage 8a). Proposed: mini-5i
   first, so that mini-acid is written and tested on the host before
   the kernel has stage 7, and the same side serves stage 10's replay;
   ptrace then (a few calls, but C: a stub of lib_core's behind a
   capability, Cap.ptrace, in OCaml's runtime and mini-ml's). What
   plan9port has and not (its sources, 2026-10-29): Linux, FreeBSD and
   others by ptrace, macOS none; its machines 386, amd64 and power, no
   arm: the arm and arm64 parts are principia's libmach's (5db, 7db).
   **Decided** (the author, 2026-10-29, of three ways: a protocol of
   mini-5i's, mini-acid and mini-5i linked, or "a /proc served by
   mini-5i"): **mini-5i serves Plan 9's /proc**, and mini-acid is a
   Plan 9 program beside its target, reading `/proc/$pid/{mem,regs,
   ctl,status,text}` as it will on mini-9pi: one side, not two. How,
   since each of mini-5i's processes is a host process of its own
   (rfork is the host's fork), the target's memory in another
   emulator:
   - the debugger's mini-5i synthesizes another pid's files (as
     `/proc/$pid/note` and `text` are, its own); a request goes to the
     target by a signal (SIGUSR1) and a Unix socket the target then
     opens (`$TMPDIR/mini-5i-$uid/$pid`): the loop's check for notes
     (Linux.signal_waiting) is where it is served. Nothing is made and
     nothing polled for a program no one debugs;
   - while a debugger talks to it, the target is stopped; requests:
     read and write its memory, its registers (Plan 9's Ureg for arm),
     ctl's stop, start, waitstop, startstop, hang, kill; a breakpoint
     (an undefined instruction, 5db's) stops it and it waits on its
     socket, Stopped in its status;
   - a write to the text flushes mini-5i's cache of decoded
     instructions (it assumes no code is written: plan_arm.md,
     decision 5);
   - a target blocked in a host call (a read of the console) answers
     when the call returns: a limit of the first version.
13. **What replay records, and its cost.** mini-5i is deterministic but
   for its system calls (their results, the bytes they read), its
   signals and its time: a log of those is a run. rr's design, without
   rr's hard part (counting instructions on a real CPU's counters):
   mini-5i counts them. Snapshots: the memory's segments copied every
   N instructions (or by pages changed). Proposed: a run of mini-doom's
   start recorded, its log's size and the replay's speed measured first;
   threads (mini-5i runs them one at a time) in the log as switches at
   counted instants.
14. **Where a program's types are described** (stage 9, C's and
   OCaml's). Plan 9's: 5c -a writes acid's declarations of a file's
   structs (aggr: a member's format and offset), a function printing
   each, and a local's type (complex Node walk:n), in a file loaded
   with -l. **Decided** (the author, 2026-10-30: "show values in a nice
   way, in C and ML", "leveraging metadata generated by the compiler";
   mini-ml's descriptions "In the program", and "for C we should also
   have the option to embed them (like in Go? like in DWARF?)"): the
   compilers describe the types; the descriptions in the program
   (-g), for C and OCaml alike, besides 5c -a's file for C (compared
   with 5c's, and principia's acid reads it); one printer of a value by
   its description, in acid, ix's library's. The steps: mini-acid's
   complex types (complex, ., ->, a cast, f:v, print calling a type's
   function, acid's), then mini-cc -a, then the printer, then OCaml's
   values without a description (their headers), then mini-ml's
   descriptions. The format in the program (the author, at mini-cc -a's
   step: "Acid text"): acid's text, -a's, a data symbol .acid that
   mini-acid runs as a library; stage 5's runtime would parse it.

## Tests

- Stage 1: the recorded executables of `linker/tests`, linked with
  symbols, the same bytes as goken's (`mkfiles/check_arm.sh` has the
  comparison without them).
- Stages 2 to 4: a program made to die at a known depth
  (`kernels/9pi/tests/`: a function that calls a function that reads
  address 0; one in mini-ml, one in C by mini-cc), its trace recorded:
  the names in order. The session `tests/session-c` already has a
  suicide (`hoc -e 1.5*2`).
- The two addresses of the survey, kept as a case: `0x103ee4` and
  `0x10a0e0` in that day's mini-rio are `gc_full_major` and
  `ux_strings`.
- Stage 5: a program that raises through three functions, its message
  recorded, on Linux and on Plan 9; 5a: the same from the card, its
  names on the console, no address; 5b: with `/src` and without.
- Stage 7: mini-ratrace against principia's ratrace on mini-9pi, the
  same program's calls (decision 11's way); `#p`'s files read by `cat`
  and `xd` in a recorded session.
- Stage 8: decision 11; mini-acid's language alone by unit tests, its
  library's functions on a program of C stopped under mini-5i
  (decision 12).
- Stage 9: a unit's types printed by mini-acid, against what OCaml's
  toplevel prints of the same values.
- Stage 10: a program whose bug writes a bad value early and crashes
  late (a C program, then the survey's kind: a mini-ml program with a
  bad external); the reverse watchpoint names the write; a recorded
  run replayed gives the same instructions' count and output.

## Out of scope

- DWARF written: mini-ld's ELF executables get ELF's symbol table, no
  more. DWARF read is in (stage 8a), gcc's programs debugged.
- Source-level stepping in OCaml at first: stage 8 steps by
  instructions and lines, as acid does in C; a step by expression is
  another plan.
- The Debug Adapter Protocol and an IDE's front end: mini-acid runs in
  a window of rio, as acid did; mini-emacs could later drive it as
  acme drove acid.
- Dynamic tracing (DTrace, eBPF): mini-ratrace covers the calls,
  mini-prof the time.
- The board's own debugging aids (JTAG, a serial monitor).

## Status

2026-10-08: the document, and stage 0. A suicide is followed by a
`trace:` line of addresses (`Syscall.trace`, on unless
`Syscall.traced` is false; `Arch.tf_lr`); the sessions recorded from
9pi take the line out and are the same (stage C's, under mini-qemu).
What rio died of on the Pi1 was found the same day without it, by
reading principia's and Linux's cache code beside ours
(`docs/plans/bugs/ix.md`): the next program that dies there is the
first whose trace is read.

2026-10-13: stage 5's first half, another way than the plan's, and
what it asks next (the author, of windows that stopped answering on
the Pi 2 and `Thread 5 killed on uncaught exception
Invalid_argument("index out of bounds")`: "would be good to add stack
traces"; then, of the script that names the addresses: "so that we
don't have to use this where.sh and the stack trace is directly
displayed in a human readable form from inside mini-9pi. Maybe we
could even copy the source of m-ix and t-ix under /src on the card so
we could even show the code"). Done, commit 3ef40c2a: mini-ml's
programs print `raised at:` and addresses after an uncaught exception,
the program's or a thread's (`languages/ml/runtime/exceptions.c`: the
16 top words of the machine's stack kept at each raise, the ones that
look like return addresses printed; on mini-9pi always, elsewhere with
`ML_TRACE`); mini-ld writes `program.map` (`-map`, every link);
`scripts/where.sh` names the addresses on the host. Against the
principles in two places, knowingly, to have something the same day:
a side file where the executable's own table was to be the one source
(decision 7), and a guess where the walk was to be exact (decision
10). Not done of stage 5: an exception's arguments still print as `_`
when they are not strings or integers. Added to the plan: stages 5a
and 5b, decisions 7 to 10, their tests. Nothing of 1 to 4 is begun;
the exception that asked for all this is not found
(`docs/plans/bugs/ix.md`).

2026-10-29: the plan rewritten around a debugger (the beginning): the
shape decided, mini-acid (decision 6); stage 7 the kernel's support
with mini-ratrace, 8 mini-acid, 9 OCaml's values by mini-ml's
descriptions of its types, 10 and 11 replay and going back in mini-5i
and mini-qemu, 12 time travel in the playground; decisions 11 to 13;
the profiler's stage 5 with stage 7. What `#p` serves today looked at
(above). Found the same day, writing mini-tar's differential test:
mini-5i faulted on a buffer across a Plan 9 program's bss and heap
(`docs/plans/bugs/ix.md`), fixed. Next: stage 1.

2026-10-29, later: stage 1, its first part, for arm. mini-ld -g writes
Plan 9's symbol table and pc/line table in an a.out (-m 5 -H2, new
module Symtab): etext, the data, the bss and the files' components in
5l's hash order, each function (L for a leaf) with its `.frame`, its
named parameters and locals, the history of its object before its
first function; the pc/line table as 5l's asmlc (a literal pool's
words and the branch around it line 0, as 5l's fresh progs). The
objects carry their history (Asm.obj's `history`), stored after the
object as a second value, so the objects and libraries of a checkout
made before are read as they were (no history), and an older linker
reads the new ones. mini-asm writes its file's history with the name
as given, as goken's 5a -r: an object the same bytes in any directory
(make self compares the card's with Linux's). Checked:
linker/tests/symtab.sh, the 43 arm programs of golden/ as a.outs with
their tables, the same bytes as goken's 5a -r and 5l -H2
(golden_symtab.txt, in make test; `live` against goken now). Not yet:
-g is asked for (decision 1 open: mini-tar's a.out is 38% larger with
its tables, 100 KB of symbols and 112 KB of lines, the lines mostly
the assembly's); mini-ml's objects have no history (decision 3: their
lines are the assembly's; Lower drops the AST's `eloc`: stage 1b, the
`.ml`'s lines through to the items); mini-cc's objects have no lines
(5c's history of the #includes, and its global lines); mini-asm's
#include (5a's push and pop around it); arm64 (7l's table) and ELF's
symbol table (-H7); stage 2's mini-nm, which reads them back.

2026-10-29, later still (the author: "and let's move forward on the
debugger plan"): stage 1b's first part, and stage 2.
- **mini-ml's lines** (decision 3): each function its body's line
  (Ir.func's and Ssa.func's `line`, from Scope's `loc`; 0 for the
  compiler's own, a curry or a unit's start), printed by Gen and Emit
  as a `// line n` comment before its TEXT, which mini-asm's lexer
  skips; mini-ml's driver (CLI's ml_lines) reads them back from the
  assembly, each item its function's line, and gives the object the
  .ml's history. The code made is the same (a comment more a function
  in the assembly). mini-tar's tables, lib_core's objects so made (in
  a copy of the tree): 98 KB of symbols, 14 KB of lines, 20.2% more on
  554 KB, where the assembly's lines made it 38%. A line a call's, not
  the function's: later, through Lower's code (a marker in Ir must not
  change what Opti and the ssa passes make).
- **lib_executable** (new, top-level: the author, "let's move
  lib_mach at the top, and maybe rename it to something better"; then,
  of lib_debug, "I'm not completely sure": Plan 9's libmach is linked
  by the debuggers, the profilers, nm, size, strip, ar, file and 5i, so
  the name says what it reads, an executable and later the process
  made of one; GNU's is BFD, binutils', and LLVM's libObject and
  DebugInfo): Symbols, an
  a.out's tables read back, libmach's syminit, pc2line, fileelem and
  fline (the history as a stack of the files open at a line); a
  function and its offset, a file and its line, for an address.
- **mini-nm** (`debuggers/nm`, since in `linker/tools` beside mini-ar, as principia's linkers/misc): Plan 9's nm, -aghnsTu, an a.out's
  table, and ix's objects and libraries (their names, no values);
  against principia's nm under mini-5i, the same but -n's equal values
  (nm.c's qsort, not copied, as mini-ls's). **mini-where**
  (`debuggers/where`): a trace's addresses, `name+0xoff file:line`,
  from the program's own tables; scripts/where.sh stays until the
  tables are on by default (decision 1).
- Checked: debuggers/tests/tables.sh (in make test: the hello a.out's
  names and lines as recorded; live, against principia's nm); mini-nm
  and mini-where built by mini-ml (mini-mk, arm64) answer as dune's on
  mini-tar's a.out.
Next: stage 3 (the exact walk); decision 1 taken, the tables off by default.

2026-10-29, stage 3 (the author: "let's move forward on stage 3"):
the exact walk, for arm. lib_executable's Frames: libmach's
risctrace, the return address at 0(SP) and the caller's sp .frame
bytes up (the link register for a leaf, or before the save), from the
pc to _main, 40 frames at most; a frame's address the call's (the
return address less 4), its line the call's (decision 9). **Decision
4 answered**: mini-ml's functions keep 5l's frame but make it
themselves (TEXT $-4: the table says L and .frame 0), so their
prologue is read from the text, `SUB $n, R13; MOVW R14, 0(R13)` (or n
from the pool through R11, then SUB R11, R13), gdb's way, the table
left 5l's; the runtime's C (mini-cc) has 5l's frames and the table's
.frame. The walk is exact through the three: an ML program dying
three calls deep under mini-5i,
`f2_down+0x1c Deep.ml:5 < f2_down+0x5c Deep.ml:5 < (twice more) <
Deep.Init+0x10 < ml_program+0x264 < main+0x180 < _main+0x20`, bad ()
inlined into down. Its first user: **mini-5i**, which after a Plan 9
program's segmentation fault prints the walk when the program has its
tables (`mini-5i: trace: ...`; Cpu.fault_pc, the faulting
instruction's address, kept by a handler around the loop, not by each
instruction). Checked: debuggers/tests/walk.sh (in make test: an
assembler program, 5l's frame and a leaf, its trace as recorded; an ML
one, its functions and lines, when _mk/5-plan9's lib_core is there);
mini-5i built by mini-ml prints the same. Not yet: arm64 (7l's
frames, mini-ml's on arm64); a fault inside a prologue other than the
first frame's (the walk stops); stage 4, the same walk by mini-9pi's
kernel at a suicide; stage 5, by the runtime at an uncaught exception
(its guess of 2026-10-13 replaced).

2026-10-29, stage 4 (the author: "let's commit and move forward"):
**mini-9pi names the frames at a suicide.** Syscall's trace reads the
dying process's tables from its text segment's image (decision 5: at
the death, not kept from exec; Fault.read_image, exported), the
header and the tables only (Symbols.read_with), and walks its stack
(Frames, over user_read), its line
`trace: f+0x10 a.c:12 < g+0x2c a.c:30 < _main+0x2c main9.s:30`; no
table, stage 0's addresses as before. The card's programs are
principia's, linked by 5l with their tables: under QEMU, session-c's
`hoc -e 1.5*2` now says
`hoc 47: trace: init+0x2c init.c:64 < main+0x14 hoc.y:169 < _main+0x2c main9.s:30`.
lib_executable made a kernel's: ocaml-light's library and language
only (no labels: walk takes (pc, sp, lr); no `; _` in a record
pattern; Frames opens Symbols, ocaml-light finding no field by its
record's type; its own cleanname and basename), a word read as two
halves of 16 bits (an int has 31 bits on arm), the text read through
the memory (the prologues), not kept. The kernel's units: the
Makefile's ML and the mkfile's KML, KNAMES and KI. The recorded
sessions' filter takes out either trace line (`trace: ` and anything,
where it was `trace: lr=`). Checked: the Pi 1's kernel by the Makefile
(ocaml-light), in a directory of its own (B=, IMAGE=), session-c under
QEMU: the line above, the rest as recorded; Symbols and Frames by
ocaml-light's ocamlopt and by mini-ml -m 5; compile_ix.sh on
kernels/ (75 of 75). Not run: session-c under mini-qemu, the other
sessions, the Pi 4's kernel by mini-mk, the board.

2026-10-29, stage 5a (the author: "let's do 1! and then 2", 2 being
this; then, of the names, the runtime reading its own table): **a
program names its own frames at an uncaught exception**, on arm, when
linked with its tables (mini-ld -g): under mini-9pi, by mini-qemu,
```
% /boot/raise
Fatal error: uncaught exception Deep(7)
raised at: f1_down+0x7c Raise.ml:6 < f1_down+0x90 Raise.ml:6 < ... < Raise.Init+0x10 < ml_program+0x264 < main+0x190 < _main+0x20 rt0.s:17
```
- **The raise keeps where it was.** A raise in ML was a jump (B
  ml_raise): its address was nowhere. Now `MOVW R15, R2` first (Gen's
  `raise_`, Emit's too: one instruction a raise, arm only), and C's
  raises go through `ml_raise_c`, which puts its call's address in R2
  the same way; ml_raise keeps R2, SP, the link register and the
  handler's SP when tracing (ml_raise_pc, _sp, _lr, _top). The stack's
  words kept went from 16 to 64 (four of mini-ml's 16-byte frames
  filled the 16: the walk ended at Init); the copy stops at the
  handler's SP, so a raise caught nearby copies few.
- **The walk, in the runtime** (languages/ml/runtime/frames.c, 387
  lines with comments): lib_executable's Symbols and Frames in C, what
  a trace needs (the function at an address and its .frame, mini-ml's
  prologue, pc2line, the history's file, its last component only). The
  stack below the handler's SP read from the words kept, above it from
  the stack itself (the frames there are still there when the trace is
  asked: the handler's, then ml_program's, main's). Done when the trace
  is asked (ml_uncaught, Printexc.get_backtrace, a thread's death), not
  at each raise; the table read once, at the first.
- **The table, from the program's image**: Plan 9's `/proc/$pid/text`.
  mini-9pi's served it no more than its name (mode 000): Devproc reads
  the text segment's image (Fault.read_image, through a hook Main sets:
  Fault is after Devproc); mini-5i serves the a.out it loaded. libc
  gets Plan 9's getpid (os/plan9/getpid.c, principia's: #c/pid); the
  runtime reads by seek and read (Linux's libc has no pread).
- Without a table, or a raise whose R2 is not a raise's (an object
  made by an older mini-ml: `MOVW R15, R2` or a BL is checked at the
  address), the guess of 2026-10-13, addresses. On Linux the a.out is
  an ELF without a table yet: the guess. arm64: the guess (no ADR in
  mini-asm yet to take a raise's address).
- Checked: debuggers/tests/walk.sh's third case (fault/Raise.ml: the
  exception and its frames under mini-5i, as recorded, in make test);
  a bound error raised from C (caml_array_bound_error+0xc first);
  mini-9pi with the program in its bootdir, above. On the way: the
  shared _mk's 425 start objects were from before ml_raise_c and were
  removed to be made again (mk does not remake what a changed compiler
  made: the third time today); smoke.sh's kernel says COMPILER=light,
  its build directory its own.
Not yet: arm64; the exception's arguments other than strings and
integers (stage 9's descriptions); 5b, the line's text from /src.

2026-10-29, stage 8 begun (the author: "let's resume our mini-acid and
debugger plan"): decision 12 decided, mini-5i serves Plan 9's /proc
(above). Stage 8's steps, each checked before the next:
1. **mini-5i's /proc between processes**: another pid's `mem`, `regs`,
   `ctl` (stop, start, kill), `status`, by the signal and the socket;
   checked by a C program (mini-cc) that forks a child, stops it,
   reads its registers and a word of its memory, starts it, and by
   rc's `cat /proc/$pid/status`.
2. **Breakpoints and steps**: the undefined instruction, `waitstop`,
   `startstop`, `hang` (stopped at exec: acid's `new()`); the
   instructions' cache flushed on a write to the text.
3. **mini-acid's language**: acid's lexer and grammar (lists, strings,
   integers, `defn`, `local`, `while`, `if`, `loop`, its operators),
   its interpreter; `print`, `mem`'s formats, the symbols as
   variables (lib_executable's Symbols); its `port` library read at
   start.
4. **`stk()` and `lstk()` on a stopped process**, then `bpset()`,
   `cont()`, `step()`: a session recorded under mini-5i (make test).
5. **On mini-9pi**: stage 7's #p, the same mini-acid, then decision
   11's comparison with principia's acid.

2026-10-29, stage 8's step 1: **mini-5i serves another process's
/proc.** A Plan 9 program under mini-5i opens `/proc/$pid/{mem,regs,
ctl,status,text,note}` of another process of mini-5i's, and reads and
writes them as on Plan 9 (machine/process/Proc9, 80 lines; Plan9's
`Other` files and the target's `answer`, 90). The request by SIGUSR1
and two named pipes a process (`/tmp/mini-5i-debug/$pid.{req,rep}`,
made by the debugger, removed when it kills its target; Host_calls
gets `mkfifo`, the only call added: no sockets, the machine runs where
OCaml runs); the target answers in Plan9.deliver, between two
instructions, and while stopped waits on its pipe for the next. The
registers as Plan 9's Ureg for arm (r0-r12, sp, lr, type, psr, pc);
a write to the memory sets Memory.code_written, and the CPU's cache of
decoded instructions is dropped at the next check. Checked:
debuggers/tests/proc.sh (in make test): proc/stop.c, by mini-cc, forks
a child that counts, stops it (its status says Stopped), reads its
count twice (the same), its pc (in main), writes a flag it reads
(seen: a word it counts in would be written over by its own store,
stopped between its load and its store), starts it, stops it, kills it
(await says killed). ix's libc for Plan 9 has no print, fprint,
errstr, strstr nor wait: the test formats by vsnprint and waits by
await. Not yet: a target blocked in a host call answers when the call
returns; the pipes of a target that exits by itself are left; arm64.
Next: step 2, breakpoints, waitstop, startstop, hang.

2026-10-29, stage 8's step 2 (the author: "let's commit and move
forward on step 2"): **breakpoints, startstop, waitstop, hang**, under
mini-5i, as Plan 9's kernel has them (principia's devproc.c and
proc.c's procctl):
- a breakpoint is 5db's BKPT (E1200070): mini-5i's CLI catches it
  (Arm32 raises Unimplemented for it) and runs again from it, its note
  `sys: breakpoint` posted, the pc left at it (Plan9.breakpoint): no
  cost an instruction. A process no one traces dies of it, as on Plan
  9 (a suicide);
- ctl's `startstop` starts a stopped process traced: its next note
  stops it before it is delivered (Proc_traceme), the note left for
  the debugger, who reads it from `/proc/$pid/note` (the first note,
  taken off); the debugger's mini-5i then asks `waitstop` without a
  signal: the target opens its pipe only once stopped, so the open is
  the wait;
- `hang`, written by a process to its own ctl, stops it at its next
  exec, before its first instruction (Plan9.load); it makes its pipes
  itself, for the debugger that comes (acid's `new()`);
- a process removes its pipes at its exit.
Checked: debuggers/tests/proc.sh's second program (proc/bp.c, by
mini-cc): a breakpoint written at a function of its child's, startstop
returns there (the pc at the function, the note `sys: breakpoint`),
the instruction put back, the child goes on and exits; a child hung at
its exec, waited for, started, runs its program. Three runs of three;
make test (its mini-lex and mini-yacc jobs failed once, another
session's ML files changing between their two passes; again alone,
they pass). Next: step 3, mini-acid's language.

2026-10-29, stage 8's step 3: **mini-acid's language** (debuggers/acid,
1,022 lines with its lexer and grammar): acid's lexer (Lexer.mll: a
newline a ; at the terminal but inside braces, formats after a
backslash, // comments), its grammar (Parser.mly, dbg.y's, its
precedences), its values with their formats (Value: a result takes its
left operand's format, ++ adds the format's size; lists as acid's
cells, changed in place by append and +; 64-bit integers, so that
mini-acid built for arm, 31-bit ints, computes as acid), its
interpreter (Eval: dynamic scope, a variable a stack of values; *p
parameters by name, eval; a bare expression printed at the top
level), its code printed back (Code: whatis, pcode's parentheses and
tabs), the language's builtins (print, fmt, fmtof, fmtsize, atoi,
atof, itoa, error, access, readfile), acid's prompt and its error
lines. Two ways it differs in its making, not its behavior: a
statement runs from the grammar's own action (prog: prog bigstmnt, as
dbg.y), not after the parse returns, which would want the next token
first; and dune's build uses ocamlyacc, not menhir, which reads the
token after a ; before running the statement, so a terminal answered a
line late (mini-yacc, ocamlyacc's twin, in the mkfile). The reference
is principia's acid itself, which now runs under mini-5i (mini-5i got
/fd/N, Plan 9's dup device: acid opens its input as /fd/0): its
library (port.acid, arm.acid) read by both and printed back by whatis,
141 lines the same; nine scripts (the language, eight errors) the same
byte for byte, the prompts included. Checked: debuggers/tests/acid.sh
(in make test: the scripts and acid's outputs recorded; live: acid run
again), mini-acid built by mini-ml for arm64 Linux and for Plan 9 arm
(under mini-5i), the same outputs. Not yet: the process (*, @, [] on an
address, complex types' . and casts, the registers, the symbols as
variables, start and stop), floats printed as Plan 9's %g. Seen of
principia's acid under mini-5i: a float stops it (VMOV, ee013190, not
in mini-5i), and it ends at its first error where it goes on at a
terminal (docs/plans/bugs/ix.md). Next: step 4, the process.

2026-10-30, stage 8's step 4, its first two parts: **mini-acid debugs
a process**, under mini-5i, beside it (debuggers/acid/Proc, the program
and the process). The program read (its a.out or /proc/$pid/text): its
symbols acid's variables, each its address, and symbols their list;
the registers' variables (5db's list: R0 to R15, PC, SP, TYPE, PSR,
their offsets in the Ureg) and bpinst; the maps as libmach's (the
registers below the Ureg's 72 bytes in /proc/$pid/regs, the text and
the data to the stack's top, from the segment file, in /proc/$pid/mem;
without a process, and for @, the file), so *, @, [] on an address
and an assignment through * read and write the process as acid's
indir and windir; the a format naming an address (libmach's symoff).
The process: newproc (a child that writes hang to its own ctl and
execs the program), setproc, start, stop, startstop, waitstop, kill,
status, reason (5db's armexcep), each stop reading the notes and
calling the library's stopped(pid); strace as libmach's risctrace
(_main not said, a leaf's return the link, a frame its .frame, the
called-from address the return less 8, the parameters and locals from
the table's p and a, in libmach's order), fnbound, pcfile, pcline,
follow (a branch's target and the next: enough for new()), match;
acidinit() after the libraries, as userinit; at the end, die's echo
kill > /proc/$pid/ctl. lib_core's Plan 9 Unix gets LargeFile.lseek
(the offset's two words as boxed int32s, the runtime's ux_arg): an
address above an int's 31 bits, the stack's, mini-acid being arm's.
Checked: principia's acid and mini-acid under mini-5i, the same
session on a C program (new(), bpset(leaf), cont(), stk(),
print(count), regs()): the same output but the instructions' text
(stk's leaf(a=0x0,b=0x4)+0x0 ?file?:0 < middle(x=0x3)+0x14 < main()+0x4
< _main+0x1c rt0.s:16, the registers, the stops' reasons); a static
session (no process: symbols, a's names, @, pcfile, pcline, fnbound,
follow's error) the same; make test (159 jobs). Next, the third part:
the i format, 5db's disassembler in Plan 9's syntax (mini-5i's printer
is objdump's), then follow complete (step, next), the session in make
test.

2026-10-30, stage 8's step 4, its third part: **the instructions and
the steps.** debuggers/acid/Das, 5db's arm disassembler and armfoll in
OCaml (written by a subagent from 5db.c, checked here): Plan 9's syntax
(MOVW.W R14,#-0x4(R13), MOVW R0,a+0(FP): a parameter named from the
table, plocal's), 5db's 128 opcodes, its quirks kept (an unsigned
compare in plocal, MOVM's popped pc, a long's wraparound), libmach's
qsort (not stable: of two functions at one address, acid names the
one it leaves last; the a format's symoff now the same); follow as
armfoll, its condition from the PSR, one address. The i format prints
an instruction, indir reads one. The file builtin (port.acid's
findsrc). Proc9's debugger side no longer waits on a target that died
(a step into exits hung): its pipes opened without blocking, again
while the target lives. Checked: the whole text of twelve of
principia's programs (ls, cat, rc, awk, stats, vi, acid, troff, rio,
5c, 8c, acme), 459,850 instructions, and random words forced into
every class, printed as acid prints them (ls and cat again here,
20,010 lines); debuggers/tests/acid_proc.sh (in make test, skipped
without principia's library): mini-acid for Plan 9 under mini-5i beside
a program by mini-cc, a session of new, bpset, cont, step, step, next,
stk, and one stepping from _main into exits, their outputs principia's
acid's recorded (live: acid again). Not yet: complex types' . and casts
(arm.acid's Ureg printing), floats as %g, mini-ml programs' frames
(their L .frame 0: libmach's walk reads the link, as acid does, not
their prologue), arm64, mini-9pi (stage 7's #p).

2026-10-30, mini-ml's programs under mini-acid, **in acid** (the
author: "hopefully those ml specific stuff can be done in acid's code,
proving the versatility of the acid as a debugger language approach",
then "we should aim for preferring to implement in acid when
possible"): debuggers/acid/lib/ml.acid, 113 lines, ix's library beside
port.acid. acid's stk() is libmach's walk and stops after mini-ml's
first frame (its functions say L and .frame 0 in the table); mlstk()
walks them by their prologues, read with acid's own @ and *: mini-ml's
SUB $n, R13; MOVW R14, 0(R13) (or n from the pool), and 5l's MOVW.W
R14, -n(R13) for the runtime's C, the link before the save. Nothing of
mini-acid's OCaml changed for it (a first try put the prologues in
Proc's strace, and was taken back out: acid's builtins stay libmach's).
The prologue is read in the program's file, @, as port.acid's cont
reads an instruction under a breakpoint. On the way: a Unix_error of a
process gone, in Proc's builtins and maps, is acid's error (process
exited), not mini-acid's crash. Checked: debuggers/tests/acid_proc.sh's
third session (acid/ml/Down.ml, by mini-ml for Plan 9 with its tables:
a breakpoint at down's entry, four conts, stk's two frames, mlstk's
down four times, Down.Init, ml_program, main, _main rt0.s:17; its
output mini-acid's recorded, acid having no ml.acid); make test (161
jobs). Seen: mini-ml inlined a function marked let[@inline never]
(another session's [@inline] work). Next: a breakpoint by a .ml line
(filepc, in acid if it can be), mini-ml's values by their types.

2026-10-30, **ix's own acid library** (the author: "we can write our
own if we think we can get the same functionality with lesser LOC and a
better design. We don't have to follow exactly what acid does; we want
some comparison tests [...] we don't have to cover every corner of
acid's functionality"): debuggers/acid/lib/port.acid and arm.acid, 327
lines of code where principia's are 581. Kept: new, bpset, bpdel,
bptab, cont, step, stmnt, next, func, stk, lstk, src, asm, mem, regs,
procs, stopped. Left: win and win2 (rio windows by scripts), Bsrc (the
plumber), the notes' Ureg printing (complex types), stkignore (regexp),
spsrch, labstk, casm, three readers of a source line where one does.
The design changed in one place: stk is one walk, port.acid's frames(),
by the functions' prologues (arm.acid's frame(): mini-ml's and 5l's), C's
and mini-ml's frames alike, its parameters and locals taken from the
builtin strace (the table's) while its frames are the walk's; ml.acid
folded in. A caller's place is its call (the return less 4), not
libmach's instruction before it. debuggers/tests/acid_proc.sh now runs
with ix's library, so make test needs no principia: three sessions as
recorded (two on a C program, one on a mini-ml one: its whole stack);
live compares the C ones with principia's acid and library, the same
but for the library's load lines, the callers' offsets (and so
_main's line), a line said once where acid's next says it twice.

2026-10-30, **stage 7, mini-9pi's #p for a debugger** (the author: "I
like this plan, let's do them one at a time starting with 1"): mini-acid
debugs a process inside mini-9pi, as under mini-5i, as principia's
kernel serves acid (devproc.c, proc.c's procctl):
- Devproc's mem (another process's pages made if not yet, read and
  written by their physical addresses: Usermem's debug_read and
  debug_write, through hooks Main sets; a write's instructions synced,
  Machine.Phys.sync), regs (the slot's trap frame, Machine's new
  tf_slot_bytes, as Plan 9 arm's Ureg: Ureg.plan9 and into_frame, the
  Pi1's and the Pi4's), note read (the first, taken), segment the stack
  first (libmach's stacktop), ctl's stop, start, startstop, waitstop,
  hang besides kill;
- the stop (Syscall.procctl, at notify's start, on every way back to
  user mode): a process asked to stop, or traced with a note pending,
  is Stopped (its psstate), its debugger woken (Stop_wait), itself
  asleep on Stopped until started or killed, the trap's type kept for
  its regs; hang taken at exec (Exec); a debugger told when its
  process exits (Sysproc);
- a breakpoint (BKPT, E1200070, at a pc whose page is there: a page
  faulted in for the check made the fault after it one of rights, the
  boot's first, a panic) is the note sys: breakpoint (Main.fault).
Not yet: Plan 9's txt2data (a text a fork shares is written for both),
the Pi4 (its Ureg written, not run), mini-ratrace.
Checked: kernels/9pi/tests/acid.sh, in make test's Pi 1 job (the kernel
by ix, relinked with a boot that runs mini-acid: new, a breakpoint,
cont, stk, a variable, step, stk, as recorded; 21 s); session-c
unchanged; the Pi 2's kernel by ocaml-light builds. mini-acid's status
reads the state at its place (devproc's fixed widths: a user may be
empty, then blanks split it wrong).

2026-10-30, **breakpoints by a source line**: filepc("Down.ml:5"),
acid's builtin (libmach's file2pc), in OCaml: lib_executable's
Symbols.file_pc walks the pc/line table once, each change of line with
the history in force there, the file named by its path or its last
components (Down.ml, arch/arm/rt0.s). Not in acid: by pcfile and
pcline, address after address, each reading the table again, it would
be quadratic, interpreted, under mini-5i; the primitive is the
table's, as Plan 9's acid has it. Then bpset(filepc(...)), src(*PC)
showing the line marked, are acid's as before. Checked:
debuggers/tests/acid_proc.sh's fourth session (acid/ml/line.acid: a
breakpoint at Down.ml:5, src, stk); the tests build lib_executable
first (mini-mk takes a library's archive as it is: a stale one lacked
file_pc). A line is still a function's in mini-ml's tables (its body's
line, decision 3), so next and stmnt on mini-ml's code go a function
at a time; a statement's line is stage 1b's rest.

2026-10-30, **mini-cc's line tables**: a C frame said ?file?:0, mini-cc's
objects carrying no history; now as 5c's (Hist): Pre records each file
read, its start (its name, the global line) and its end (the line
after it), the command line's file first, an #include by its name as
written, not the path found (5c's): an object the same whatever the
-I's directories, the card's and the host's (kernels/9pi/tests/smoke.sh
compares them: pow.5 differed). Each function's code takes its name's
line (the lexer's last name, Declare.nameline, kept at the function's
head), as mini-ml's (decision 3); data none. A statement's line is
next (the compat back end's, then ssa's). port.acid's next as acid's:
src printed once out of the function, not on a line inside it.
Checked: debuggers/tests/acid_proc.sh (4 sessions, the C frames now
target.c:11, :17, :26, re-recorded) and live (principia's acid: the
same); kernels/9pi/tests/acid.out re-recorded (the same three lines);
make test (161 jobs, 118 s).

2026-10-30, **mini-acid's complex types** (decision 14's first step):
complex T v, e.m and e->m (acid's odot: an aggregate member is its
address, the others read by their format, the member's own type kept),
(T)e, f:v (a parameter's or local's address in f's innermost frame,
libmach's localaddr, by strace's walk, now Proc.walk; its type complex
T f:v's), print calling a type's function on its address (acid's comx:
the Node(addr) 5c -a writes), whatis saying a variable's complex type.
A type is a binding's (acid's Value's comt): Point(addr)'s complex
Point addr leaves its caller's addr a Node; a symbol declared complex
is read with format a. Checked: debuggers/tests/acid_proc.sh's fifth
session (acid/types: a C program with structs, its declarations 5c -an's
by goken, recorded as target.acid: n1, n1.p.x, n1.next.p, a string
through two members, *walk:n, walk:q, a cast, whatis) and live: the
same as principia's acid with the same declarations; the C sessions
too.

2026-10-30, **mini-cc -a, and the declarations in the program**
(decision 14's second step): languages/c/Acid.ml, 5c's acid.c: a
structure's aggr and function once aligned (Declare.sualign), a
variable's complex T v or f:v and an enum's constants once declared
(dodecl, doenum), keywords $-named (amap), -aa without the #includes'
(Pre.depth), -n to x.acid (or -o's), no code. The same text as goken's
5c and 7c: languages/c/tests/acid.sh, listing.sh's 218 files of
goken's libraries and utilities, -a and -aa: 436 of 436 on arm and on
arm64 (needs goken: test-all's kind). Then -g (mini-cc): the
declarations in the object, after the history, a third value (an older
object read as before, without them); mini-ld -g: the linked objects'
declarations each once (every file says libc.h's), in their order, as
the data .acid; mini-acid runs it after the libraries. Checked:
debuggers/tests/acid_proc.sh: mini-cc -a on acid/types/target.c is
5c's recorded text; the types session again on the program by -g, no
-l: the same output; live as before (principia's acid ignores .acid).

