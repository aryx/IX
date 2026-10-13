# Plan: mini-dos, a DOS for the Pi in OCaml, its extender and its mode 13h (`kernels/dos/`)

The author (2026-10-12): "I know DOS didn't exist for the Pi, but how
many LOC would be a DOS like OS for the Pi?"; then, of why: "just for
the fun, for the teaching aspect of it to see how dos, and the DOS
memory extended used by games like DOOM was"; of the screen: "ideally
we could also have the "X" mode, int 13h if I remember with fancy
graphics"; then: "let's make a plan document for it". What he said of
Oberon holds ([`plan_system_oberon.md`](done/plan_system_oberon.md)):
not an exact twin, a system "given a place here, adapted to OCaml, and
reusing some of the existing code in ix", its look, feel and approach
kept, and the code "only in" its directory, the rest by symbolic
links.

mini-dos is **the kernel that is not one**: one program at a time, no
process, no protection, every program free to write anywhere and to
take any interrupt for itself. The other kernels of `kernels/` each
add something to a machine (processes, a name space, a virtual
machine); this one shows what programs did when the system gave them
almost nothing, and the three inventions that followed from it:

- **the resident program** (a program that takes an interrupt's
  vector and stays in memory);
- **the memory past the first megabyte**, first copied down by pieces
  (XMS), then lived in by a program that leaves the system's mode
  altogether and comes back to it for each call: **the extender**,
  DOS/4GW under DOOM;
- **the screen as memory**: mode 13h, 64,000 bytes and a palette.

**The picture to reach**: the board boots to `C:\>`; `DIR` lists the
card; a game is typed by its name, the extender's banner passes, and
a maze seen from inside is drawn at 320 by 200 in 256 colours, its
program in megabytes of memory DOS does not know of, reading its file
through DOS at each level.

What is kept, and what is free:

- **Kept: the approach.** Three layers, as IO.SYS, MSDOS.SYS and
  COMMAND.COM: a BIOS (the screen, the keyboard, the disk's sectors:
  ints 10h, 16h, 13h), a DOS over it (files, memory, programs: int
  21h), a shell that is the DOS's first program. **A table of 256
  vectors** in low memory that any program may read and write. Memory
  as a chain of blocks, each with its owner. Programs as flat images.
  The extender as **a program**, not a part of the system: DOS never
  learns that the processor's mode changed.
- **Kept: the feel.** `C:\>`, drive letters and backslashes, names of
  eight and three letters in capitals, `/` for a switch; `DIR`'s
  listing and its last two lines; `Bad command or file name`;
  `AUTOEXEC.BAT`; the extender's banner before a game; mode 13h's
  look, large pixels and a palette that fades.
- **Free: what is under.** The processor is an ARM, so the calls'
  registers are its own; the kernel is OCaml; the FAT is mini-9pi's;
  the BIOS is in the kernel's image and not in a ROM.
- **What the Pi cannot show** (said here once, and in "The limits"
  below): the 8086's segments, and the VGA's planes. Both were the
  processor's and the card's, not DOS's.

**Status**: the survey done and this plan written (2026-10-12);
nothing else is. The decisions are mine to propose, the author's to
take.

## The survey (2026-10-12, checked by `kernels/dos/survey.sh`)

Three references. **MS-DOS**, as Microsoft released it
(`github.com/microsoft/MS-DOS`: 1.25, 2.0 and 4.0, MIT). **FreeDOS's
kernel** (`FDOS/kernel`, GPL 2). And for what a game asks of DOS, of
the extender and of the VGA, **Heretic's `I_IBM.C`**
(`OpenSourcedGames/Heretic`, GPL 2): Heretic is DOOM's engine, and
DOOM's own release (`id-Software/DOOM`) has only the layer for Linux,
its DOS one having been left out with the sound library.

What I read today: the files by their sizes, and `I_IBM.C`'s lines
that name an interrupt, a port or the screen's address; nothing line
by line. The DPMI specification, the XMS and EMS ones, Abrash's
chapters on Mode X and ARM's manual on the caches with the MMU off I
know from before and **did not read again**: to do before the stage
that needs each.

