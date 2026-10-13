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
  [`plan_pi.md`](done/plan_pi.md)'s table: xv6's arm-pi2 runs on `raspi2b`
  with one core, the system timer and the PL011, as mini-9pi would;
  principia's 9pi2 uses the cores' own timer.
- **The emulators**: QEMU has `raspi2b`. **mini-pi has no Pi2**: no
  file of `raspberry/` names one (plan_pi.md's table has it; its
  "Refocus" left the Pi1 and the Pi4).
- **What a Pi2 would be in mini-pi** (the author: "for mini-pi, it all
  depends how many lines we need to add to support it"). Its Pi1 is
  `raspberry/boards/Board.ml` (296 lines) over `machine/`'s `Arm32` and
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

Not in this plan: several cores
([`plan_multicore.md`](plan_multicore.md)); the 3D processor (plan_gpu.md:
its driver is one file for the Pi1 and the Pi2, the registers' address
the board's); mini-pi's Pi2.

## Open questions

- One directory or two (decision 1)? One, with a flag, by stage 1's
  count (the Status). Confirmed (the author, 2026-10-12: "I like your
  decision").

## Status

2026-10-08: plan written, from reading. Nothing built. The author's
board: "Raspberry Pi 2 Model B V1.2", the BCM2837.

2026-10-12: begun, by stage 3's first half (the author: "I think one
of the first step was updating the firmware files in the repo and
check if the Pi1 was still working with those new firmware").
`kernels/firmware/pi1-pi2/`: `bootcode.bin`, `start_cd.elf` and
`fixup_cd.dat` of github.com/raspberrypi/firmware's tag `1.20260915`
(built Sep 14 2026; it names `kernel7.img`), with that tag's licence;
`make card` takes them (`FIRMWARE`), `conf/config.txt` unchanged, so
that the firmware is the one thing that differs. Checked: `make card`,
the three files read back from the card's FAT by mcopy, the same
bytes. **Not checked: the author's Pi 1 with this card** (rio, a game,
the sound, `cpu: 800 MHz`, the keyboard and the mouse). Until it is,
the 2015 set stays in `kernels/firmware/pi1/` (`make card
FIRMWARE=../firmware/pi1`), and the recorded card sessions
(`tests/session-card`, `session-card-ix`: the three files' sizes in
their listings) are the old set's: `make check-card` fails on those
lines, not run. Read for stage 1, nothing written: principia's
`startv7.s` (the SMP bit before the caches, ARMv7's cycle counter; it
does not leave the hypervisor's mode), and what QEMU's `raspi2b`
wants (`-kernel`, which parks the three other cores as the firmware
does, where the Pi 1's `-device loader` would start all four).

2026-10-12, the same day: what a boot says of what it runs (the
author: "would it be possible during the boot to display the fimrware
version? Is it something mini-9pi can detect? Also maybe would be good
to put the current version of mini-9pi so we have visual feedback when
we boot whether it's actually a new version"). The firmware says its
revision (the mailbox's tag 1: the second its files were built at):
`Machine.firmware_rev`, and the banner's "board rev: ... firmware
rev: ..." are now both asked (they were the emulators' two numbers,
written in `Main.ml`, on a board too). On a board, `conf/boot.rc` says
last, after "cpu: 800 MHz": `firmware: 2026-09-14` (the kernel's
`#ec/firmware`, set when a speed was measured) and the card's
`version.txt`, which `make card` writes: `mini-9pi 0.2 (b882a5af+),
card of 2026-10-12 10:45` (changes.txt's version, the commit, a + for
a tree that differs, the minute the card's image was made). Neither
under an emulator: the recorded screens and consoles are as they were
but for the FAT's listings, one file more. Checked: the date's
arithmetic on the host against date(1), six dates; under QEMU with the
card, the banner as before and no new line; with the two conditions
forced for one build, "firmware: 1970-01-05" (QEMU's 346337) and the
card's line; mini-xv6 builds. Not checked: a board; the Pi 4's kernel
(no ocaml-light for arm64 on this machine) and the kernels by ix's own
tools, not built.

2026-10-12, later: **the Pi 1 boots with the new firmware** (the
author: "it works!", the keyboard; after "still fail" three times).
What it took, a card a try, the author typing the kernel's numbers
from the screen:
- The first card did not boot at all ("a gradient color big image"):
  the card reader had left the USB bus in the middle of the write
  (the host's log), on a port whose USB 2 side is bad. Not the
  firmware. A write is now read back (`cmp`) before the card moves.
- With a whole card the kernel reached its prompt and had no USB:
  "usb: ep1.0 port 1: i/o error". `usb.c` and `Usbdwc.ml` say the
  controller's registers when a transfer fails (three lines of
  hexadecimal, `usbotg:`; nothing when all is well, so nothing under
  an emulator). By them, one after the other: the host mode comes
  after 66 ms, 25 were waited; HCFG's clock field 1 for 0; the frame
  48000 clocks for 7500; and GAHBCFG 0x1e, DMA off, seconds after the
  kernel had set it. Each put right in turn (`docs/plans/bugs/ix.md`
  has the row); the card that booted had the last two together (the
  firmware's answer waited for by the clock; the setup done again
  before the port's reset when DMA is off), so which of them it was
  is not known.
- The same will be the Pi 2's: its kernel has this `usb.c`.
Checked on the board by the author: the boot, the keyboard and the
mouse ("independently the mouse and keyboards are working!"). Seen
there and not explained: `ls` typed at the prompt answered "ls:
'/boot/' file is a directory" (under QEMU with the same card it lists
/usr/pad). Then, the author: "cameltry was working, missilecommand
was working, with the sound": two games and the PWM's sound with this
firmware. Checked
here: each card's image under QEMU and mini-qemu with a USB keyboard
and mouse, the prompt and no `usbotg:` line; mini-xv6 builds. Not
checked: rio on the board with this firmware; the Pi 4's kernel and the kernels by ix's own tools, not
built; `make check-card` and the other recorded sessions, not run
(the card's listings are still the old files').

2026-10-12, stage 1: **mini-9pi boots under QEMU's `raspi2b`** to its
prompt, with the card, a USB keyboard and a mouse: `make ix BOARD=pi2`,
`kernel-pi2-ix.img`; "board rev: 0xa21041", "cpu0: 0MHz ARM
Cortex-A7", "1024M memory: 64M video, 96M kernel data, 864M user".
Not committed. **Decision 1, by the count: one directory and a flag**
(`BOARD=pi2` is `lib_machine/pi1/` with `PI2` said to its C and its
assembly): some 90 lines in `start.s`, `board.h`, `machine.c` and
`kernel.mk`, comments included, where a `pi2/` would copy 1,400.
What the Pi 2 is, in them:
- the devices at 0x3F000000 (`IO_PHYS`, `IO_MB`), the RAM's address
  for a device 0xC0000000;
- 1 GB: the RAM at KERNBASE reaches 0xBF000000, over the Pi 1's
  second view of it (not cached, at 0xA0000000), so that view is at
  0x40000000, the GB between the user's addresses and the kernel's,
  which nothing used. (Found by a fault: QEMU's framebuffer is at
  0x3C100000.)
- the start: the other cores stopped (MPIDR), the hypervisor's mode
  left if the kernel is started in it; ARMv7's cycle counter; the
  caches left off (stage 2).
- and, the board's nothing: `Main.ml`'s line of the memory doubled a
  number past an int of 31 bits (1 GB) and never ended: in megabytes
  now. `Devarch`: the processor's name from the board's revision
  (BCM2835, 2836, 2837); no speed said under an emulator, known by
  its firmware's revision (QEMU's Pi 2 has a cycle counter and said
  1005 MHz, which made it a board for `boot.rc`).
QEMU: `-device loader` at 0x8000 as the Pi 1's, not `-kernel`, which
puts an image without a header at 0x10000; so QEMU starts the kernel
in SVC, and **the way out of the hypervisor's mode has not run
anywhere**: the board's to say. Checked: `make check-ix` for the Pi 1
under both emulators and for the Pi 2 under QEMU (`BOARD_SED`'s two
lines), each the recorded console but one line, "status hello 28: 3"
for 24, the same on both boards: four processes more at the boot than
when it was recorded, not from this work (with one `ls` more in
`boot.rc` it was 29; that `ls` is now inside the test of the speed).
Not done, of stage 1: the start for ix's own tools (`l.s`, the
mkfiles: decision 5); the other sessions of `make check BOARD=pi2`
(rio, the screens, the network), not run; mini-pi's Pi 2; mini-xv6
for the Pi 2 (stage 4), not built.

2026-10-12: `./mini-pi -q mini-9pi2`, and `-g -q` (the author:
"maybe we can have a mini-pi -g -q mini-9pi2 ?"): the launcher builds
the Pi 1's card and the Pi 2's kernel (by ocaml-light and gcc: ix's
own tools have no start for it yet) and runs QEMU's `raspi2b`;
without `-q` it says mini-qemu has no Pi 2 yet. Checked: `./mini-pi
-q mini-9pi2`, two commands at its prompt; `make BOARD=pi2 ix-usb`
(what `-g` builds), a command typed on QEMU's USB keyboard. Not
checked: the window itself (`-g`), not looked at.

2026-10-12: **mini-9pi boots on the author's Pi 2 Model B V1.2**
("it is booting! usb is working! keyboard, nouse, display"), the
first try, from one card for both boards: stage 3's second half
before stage 2, the caches still off. `conf/config.txt` by sections
(`[pi2]` `kernel=mini9pi2.img`; `[pi1]` `kernel=mini9pi1.img` and its
overclock; `[all]`), `make card` building the Pi 2's image too and
putting both kernels on the FAT (`mini9pi1.img`, `mini9pi2.img`),
the firmware `kernels/firmware/pi1-pi2`. So the start runs on the
board, whatever mode the firmware entered it in (not known which:
nothing prints it), and the day's USB changes hold on the Pi 2's
controller and hub. Checked here: both kernels read back from the
card by mcopy, the same bytes; each booted with the card under QEMU.
Not known yet from the board: its banner's lines (the board's
revision, to be 0xa22042; the processor's name and speed), the
sound, a game, rio, how long the boot is without the caches; the
same card back in the Pi 1. Not committed.

2026-10-12, stage 2: the Pi 2's caches, written; **not yet on the
board**. The author, of the first boot: "it said 900 MHz I think, but
things are really really slower than on the Pi1 actually" (the caches
off, as said). `pi1/start.s` under `PI2`: `dcache_all`, every data or
unified cache walked by level, set and way (CLIDR, CSSELR, CCSIDR:
the ARM manual's loop, Linux's `v7_flush_dcache_all`), invalidating or
writing first; `caches_enable`, ACTLR's SMP bit (a Cortex-A7's; the
A53's is elsewhere, its firmware's to set, and the write does nothing
there: from memory), the caches and the predictor emptied, SCTLR's C,
I and Z; `cache_flush_all` by the same walk; SCTLR's TRE and AFE
cleared at the start, the tables being ARMv6's. The Pi 1's
operations by address (`cache_clean_range`, `cache_sync_range`) are
ARMv7's too and are the Pi 2's as they are; their step is 32 bytes
where the line is 64, each line told twice. Not read against
principia's `cache_raspi2.s` (the plan's check). Checked: both
kernels boot with the card under QEMU, a program run, no fault in
the kernel: which says only that no instruction is undefined there,
an emulator having no cache.

2026-10-12: the board's revision, read by the author off its banner:
**0xa02042** (not the 0xa22042 guessed above, which is the same board
made by Embest): 1 GB, made by Sony UK, the BCM2837, a 2B, revision
1.2. So the processor is the Cortex-A53, run as a 32-bit one, and
`Devarch` names it so (the revision's processor field, 2).

2026-10-12, on the Pi 2 with the caches (the card of 13:54): "far
faster to boot"; "cameltry is faster! 30fps instead of around 20fps I
experienced with the Pi1"; the banner's "Cortex A53 at 900MHz". Stage
2 holds on the board for a boot and a game. Then two faults, each
with a fix on the next card (14:03), **neither seen on the board
yet**:
- "The first command still fail with :/boot/' file is a directory",
  "and the second one works", "like what I experienced with the Pi1":
  a byte 0 in the console's line before the first key, taken to be
  the serial line's, nothing being plugged on it
  (`console/Devcons.ml`: no NUL from the serial line nor from a key
  without a character). A guess that fits every word of the symptom;
  the 0 itself was not seen.
- "sound is working but the quality is bad compared to the pi1", "some
  noise sound is repeating", "even stopping the game leads to this
  repeated sound": `Devaudio` gave the DMA the Pi 1's address for the
  RAM (0x4000...) on every board; now the board's
  (`Machine.bus_alias16`, new: 0xc000 on the Pi 2).
`docs/notes_debugging_techniques.md`, section 18 (the author: "can be
interesting techniques to add to debugging techniques document, maybe
things special for audio device"). Checked here: `make check-audio`
on the Pi 1 under mini-qemu, the tone whole; `make check-ix`, as
before (its one line of the processes' numbers); both kernels boot
with the card under QEMU.

2026-10-12, the card of 14:03 on the board: "ls now works as the
first command". The NUL's fix holds (which of its two sources it was,
the serial line or a key, is still not known). The sound with the
board's alias: not said yet.
Then: "sound is working well now". The board's alias was it.

2026-10-12: rio on the Pi 2 with the caches (the author: "I've tried
rio, it works! Everything seems to work, only slightly faster which is
great"): what the Pi 1's caches first failed at holds here. "Only
slightly faster" than a Pi 1 at 800 MHz, where a Cortex-A53 at 900
does more work a cycle: not measured, and not looked into. What could
be left on the table, each a guess: the page tables' walks, which are
not cached (TTBR's bits for it are 0); the screen's memory, written
where it is not cached, which a game's frame is mostly; the three
other cores.

2026-10-12: **the same card boots the Pi 1** ("the Pi1 works! with
the same SD card!"): `config.txt`'s sections choose each board's
kernel on the firmware of September 2026. Stage 3 is done: one card,
the author's Pi 1 and Pi 2B. And decision 1 is the author's ("I like
your decision").

2026-10-12, the speed, measured by the author with the same card on
both boards: cameltry from the console, "about 16fps in the Pi1 and
around 45 in the Pi2" ("so definitely better"): 2.8 times. Under rio
it was 20 and 30: there the window system's part, the same work on
both, is what is left. So "only slightly faster", above, was rio's
share and not the processor's; the three guesses there are not
needed to explain it. Both kernels on that card are by ocaml-light
and gcc (`make card`'s default on this machine, the Pi 1's too, as
before today); the programs are by ix's tools and are the same files
on both boards.

2026-10-12, stage 1's rest: **the Pi 2's kernel by ix's own tools**
(decision 5), under QEMU; not on the board, not committed.
`pi1/l.s` is now what both boards share, included by `pi1/l1.s` (the
Pi 1: its constants, its cycle counter, its caches on and emptied,
moved there as they were) or `pi1/l2.s` (the Pi 2: `board_start`,
ARMv7's counter, `dcache_all` and the caches, as `start.s`'s): the
assembler has `#include` and `#define` and no `#ifdef`. `mkboard`'s
`PI2`, `mkkernel`'s `LS` and `-DPI2`; `kernel.mk` passes `PI2=1` for
`make BOARD=pi2 COMPILER=ix`. Found by it, QEMU's only: the three
other cores, left at 0, ran up through the low memory where this
kernel has its tables and its vectors' page, jumped to the vectors'
addresses with the MMU off, and faulted for ever, the boot crawling:
they are now started at the image's entry, where the kernel stops
them (`BOOT`, in `kernel.mk`, `mkkernel` and `mini-pi`). Checked: both
boards' kernels built by ix's tools boot under QEMU with the card
and run a program (the Pi 1's is the same code moved, its image not
compared byte for byte with the one before); `make check-ix
BOARD=pi2` under QEMU and `./mini-pi -q mini-9pi2` with the new
`BOOT`, as before. Not checked: either of them on a board; the
caches' walk in `l2.s`, which only a board runs for real; the
kernels of `kernels/steps`, `oberon`, `singularity` (their own
files, not touched); mini-xv6 by ix's tools.

2026-10-12, stage 1's rest: **a Pi 2 in mini-qemu** (`-M raspi2b`),
not committed. `raspberry/boards/Board.ml`: the Pi 1's board with a `pi2` in
its configuration, not a second board: the I/O space at 0x3F000000,
1 GB of RAM less the 16 MB under it, the VideoCore's 64 MB at the top
(the framebuffer at 0x3C100000, as QEMU's), the board's revision
0xa21041, and a Cortex-A7's MIDR, CTR, MPIDR, CLIDR, CCSIDR and CSSELR
(the kernel's walk of the caches reads them; the walk's own
operations do nothing, as the Pi 1's). One core: a `-device loader`
for another core is taken and ignored. `Dma.ml`: the peripherals'
bus addresses (0x7E...) are the board's I/O space, not the Pi 1's
for every board. `mini-pi`: `./mini-pi mini-9pi2` no longer needs
`-q`. The kernel needed nothing: it booted there at the first try.
Checked, `BOARD=pi2`, the kernel by ocaml-light and gcc: `make
check-ix`, the console the same byte for byte under mini-qemu and
QEMU (and the recorded one but the two lines known: the processes'
number, and `/env/cpu` in the second session's listing, there since
the banner's work); `make check-draw` under both; `make check-audio`
under mini-qemu, the tone whole; `./mini-pi mini-9pi2` with the card,
`pwd`, `ls`, `hello`; the screen at the prompt of `make check-menu`,
the same under both emulators, the USB hub, keyboard and mouse found.
The Pi 1 after it: `check-draw`, `check-audio`, `check-ix`, as before.
The kernel by ix's own tools boots there too, with the card, to its
prompt and `hello` after 80 s, as the Pi 1's by ix's tools does (the
same loop, not looked into). Not checked: `make check-menu` and the
other screens' checks for the Pi 2, which stop at the first screen:
the recorded ones have the Pi 1's banner (the board's revision, the
processor, the memory), so the Pi 2 needs its own or a banner that
the checks do not see; the window (`-g`); the page (MiniQemuWeb has
`pi2 = false`). Known limit: the emulator takes any of the
VideoCore's aliases for the RAM, so this morning's sound (the Pi 1's
alias given to the Pi 2's DMA) plays well there; only the board said
it.
