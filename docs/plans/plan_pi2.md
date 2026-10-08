# Plan: mini-9pi on the Pi 2B: a third board (`kernels/lib_machine/pi2/`, `kernels/9pi/`, `raspberry/`)

The author (2026-10-08), of
[`plan_gpu.md`](plan_gpu.md), whose goal is a 3D
game drawn by the Pi1's 3D processor: "and I have a Pi 2B"; "so
definitely would love to have mini-9pi running on it"; and, the board
being a stage of that plan: "Pi2 should go in separate plan document,
that can be linked from this one." And, asked which Pi 2B: "Pi 2
V1.2 (2014)".

Why this board: **the Pi1's devices and its 3D processor, behind four
cores each faster than the Pi1's one.** What a game computes by itself
(its update, its view) is the processor's whatever draws, and that
plan's stage 3 may say it is too much for a Pi1.

The short answer: **a small port**, by what was read: the kernel
reaches every device at one address that its start maps, so the
board's other address is a line; what is really the Pi2's is the
processor's start and its caches. **Nothing here was built or run**;
the numbers are `games/survey3d.sh`'s ("ix: the boards") and the greps
said below (2026-10-08).

## The survey (2026-10-08, read; nothing run)

- **The board, by the author's word a V1.2: a BCM2837**, four
  Cortex-A53 (the Pi3's processor, ARMv8) run as 32-bit ones, 1 GB;
  the Pi1's peripherals, at 0x3F000000 where the Pi1 has them at
  0x20000000; the same VideoCore IV; the same USB hub and Ethernet as
  the Pi1 model B (a LAN9514: from memory). The first Pi 2B (V1.1) is
  a BCM2836, four Cortex-A7 (ARMv7): the same addresses, another
  processor. The seller's sheet for the V1.2
  ([Farnell's](https://www.farnell.com/datasheets/2163186.pdf)) says
  it needs the firmware of October 2016 or later to boot.
- **It is that board**: the author read on it "Raspberry Pi 2 Model B
  V1.2" (the year printed, 2014, is the drawing's: a V1.2 was sold
  from late 2016; a Pi1 Model B+ has "V1.2" and "2014" printed too,
  from memory, hence the question). Its revision, that the kernel
  prints (`board rev`), is to be **0xa22042**; a V1.1's is 0xa01041 or
  0xa21041 (from memory).
- **What a Cortex-A53 changes against a Cortex-A7, for a 32-bit
  kernel** (from memory, to read at stage 1): little. It takes ARMv7's
  system registers and caches' operations; the bit that says its
  caches are several cores' is in another register (`CPUECTLR`'s
  SMPEN, where the A7's is `ACTLR`'s), and the firmware's own start
  may set it. xv6's arm-pi3 is this processor run as a 32-bit one,
  under QEMU's `raspi3b` (plan_pi.md's table).
- **mini-9pi's boards**: `kernels/lib_machine/pi1` (1,393 lines:
  `start.s` 426 and `l.s` 411, the same start for gcc's assembler and
  for ix's; `machine.c` 302; `Arch.ml` 65; `board.h` 44; `kernel.ld`
  30) and `pi4` (1,103). What is shared is beside them (`runtime.c`,
  `usb.c`, `libc.c`, `Machine.ml`).
- **The devices' address is the start's**: the kernel's C and OCaml
  name 0xFE000000 (`board.h`'s `IO_BASE`; `machine.c`'s `REG`, `TIMER`,
  `INTC`), where `start.s` and `l.s` map "the devices at 0xFE000000:
  16 MB from 0x20000000". One constant in each of the two; and
  `machine.c`'s `MAILBOX 0x2000B880` with `REG`'s difference, which
  say the physical address.