**The licences**: MS-DOS is MIT, so it may be read and, with its
notice, quoted; FreeDOS and Heretic are GPL 2 and ix is LGPL 2.1:
**read, never copied**. In any case mini-dos is written anew
(8086 assembly has little to give to OCaml).

| MS-DOS | lines | what |
|---|---:|---|
| 1.25, `MSDOS.ASM` | 4,030 | the DOS: the FAT, the calls |
| 1.25, `IO.ASM` | 1,933 | the BIOS's side, for one machine |
| 1.25, `COMMAND.ASM` | 2,165 | the shell |
| **1.25, the three** | **8,150** | with `STDDOS.ASM`'s 22: a whole DOS |
| 2.0, all of `source/` | 51,686 | 100 files: with its utilities (DEBUG, EDLIN, FORMAT, CHKDSK, PRINT...) |
| 2.0, the kernel's and the shell's largest | 12,876 | directories, handles ("XENIX"), EXEC, the allocator (`ALLOC.ASM`, 370) |
| 4.0, `DOS` | 34,008 | |
| 4.0, `BIOS` | 21,382 | |
| 4.0, `CMD/COMMAND` | 19,832 | |
| 4.0, `MEMM` | 30,240 | the expanded memory manager for the 386: EMM386's parent |
| 4.0, all | 495,680 | |
| FreeDOS's kernel | 33,890 | C and assembly: `kernel/`, `hdr/`, `drivers/` |

So **a whole DOS was eight thousand lines of assembly** in 1982, and
its memory manager alone thirty thousand six years later.

| a game's layer over DOS (Heretic) | | |
|---|---:|---|
| `I_IBM.C` | 2,204 | the screen, the keyboard, the mouse, the timer, DPMI |
| `I_IBM_A.ASM` | 135 | |
| interrupts called from protected mode | 11 | of them the video's 4, the extender's (`int 31h`) 6 |
| vectors taken (`_dos_setvect`) | 4 | the keyboard's and the timer's, set and given back |
| pages locked (`_dpmi_lockregion`) | 4 | what an interrupt's handler touches |
| the mode | | `regs.w.ax = 0x13`, then `pcscreen = (byte *)0xa0000` |
| the VGA's ports named | 9 | `3C0`, `3C4`, `3C6` to `3C9`, `3CE`, `3D4`, `3DA` |

That is the whole of what DOOM's kin asked of the system: **a mode, an
address, two vectors, and a way to call down.** DOOM's release for
Linux is 54,923 lines of C, its layer for Linux 2,611.

What ix has (the same script):

| a DOS needs | ix | |
|---|---|---|
| an OCaml program on the bare Pi 1 and Pi 2 | `kernels/lib_machine`: 3,176 lines with the Pi 1's, the run-time system's C in it (`libc.c` 504, `runtime.c` 370) | there, **but** its start links a kernel at `0x80000000` and turns the MMU on at once (decision 2) |
| the FAT, read and written | mini-9pi's `Fat` (509): `read`, `write`, `create`, `remove`, `rename`, `truncate`; it names FAT12, 16 and 32 | there, by a link |
| the card | mini-9pi's `Emmc` (302) | there, by a link |
| the keyboard | `Usbhost` (186) over `usb.c` (397); mini-9pi's `Kbd` (213) for the keys' meaning | there, by links |
| the screen | `Screen` (107): 1024 by 768 at 16 bits, a cell of 8 by 16 | its mailbox call, by a link; the modes are new |
| a shell | tiny-shell is 625 lines, its language `rc`'s cut down | not DOS's: `COMMAND` is written |
| a kernel of processes over the same layer, for the size | mini-xv6: 1,301 lines of OCaml | |
| a game | `games/fps/TinyWolfenstein.ml` (338), over `lib_playground` | OCaml: decision 8 |
| 8 bits a pixel, a palette, a second page, in QEMU | its mailbox answers `SET_DEPTH`, `SET_PALETTE`, `SET_VIRTUAL_OFFSET` (its master today; the one here is 8.2.2) | there, I believe: not tried |
| the same in mini-qemu | its mailbox has neither the palette's tag nor the offset's, and shows 16, 24 and 32 bits | **to add** (decision 9) |

