# Plan: a program that dies says where and how it came there: names and lines in a suicide's trace, in an uncaught exception's, in a kernel's panic, and then a debugger (`linker/`, `kernels/9pi/`, `languages/ml/runtime/`, `debuggers/`)

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

## What was tedious (2026-10-08, the survey)

Three messages of that day, each as it was shown, and what it took to
read it.

| the message | what it does not say | how it was read |
|---|---|---|
| `suicide: sys: trap: fault read va=0x35 pc=0x103ee4` (rio, on the board) | which function; who called it; even which program, when the line is read from a photo | mini-rio linked again with `mini-ld -v` (5l's `-a` listing: 262,312 lines), the address looked for, the last `TEXT` above it: `gc_full_major` |
| `rio: suicide: ... pc=0x10a0e0` (the same, another boot) | the same | the same: `ux_strings`, the runtime's, called when a program is started. Both in the runtime, given a value that is no pointer: the harm was done before, and where is not known. The caller would have said more |
| `Fatal error: uncaught exception Unix_error(_, "open", "/dev/bintime")` (TinyCameltry in a window, under QEMU) | the error (`_`); where `open` was called from | the kernel's `sysopen` given a print, twice, a kernel built each time; `gettimeofday` found by reading the game's loop |

And what there is to build on:

- **The kernel knows the stack and the registers** at a trap, and a
  process's segments. Since that day a second line follows a suicide
  (`Syscall.trace`, stage 0 below): `trace: lr=0x1698 sp=0x1fffff10:
  0x1698 0xe010 0x4274 0x87a8`, the stack's words that are addresses of
  the program's code. Numbers, and a guess: a word that looks like a
  return address is taken for one.
- **The linker knows every name**, its address, its frame's size and
  the file and line of each instruction (`Program.prog`: `where`,
  `frame`), and writes none of it: a Plan 9 executable's symbol table
  is empty (`Exe`, its header's `syms` 0), `-s` is accepted and does
  nothing. Its `-v` prints the listing used above.
- **Plan 9 has the formats and the method**: the a.out's symbol table
  (a value, a type, a name; a function's frame size as a symbol of its
  own, `.frame`; the files' names as `z` entries) and its pc/line
  table, written by 5l (goken's: the reference for the bytes), read by
  libmach, whose `ctrace` walks a stack exactly with them; `db` and
  `acid` are that library and a language (principia's `debuggers/`,
  `Debugger.nw`). xix's `debugger/` has `ksym.ml` only.
- **mini-9pi's `#p` has the files a debugger reads** (`mem`, `regs`,
  `text`, `ctl`, `note`: `Devproc`), how much of each works was not
  looked at.
- **mini-ml's runtime** prints an uncaught exception's name and
  arguments, an argument that is not a string or an integer as `_`,
  and has no backtrace (`caml_get_exception_backtrace` is refused).

## Principles

- **A trace is read by a person, on a screen, maybe from a photo**:
  names, not addresses to look up; the program's name on each line;
  short enough for a console of 80 columns.
- **One source of names: the executable's own symbol table**, Plan 9's,
  written by the linker. The kernel, a tool on the host, the runtime
  and a debugger read the same bytes. No side file to keep in step
  with a binary (the listing of that day was only right because the
  binary on the card was the one just linked).
- **mini-ld's bytes are 5l's** where 5l writes them (the twin's rule):
  goken's 5l and 7l say what a symbol table is, byte for byte. What is
  ours alone (mini-ml's names, its frames) goes in the same format.
- **Nothing is paid when nothing dies**: the table is not loaded with
  the program; a trace reads it from the image when it is wanted.
- **9pi's words stay 9pi's**: the trace is a line more, taken out of
  the sessions recorded from the C kernel (`Syscall.traced`, the
  Makefile's filter), not a change of the `suicide` line.

## Stages

| | what | who uses it | state |
|---|---|---|---|
| 0 | **The kernel's line of addresses** after a suicide: lr, sp, the stack's words that are in the text (16 at most) | a person with `mini-ld -v`'s listing | done 2026-10-08 (`Syscall.trace`) |
| 1 | **mini-ld writes the symbol table**: Plan 9's, for `-H2`; ELF's for `-H7`; `-s` leaves it out. Text, data and bss names, a function's frame (`.frame`), the files and the pc/line table. The bytes compared with goken's 5l and 7l on the recorded programs (`linker/tests`) | everything below | |
| 2 | **`mini-nm`, and a tool that names addresses**: an executable and addresses (or a `trace:` line pasted) give `name+offset file:line` each. On the host, today's listing in one command | a person, from a photo of the board | |
| 3 | **The walk is exact**: from the pc, its function and its frame's size give where its return address is, and so the caller, to the program's start (libmach's `ctrace` for arm, then arm64). A leaf's caller is in lr. The guess of stage 0 goes | the tool of 2 given `sp`, `lr` and the stack's bytes; then the kernel | |
| 4 | **The kernel prints names**: at a suicide the table is read from the process's image (its text segment's channel is open) and the line is `trace: ux_strings+0x10 < exec+0x44 (Sys_plan9) < start+0x90 (Rio) < ...`, one more with the files and lines if asked (`#c` or a boot variable). No table: stage 0's addresses | the author at the board | |
| 5 | **An uncaught exception says more** (its first half done 2026-10-13, by a guess and a side file: Status): every argument printed (a constructor's name, `Unix_error`'s error as its message: no `_`), and where it was raised and through whom, by the same walk from inside the runtime (the stack as it was at the raise: mini-ml's handlers are a chain, the walk is made before it is cut, when no handler will take it, or at each raise behind a flag) | whoever runs an ix program, on any system | |
| 5a | **The names said by the program itself, on the board**: no `scripts/where.sh`, no host. The runtime, when it prints a trace, reads the symbol table of its own image (stage 1's; Plan 9: `/proc/$pid/text`, which `Devproc` has; Linux: `/proc/self/exe`) and prints `raised at: Tilemap.get+0x48 < Breakout.brick_at+0x30 < Breakout.move_ball+0x1c4 < ...`, a line of names an 80 column console holds, the unit's name and not `f27_get<>` (decision 2). Only when a program dies: nothing read before. Until stage 1, the same from `program.map` if the card has it beside the program (decision 7) | the author at the board, from a photo | |
| 5b | **The sources on the card, and the line of code in the trace**: `/src` has what the card's programs are made of (decision 8), in the tree's own layout (`/src/lib_graphics/Draw.ml`). With the pc/line table (stage 1, decision 3) a trace's first lines can be `Tilemap.ml:137  let get t col row = t.cells.(row).(col)`: the file and line from the table, the text read from `/src` when it is there (no `/src`, or a file changed since: the file and line alone). And without any trace: the system's sources are read on the system (`emacs /src/windows/Window.ml`), which is what Plan 9's `/sys/src` is for | the author at the board; a reader of the system on the system | |
| 6 | **The kernel's own panic**: `panic:` and a guard's message (`Main.guard`) with the kernel's stack walked; its names from `kernel.elf` on the host first (stage 2's tool), in the kernel later if wanted | who debugs mini-9pi | |
| 7 | **A process that died stays to be looked at** (Plan 9's Broken state, a limit on how many), and **mini-db**: `$c` the stack, `$r` the registers, a symbol's value, memory printed, through `#p`'s `mem` and `regs`. Then breakpoints and steps (`ctl`), and whether acid's language is wanted | the author, at mini-9pi's console | |

Stages 1 to 4 are the request; 5 is the same work for the third
message of the survey; 6 and 7 are what comes after, and may wait.
5a and 5b are the request of 2026-10-13, below: they need stage 1 (the
table in the program) to be done as the principles say, and 5a can be
had sooner from the map.

## Decisions to take

1. **Are symbols on by default?** 5l writes them unless `-s`. TinyCameltry's
   text is 1.5 MB; its table would be some tens of KB of names and as
   much of lines (to measure at stage 1). The card's programs are in
   the kernel's image, which is loaded whole at boot. Proposed: on, and
   measured.
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
6. **The debugger's shape** (stage 7): `db`'s commands, small and
   known, or acid's language, larger and Plan 9's own way. Not needed
   before stage 4 is lived with.

7. **The map, or the table?** (5a) Since 2026-10-13 mini-ld writes
   `program.map` beside every program (`-map`: a function's address
   and name a line; mini-stats's is 35 KB for 698 KB of program), read
   on the host by `scripts/where.sh`. It is the side file the
   principles refuse: right only for the binary it was written with.
   Two ways to names on the board: the maps copied to the card beside
   the programs and read by the runtime (a day's work, some 5% more
   card, and a map that can be stale), or stage 1 first and the table
   read from the image (the principle; the linker's twin work).
   Proposed: stage 1, then 5a from the image, and the map and
   `where.sh` removed; the maps on the card only if stage 1 is to wait.
   **Decided** (the author, 2026-10-13: "we can support both the table
   in the binary and an external Map possibly with more info"): both.
   The table in the program is what a trace needs and is always
   there; the map stays, beside the program, for what the table has
   no room or no place for (to say at stage 1: each function's size
   and frame, its unit and its file, the lines, what mini-ml knows of
   a function's arguments). A reader takes the table first and the
   map when it is there and is the program's (the two are to say
   which link they are of: a stale map is not read). The principle
   "one source of names" above becomes: one source that is always
   right, and a second that may say more.
8. **What is `/src`?** (5b) The author: "copy the source of m-ix and
   t-ix under /src on the card". Counted 2026-10-13 (`git ls-files`,
   `.ml .mli .c .h .s .mly .mll`, tests apart): 11.9 MB for the whole
   tree, of which `tiny/` (t-ix) 1.5 MB; the card is 128 MB with its
   second partition's programs. Proposed: all of it, as files of the
   card's file system in the tree's layout, made by `make card` from
   `git ls-files` (what is committed, not what lies in the working
   tree), with the commit's hash in `/src/VERSION` so that a trace can
   say when the sources are not the program's. To check first: how
   long the card's file system takes to make and to list with some
   3,000 files more, and whether it wants to be a third partition
   mounted when asked. **Decided** (the author, 2026-10-13: "yes, I
   like your suggestion and /src/VERSION"): all of it, from what is
   committed, with `/src/VERSION`.
9. **Whose file and line, when the table says an address?** (5b) The
   table gives the line of the instruction; an exception's trace has
   return addresses, whose line is the call's (the address less one
   instruction: what `exceptions.c` already prints). A function
   inlined or a tail call has no line of its own: the caller's is
   said, as decision 4.
10. **Still a guess, or the exact walk?** The trace of 2026-10-13
   takes a word of the stack for a return address by its look (as
   stage 0's kernel line): a line too many now and then. Stage 3's
   walk needs each function's frame, which mini-ml's code has not on
   the machine's stack in the usual way (its values are on a stack of
   their own, the machine's has little but return addresses): the
   guess is nearly exact there, and wrong mostly in the runtime's C
   frames. Proposed: keep the guess in mini-ml's code, and stop a
   trace at the first C frame it cannot walk. **Decided** (the author,
   2026-10-13: "ok, but at some point we can probably imitate more
   what principia/goken are doing for the debugger (and profilers)"):
   the guess for now; later their way, which is stage 3's exact walk
   (libmach's `ctrace`, by each function's frame) and stage 7's db
   and acid, and for the profilers what Plan 9 has and ix has not:
   `prof` over a program's `#p` profile segment and the kernel's
   `kprof` (a clock's samples by address, named by the same table),
   where ix's today count every instruction under an emulator
   (`machine/tests/profile.sh`, mini-qemu's `-prof`:
   `docs/notes_profiling_techniques.md`). To be read in principia's
   `debuggers/` and `profilers/` and in goken before it is planned:
   written here from memory.

## Tests

- Stage 5a: the program of stage 5's test run on mini-9pi from the
  card (a session of `tests/session-card-*`): its names on the
  console, no address.
- Stage 5b: the same with `/src` there and without: the line of code,
  or the file and line alone.

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
  recorded, on Linux and on Plan 9.

## Out of scope

- Source-level stepping in OCaml, values printed by their types: a
  debugger for mini-ml is another plan.
- DWARF. ELF executables get ELF's symbol table, no more.
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
(names on the board) and 5b (`/src` on the card, the line of code in
the trace), decisions 7 to 10, their tests. Stage 0 is committed
since. Nothing of 1 to 4 is begun; the exception that asked for all
this is not found (`docs/plans/bugs/ix.md`).