- **What is the ARM1176's in `l.s` and `start.s`**: the caches'
  operations on a whole cache (`DCLEAN`, `DFLUSHALL`, `IINVALL`,
  `CACHEINV`, `DRAIN`, `PREFETCH`, `BTACINV`: some thirty lines of
  `MCR`), which ARMv7 has not in that form (a cache is walked, a line
  at a time); the cycle counter (`C(15), C(12)`); `SCTLR`'s bits. The
  rest (the modes, the vectors, the tables of pages in ARMv6's format,
  the VFP's access, `WFI`) an ARMv7 takes as it is (to check: the
  tables' bits for the caches).
- **principia's 9pi has the port** (`kernel/COMPILE/9/bcm`): 836 lines
  in six files, `raspi2.c` (212), `startv7.s` (259), `cache_raspi2.s`
  (280), `tas_raspi2.s` (41), `time_raspi2.s` (12),
  `concurrency_raspi2.c` (32). Its start sets the SMP bit before the
  caches are on (`CpACsmp`: a Cortex-A7's caches want it, even with
  one core); it leaves the hypervisor's mode if the firmware started
  it there (from memory of 9front's and Linux's; **not read in
  principia's file here**).
- **The interrupts and the timer**: mini-9pi's are the Pi1's system
  timer and interrupt controller (`TIMER`, `INTC`, by their offsets).
  The BCM2836 keeps both and adds a controller for its cores at
  0x40000000, which by default gives the peripherals' interrupt to the
  first core (from memory; QEMU's `raspi2b` is what says first).
  [`plan_pi.md`](plan_pi.md)'s table: xv6's arm-pi2 runs on `raspi2b`
  with one core, the system timer and the PL011, as mini-9pi would;
  principia's 9pi2 uses the cores' own timer.
- **The emulators**: QEMU has `raspi2b`. **mini-pi has no Pi2**: no
  file of `raspberry/` names one (plan_pi.md's table has it; its
  "Refocus" left the Pi1 and the Pi4).
- **What a Pi2 would be in mini-pi** (the author: "for mini-pi, it all
  depends how many lines we need to add to support it"). Its Pi1 is
  `raspberry/Board.ml` (296 lines) over `machine/`'s `Arm32` and
  `Mmu32`, and what says "Pi1" in it is three constants: `let io =
  0x20000000`, `midr` (the ARM1176's, with its feature registers'
  two rows) and the mailbox's `~board_rev:0x900021`; the RAM's size is
  already the command line's. Its `mcr` keeps `ACTLR` (where the SMP
  bit goes) and **takes every cache operation it does not know as
  nothing** (`| _ -> ()`), ARMv7's by a line included; a register it
  does not know reads 0. So, for the kernel of this plan (one core,
  the Pi1's timer and interrupt controller): **the three constants
  made a board's, and `-M raspi2b` in `Main.ml`: 30 to 60 lines, a
  guess from reading**. In its favour: `Arm32` has ARMv7's `dsb`,
  `dmb` and `isb`, and the model already answers zero at 0x40000000
  (its "gpu" region), where the Pi2's cores' controller is. Right
  only if the new start uses no other instruction `Arm32` has not.
  What would make it hundreds: the four cores started, their
  controller and their own timer, the hypervisor's mode (the Pi4's
  model is 453 lines and its GIC 167): none of it this plan's.
- **The card: one for the Pi1 and the Pi2, and later the Pi4** (the
  author: "ideally we could make a single SD card that could boot on
  pi1 or pi2; (and later pi4). Is it possible?"). **Yes**, by what the
  firmware does (the Foundation's
  [config.txt pages](https://www.raspberrypi.com/documentation/computers/config_txt.html),
  read 2026-10-08), and it is how its own system's one image boots
  every board:
  - **The same three files start a Pi1 and a Pi2** (`bootcode.bin`,
    `start*.elf`, `fixup*.dat`); the Pi4 reads none of them (its
    loader is in the board) and wants its own beside them
    (`start4.elf`, `fixup4.dat`, its `.dtb`: `kernels/firmware`'s
    README). The names do not collide: one FAT.
  - **A kernel for each board, by its name**: with no `kernel=` line
    the firmware loads `kernel.img` on a Pi1, `kernel7.img` on a Pi2
    (and Pi3), `kernel8.img` on a Pi4 (`kernel7l.img` with
    `arm_64bit=0`).
  - **`config.txt` has sections by board**: `[pi1]`, `[pi2]` ("2B
    (BCM2836- or BCM2837-based)"), `[pi4]`, `[all]`: the Pi1's
    overclock under `[pi1]`, and a `kernel=` under each if ix's names
    are kept (`mini9pi1.img`).
  - **What has to change: the firmware's files.** ix's are **of March
    27, 2015** (`kernels/firmware/pi1`, from Miller's 9pi image): they
    know `kernel7.img` (`strings start_cd.elf`) but are older than
    the author's board, a V1.2, which wants October 2016's or later;
    and `conf/config.txt` says of them "this firmware (2015) may not
    know the sections, and would take them all". So: **one newer set
    for the Pi1 and the Pi2** (`kernels/firmware/pi1` renamed for
    what it is), from github.com/raspberrypi/firmware's `boot/`, its
    version and sums in the README; and **the Pi1 booted again with
    it before anything else** (a firmware eleven years younger under a
    kernel that asks it for the framebuffer, the clocks, the USB's
    power: what changes is the board's to say).
  - **The cut-down firmware has no 3D**: "The cut-down firmware
    removes support for codecs, 3D and debug logging"; `gpu_mem=16`
    is what chooses it. Nothing for this plan, and
    [`plan_gpu.md`](plan_gpu.md)'s stage 4 needs the other one
    (`start.elf`, `fixup.dat`, more of `gpu_mem`).
- **The programs are the Pi1's**: mini-ml's and the C compiler's arm
  code is ARMv6's at most, which a Cortex-A7 or A53 runs. Nothing of the
  user's side is built again.

## Decisions (proposed, for the author)

1. **`kernels/lib_machine/pi2/`, the Pi1's six files with what
   differs**, as `pi4` is beside `pi1`; `make BOARD=pi2`,
   `kernel-pi2.img`. If what differs comes to the devices' address and
   the caches' few functions, **one directory for both boards and a
   flag** is the other way (fewer lines, a file that is two
   processors'): to say once stage 1 shows how much it is.
2. **One core.** The Pi1's kernel has one; the three others are left
   where the firmware parks them. Several cores is a kernel's change
   (locks, a scheduler for each), not a board's: not in this plan.
3. **The Pi1's timer and interrupt controller**, as xv6's arm-pi2: no
   new driver, if QEMU and the board agree.
4. **QEMU first**, `raspi2b` (a Cortex-A7: the addresses and the
   ARMv7 start are the board's, the processor is not quite; `raspi3b`
   with a 32-bit kernel, as xv6's arm-pi3, if a difference is to be
   looked at), the Pi1's sessions with the board's
   lines changed (`BOARD_SED`, as the Pi4's). **mini-pi's Pi2 after, by its count** (the author):
   stage 1's kernel is run on mini-pi's Pi1 model with the three
   constants changed, and what it stops on is the count. Some tens of
   lines: done, in stage 1, and the tests run on both emulators as
   the Pi1's. More: said to the author first.
5. **Both of gcc's and ix's start** (`start.s`, `l.s`), as the Pi1's:
   the kernel built by ix alone is what goes on the card.

## The stages (each checked before the next)

1. **It boots under QEMU.** The address; the start (the mode it is
   entered in, the SMP bit); the caches off (`let caches = false`, the
   switch the Pi1's bring-up left in `kernels/9pi/init/Main.ml`).
   Check: `make check BOARD=pi2`, the Pi1's sessions (the boot, rio,
   the games' frames), the same answers.
2. **The caches**, ARMv7's operations, a line at a time. Check: the
   same sessions (an emulator does not say that a cache is told
   rightly: `docs/plans/bugs/ix.md`'s row of the Pi1's); read against
   principia's `cache_raspi2.s`.
3. **The card, one for both boards, and the Pi2.** First the newer
   firmware with the Pi1's kernel alone: `make card`, **the author's
   Pi1 boots as before** (rio, a game; `make check-card`'s record made
   again). Then `config.txt` by sections, the two kernels on the card
   (`MKCARD`'s list), and the author's Pi 2B: the boot, its `board
   rev` (0xa22042), a keyboard, rio, Tetris; then the speed plan's two
   games with `stats=on`, their frames beside the Pi1's in
   [`plan_playground_speed.md`](plan_playground_speed.md)'s Status.
   The same card back in the Pi1. (The Pi4's files join it when the
   Pi4's card is made: `kernels/firmware`'s README, "to come".)
4. **mini-xv6 on it**, the same directory serving both kernels as the
   Pi1's does: if it is nothing more, done with stage 1.

Not in this plan: several cores; the 3D processor (plan_gpu.md:
its driver is one file for the Pi1 and the Pi2, the registers' address
the board's); mini-pi's Pi2.

## Open questions

- One directory or two (decision 1)?

## Status

2026-10-08: plan written, from reading. Nothing built. The author's
board: "Raspberry Pi 2 Model B V1.2", the BCM2837.