## The first megabyte

The PC's map is the thing to show, and decision 3 is to have it as it
was:

    0x00000000  the processor's eight vectors (the ARM's, as the 8086's were here)
    0x00000400  mini-dos's 256 vectors, four bytes each; the BIOS's data
    0x00001000  the transfer area a program is loaded at, to
    0x000A0000  640 KB: the end of conventional memory
    0x000A0000  mode 13h's 64,000 bytes (under the extender; see decision 9)
    0x00100000  the kernel's image, its heap: "DOS loaded high"
    ...         extended memory: what XMS lends and the extender takes
    0x20000000  the board's devices (the Pi 1's)

## Decisions to take (the author's; my proposals)

0. **The name: mini-dos**, in `kernels/dos/`, a `plan_system_`: a
   historical system given a place, counted apart in `make loc` as the
   other systems are. It is not a port of MS-DOS: no program of the
   PC's runs on it.
1. **The Pi 1 first, the Pi 2 by the same flag**
   ([`plan_pi2.md`](plan_pi2.md)): the two boards the author has that
   are arm32. Under mini-qemu and QEMU as the others. The Pi 4 (arm64)
   is not in this plan.
2. **Real mode is the MMU off.** It is what the firmware hands over:
   physical addresses only, nothing protected. Protected mode is then
   the MMU on, and the switch is **one bit of one control register**
   with a table's address set before it, which is what it was on the
   386 (`CR0`'s PE, and the tables). mini-dos, its BIOS and every
   program not extended run so, all in a privileged mode. Two
   consequences:
   - `kernels/lib_machine/pi1`'s start cannot be linked as it is (it
     turns the MMU on in its first lines and runs at `0x80000000`):
     mini-dos has **a start of its own**, and what of `machine.c`
     names a kernel address is to look at;
   - **without the MMU the ARM has no data cache**, so the whole
     system is slow, as the author saw on the Pi 2 before its caches
     ("really really slower"). For this system that is the lesson:
     the extender gives a program memory **and speed**. But it is
     also the plan's first risk (the OCaml kernel itself runs so):
     stage 0 measures it. If it is not bearable, the way back is an
     identity map with the caches on that is called real mode, which
     is what EMM386 made of the PC (decision 11).
3. **The first megabyte is the PC's** (the map above): the kernel
   linked at 1 MB, its first instructions copying the image up from
   `0x8000` where the firmware and the emulators put it. Conventional
   memory is then truly the 640 KB under `0xA0000`. The limit itself
   is a rule (see "The limits"). The cheaper way, the megabyte
   anywhere above the kernel, keeps `lib_machine`'s layout and loses
   the picture.
4. **The calls are the software interrupt, with DOS's numbers.**
   `SWI 0x21` is int 21h, the function's number in `R0` as it was in
   `AH`, the arguments in `R1` to `R3`, the answer in `R0`, **the
   carry set for an error** with its code in `R0`. `SWI 0x10`,
   `0x16`, `0x13` are the BIOS's. A `SWI n` goes through vector `n`
   of the table of 256, and the board's two interrupts through
   vectors 8 (the timer) and 9 (the keyboard), so that **a program
   takes one by writing four bytes**, or by functions 25h and 35h.
   The kernel's own handlers are OCaml behind an entry; a program's
   is machine code. Some thirty functions of int 21h: the console's
   (01h, 02h, 09h with its `$`, 0Ah), the handles' (3Ch to 42h), the
   directories' (39h to 3Bh, 47h, 4Eh, 4Fh, 41h, 56h), memory's (48h
   to 4Ah), the programs' (4Bh, 4Ch, 4Dh, 31h), the vectors', the
   date and the version.
5. **Files: the card's FAT partition is `C:`**, the one the board
   boots from, by `Fat` and `Emmc` linked. So `DIR` shows
   `CONFIG.TXT` and the kernels' images beside `COMMAND.COM` and
   `AUTOEXEC.BAT`. Names of 8 and 3 letters, case not kept, `\`
   between them, a current directory.
6. **A program is a flat image at one address** (a `.COM`): loaded at
   the transfer area's start after a prefix of 256 bytes (its
   command line, its memory's end: the PSP), entered at its first
   byte, by mini-ld's raw images. Written in **assembly and C**, by
   mini-asm and mini-cc, over a C library of some 150 lines whose
   every function is one `SWI`. One address for all is enough for one
   program at a time; a program that runs another (the shell) and a
   resident one need a second place: `COMMAND` is first **a module of
   the kernel**, as its resident part was the piece of the shell that
   never left memory, and a resident program copies its handler to a
   block at the top and must be written to run anywhere. A `.EXE`
   with a table of relocations is later, if ever.
7. **Memory: a chain of blocks**, each headed by its size and its
   owner, from the transfer area to 640 KB (DOS's memory control
   blocks); a program is given the largest and may shrink it. `MEM`
   prints the chain. **XMS** (`HIMEM`) is in the kernel: how much
   memory is past the megabyte, a handle for a piece of it, and a
   copy between a handle and conventional memory, which is the only
   way a real-mode program had to it.
8. **The extender is a program, `DOSX.COM`**, in C and assembly, and
   the clients are flat images linked for a virtual address (the
   game, in C, written for it: a raycaster in mode 13h was the
   machine's own kind of program). `DOSX GAME` does what DOS/4GW did:
   - takes all of XMS, builds the tables (the first megabyte and the
     devices as themselves, the client where it was linked, the
     screen at `0xA0000`), turns the MMU and the caches on, enters
     the client;
   - has taken vector 21h, as a resident program does. A client's
     call arrives there with pointers DOS cannot follow (the client's
     addresses are not the memory's): the extender **copies the
     arguments to a transfer buffer in conventional memory, turns the
     MMU off, calls DOS, turns it on, copies the answer back**;
   - answers `SWI 0x31`, DPMI's few that `I_IBM.C` uses: memory
     given and taken back, a real-mode interrupt called with a block
     of registers, a vector for a handler in protected mode, the
     version;
   - passes the timer's and the keyboard's interrupts to the handler
     the client set, or down to DOS.
   On the ARM the way down is dear for a reason of its own: memory
   written through the cache must be written out before the cache is
   left. **That cost is measured** (`numbers.sh`: one read of a file
   from the client against one from a real-mode program), as the
   cost of a mode switch was the thing every extender's maker fought.
   TinyWolfenstein, in OCaml, is a later stage: it needs mini-ml's
   run-time system over int 21h and a platform of `lib_playground`
   over mode 13h.
9. **The screen: three modes by `SWI 0x10`.** Mode 3 is the text's,
   80 by 25 in `Screen`'s cell of 8 by 16: 640 by 400. **Mode 13h**
   is 320 by 200 at 8 bits, one byte a pixel, with the palette's
   functions (the firmware's tag): on the author's 1280 by 800
   monitor, four times each way exactly. Its address is where the
   firmware put it, given back by the call as VESA's later modes gave
   theirs; under the extender it is at `0xA0000`. **"Mode X"** is
   here its two gains that the Pi can give: 320 by 240 with square
   pixels, and **two pages flipped** (a framebuffer twice as high and
   the firmware's offset), by a function of mini-dos's own since on
   the PC it was no BIOS mode but a way to program the card. In
   mini-qemu: 8 bits shown through a palette, and the two tags, some
   40 lines outside the directory.
10. **The keyboard: the USB driver the other kernels have**, in the
    BIOS, giving `SWI 0x16` its keys and raising vector 9; the serial
    line is a second keyboard and a second screen for the tests, as
    for the others.
11. **Expanded memory (EMS) is later, and changes decision 2.** A
    window of 64 KB under the megabyte whose four pages are changed
    by a call needs the MMU, on the PC too: EMM386 put DOS itself
    under the 386's paging, in virtual 8086 mode, and real mode was
    never real again. That is then the same step as decision 2's way
    back and as the extender's optimization (DOS run under the
    client's tables, no switch): one later stage, **apart and
    switchable**, with what it changes for an extender (it finds the
    processor already taken: what VCPI was for).
12. **Two builds**, as the other kernels: by ocaml-light and gcc, and
    by ix's own tools; the programs by ix's tools only.

## The limits (what a reader must not take for DOS)

- **No segments.** `segment:offset`, near and far pointers, the
  64 KB of a `.COM`, the A20 line: all the 8086's. Here an address is
  32 bits everywhere, and **the 640 KB limit is a rule the kernel
  keeps**, not one the processor makes. So is the rule that DOS's
  calls take only addresses of conventional memory; without it a
  real-mode program could reach all the memory by itself, with the
  MMU off, and XMS would teach nothing.
- **No planes.** Mode X's third gain, four pixels written by one
  byte and copies inside the card, came from the VGA's four planes
  and its ports. The Pi has a plain framebuffer; planes made in
  software would be slower than without, the opposite of the point.
- **The honest way to both** is another system: an 8086 with a PC's
  BIOS as an emulator, running MS-DOS 1.25 itself from its sources
  (they are MIT). A 386 with protected mode, for DOOM's own binary,
  is several times that. Neither is in this plan.

## The rule: one directory, and what cannot be in it

As the other systems: the kernel, its programs and its tests are in
`kernels/dos/`; what is shared is there as a symbolic link, one a
file. Outside by its nature: mini-qemu's framebuffer of 8 bits
(`raspberry/boards/Devices.ml`, `Framebuffer.ml`).

The layout I propose:

    kernels/dos/
      mkfile  survey.sh  numbers.sh  README.md
      Main.ml
      bios/      Vectors (the table of 256, a SWI's way through it),
                 Int10 (the modes, the text, the palette), Int13 (sectors),
                 Int16 (keys)
      dos/       Int21 (the functions by their numbers), Handles, Dir
                 (paths, drives, 8.3), Memory (the chain; XMS), Exec
      command/   Command (the prompt, the built-in commands), Batch
      machine/   links (Machine, machine.c, the run-time system's C...),
                 and its own l.s: the start that goes up, the vectors
      drivers/   links: Fat, Emmc, Usbhost, usb.c, Kbd
      programs/  libc/ (a function a SWI), HELLO.s, MEM.c, FIRE.c (mode 13h
                 and its palette), CLOCK.s (a resident program)
      extender/  DOSX.c, switch.s; its clients: BIG.c, MAZE.c
      tests/

## What is checked

- **Recorded sessions**, as the other kernels': the lines typed at
  `C:\>` on the serial line and what comes back, under mini-qemu and
  under QEMU: `DIR`, a file copied, typed, renamed and deleted (and
  the card's image read back by `mcopy`: the FAT written is one
  Linux reads), a batch file, `MEM` before and after a resident
  program.
- **The screens**: mode 13h's frame of `FIRE` and of `MAZE` at a
  given tick, dumped by the emulator and compared; the palette's
  change with no pixel written.
- **The lack of protection**, which is this system's claim: a
  program that writes vector 9 owns the keyboard; one that writes on
  the kernel stops the machine, and the test says that it does.
- **The extender**: `BIG` asks for 64 MB and sums it; a client's
  read of a file of several megabytes gives the file's bytes (every
  one came through the transfer buffer); a key pressed while the
  client runs reaches its handler.
- **The numbers** (`numbers.sh`): the same loop in real mode and
  extended (the caches' share: on the board, by its cycle counter;
  the emulators count instructions and do not say it); one int 21h
  from each side; the switches of a level's loading counted.
- **On the boards**, by the author: the Pi 1 and the Pi 2 from one
  card, as mini-9pi's.

## The stages (each checked before the next)

0. **The ground: an OCaml program with the MMU off**, linked at 1 MB,
   printing its banner on the serial line. Settles decision 2's two
   consequences: the start, and how slow the kernel is so.
1. **The BIOS**: the table of vectors and the `SWI`'s way through
   it; int 10h's text, int 16h, int 13h over `Emmc`. `HELLO.COM`, ten
   lines of assembly in the kernel's image, run and returned from.
2. **The DOS**: `Fat` on `C:`, the handles, the chain of memory, a
   program loaded from the card and ended (4Bh, 4Ch).
3. **`COMMAND`**: the prompt, `DIR`, `TYPE`, `COPY`, `DEL`, `REN`,
   `CD`, `MD`, `RD`, `CLS`, `VER`, `MEM`, `ECHO`, a batch file,
   `AUTOEXEC.BAT`. The USB keyboard and the text on the screen. **A
   DOS**: the first recorded session.
4. **Mode 13h**: the mode, the palette, `FIRE`; mini-qemu's 8 bits.
5. **The vectors taken**: the timer's and the keyboard's passed
   through the table; `CLOCK`, resident (31h), drawing the time in a
   corner while another program runs.
6. **XMS**: `HIMEM`'s functions, and a program that keeps a picture
   larger than its memory up there.
7. **The extender**: `DOSX` with `BIG`, then a client's files
   through the transfer buffer; `SWI 0x31`. The numbers.
8. **The game**: `MAZE` under `DOSX`, the screen at `0xA0000`, the
   two pages, its own keyboard handler. **The picture.**
9. **The boards**: the Pi 1, then the Pi 2.
10. Later, each to be decided: DOS under the tables (decision 11:
    EMS, the extender without the switch, VCPI's question); the
    text mode as cells of a character and an attribute at `0xB8000`,
    the kernel drawing them (sixteen colours: an editor's blue
    screen); the mouse (int 33h); a sound card's kin over mini-9pi's
    audio driver, and the speaker's beep; `EDLIN` and `DEBUG`;
    `CONFIG.SYS` and a driver loaded from it; OCaml programs
    (mini-ml's run-time system over int 21h), and with them
    TinyWolfenstein and `lib_playground`; `.EXE`.

## The size

A guess, to be held against what is written. The kernel's OCaml
**1,300 to 1,800 lines** with its interfaces: the BIOS 300 to 400,
the DOS 500 to 700 (MS-DOS 1.25's is 4,030 of assembly with its FAT
in; here the FAT is linked), `COMMAND` 400 to 500 (1.25's is 2,165),
the rest 100 to 200. Its own assembly and C **250 to 400** (the
start, the vectors, a program entered and left). The programs: the
C library 150, the small ones 200 to 300, **the extender 500 to
700**, the game 300 to 400. In mini-qemu **40**. By links, not
written: `Fat` 509, `Emmc` 302, `Usbhost` and `usb.c` 583, `Kbd`
213, and `lib_machine`'s C.

So **some 2,700 to 3,800 lines written**, of which a DOS one can
type at (stages 0 to 3) is about 1,800: under a quarter of MS-DOS
1.25's lines, with a file system it did not have to write.

## Not checked yet

- nothing was built or run; the references were looked at by their
  sizes and by `grep`;
- **the ARM without its MMU**: that the ARM1176 and the Pi 2's
  processor cache no data so (the instruction cache may be on), and
  what leaving the MMU costs (the caches written out, the TLB): from
  memory, to read in the manual before stage 0 and stage 7;
- **how slow the OCaml kernel is with the MMU off**: the author's
  word of the Pi 2 before its caches is the only measure; stage 0;
- what of `kernels/lib_machine` (its C, `Machine`, the collector's
  heap) supposes a kernel at `0x80000000` or the MMU on, and whether
  the image may copy itself to 1 MB under both builds;
- that the firmware of the boards gives 320 by 200 at 8 bits and
  scales it, takes a palette, and flips a second page by the
  virtual offset; that QEMU 8.2.2 does (its master has the three
  tags); **a way to wait for the screen's retrace on the Pi**, which
  I do not know: without one the two pages still tear;
- int 21h's and DPMI's function numbers above, the PSP's contents,
  `DIR`'s exact lines and DOS/4GW's banner: from memory;
- that DOOM itself drew through the VGA's planes and Heretic through
  plain mode 13h, as `I_IBM.C`'s lines suggest for the second: not
  read;
- `Fat` on the boot partition while the firmware's files are on it,
  and `Emmc` outside mini-9pi (what it asks of that kernel: not
  looked at);
- mini-cc and mini-ld for a flat program at an address under 1 MB
  and one for a client's virtual address; a C library of one `SWI` a
  function has not been tried with them;
- the sizes above are guesses, the extender's the least sure;
- the licences' reading above.
