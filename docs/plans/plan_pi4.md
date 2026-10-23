# Plan: mini-9pi on the Pi 4B: from QEMU's raspi4b to the board (`kernels/lib_machine/pi4/`, `kernels/9pi/`, `raspberry/`)

The author (2026-10-23): "let's start to port mini-9pi to the Pi4!
there is a special built qemu that support the Pi4" (QEMU 11.1 built
with `-M raspi4b` and slirp: `/home/pad/work/TOOLCHAINS/qemu/build`,
mini-pi's `QEMU64`).

Why this board: the author owns one (with a Pi 1 and a Pi 2B); four
Cortex-A72 at 1.5 GHz, 1 to 8 GB, where the Pi 2's A53 at 900 MHz has
1 GB: the build of m-ix on the card (176 minutes on the Pi 2 under
QEMU, plan_self_hosting.md), the games, mini-netscape, all want it.
And plan_wifi.md's target is its CYW43455.

The short answer: **mini-9pi has run under QEMU's raspi4b since
2026-09-27** (done/plan_9pi.md, "mini-9pi4"), the programs principia's
and ix's arm ones run in AArch32 at EL0 under the arm64 kernel; it had
stopped booting there since 2026-10-11 and boots again (the Status).
What is left is **the board**, and the board differs from QEMU's
model where the Pi 1 and Pi 2 did not: **its USB keyboard and mouse are
behind PCIe** (a VL805, xHCI), its SD card on another controller, its
firmware answers asked of nothing so far. The keyboard is most of the
work.

## The survey (2026-10-23; what is "from memory" is to be checked)

- **What exists**: `kernels/lib_machine/pi4/` (1,174 lines: `l.s` 431
  for ix's tools, `start.s` 366 for gcc's, `machine.c` 222, `Arch.ml`
  82, `board.h` 50, `kernel.ld` 23), the same `kernels/9pi` as the Pi 1
  (`ARCH=arm64`: `syscalls/arm64/Ureg`, the AArch32 processes' ABI
  `syscalls/arm/Syscall`), mini-qemu's Pi 4 (`raspberry/boards/Pi4.ml`,
  455 lines, the Pi 1's `Arm32` for EL0's AArch32). `./mini-pi
  mini-9pi4` (`-q`: QEMU) and `make BOARD=pi4` in kernels/9pi.
- **Which build**: on this machine (x86-64) only ix's tools build it
  (`COMPILER=ix`, `kernel-pi4-ix.elf`): ocaml-light's arm64 wants the
  host's gcc to be an arm64 Linux's, and `COMPILER=ocaml` (OCaml 4.14)
  too (`kernel.mk`). So `start.s` is kept in step with `l.s` and not
  run here.
- **What is QEMU's and not the board's, in `pi4/machine.c`**: the
  firmware asked nothing; `board_rev` (0xb03115, QEMU's 2 GB 4B),
  `firmware_rev` (QEMU's 346337), `clock_rate` (the SD's 50 MHz),
  `display_size`, `board_mac`, `usb_power` all answer QEMU's numbers.
  `Arch.pages`: the processes have 128 MB (`384M memory: 256M kernel
  data, 128M user`), xv6 arm64-pi4's layout, where a Pi 1 now gives
  them 352 MB of 512.
- **The framebuffer**: `lib_machine/machine.c` asks it on the
  mailbox's channel 1, the old framebuffer channel, as xv6 arm-pi1.
  **The Pi 4's firmware has no channel 1** (from memory: Circle and
  Linux's simplefb use the property channel, 8, on every board; the Pi
  4's documentation lists only 8): the board's screen wants the
  property tags (allocate, physical and virtual size, depth, pitch).
  QEMU answers both.
- **The SD card**: mini-9pi's `Emmc` is at the peripherals' 0x300000,
  the Pi 1's EMMC. On a Pi 4 the card is on **EMMC2, at 0x340000** (an
  SDHCI too), the old one wired to the WiFi chip (from memory).
  QEMU's raspi4b has both (`info mtree`: `sdhci` at 0xFE300000 and
  0xFE340000); `-drive if=sd` puts the card on one of them, by the
  GPIO's routing: which, and whether a card can be put on EMMC2
  (`-device sd-card,bus=...`), is to be tried.
- **The USB**: mini-9pi's is the DWC2 at 0x980000 (`usb.c`,
  `Usbdwc`). On a Pi 4 the DWC2 is the USB-C port's alone (power, and
  a device by default); **the four USB-A ports are a VL805, an xHCI
  controller, on the BCM2711's PCIe** (from memory). So the keyboard
  wants: the PCIe root complex started (the BCM2711's own, at
  0xFD500000: Linux's `pcie-brcmstb.c`, a few hundred lines in
  Circle's), the VL805's reset told to the firmware (a property tag,
  0x00030058, on boards whose VL805 has its firmware in an EEPROM:
  from memory, every Pi 4 since 2020), and an xHCI driver: rings,
  slots and endpoints' contexts, a hub's ports, interrupt transfers
  for the HID devices. 9front's `usbxhci.c` is about 1,800 lines of C;
  mini-9pi's DWC2 is 709 (`usb.c` 397, `Usbdwc` 312), its HID and
  hubs above it shared (`buses/lib_usb`). **Neither QEMU's raspi4b
  nor mini-qemu's has PCIe** (raspi4b.c takes `bcm2711-pcie`,
  `rng200`, `thermal` and `genet-v5` out of the device tree "until
  they are implemented"): an xHCI driver is tested on the board only,
  or on a model of it written in mini-qemu.
- **The RNG**: the board's RNG200 at 0xFE104000, which `Rng` reads;
  QEMU's raspi4b has none (the Status), mini-qemu's has.
- **The serial line**: the PL011 at 0xFE201000, as QEMU's. On the
  board the PL011 is the Bluetooth's by default and the mini UART is
  on the pins (from memory: `dtoverlay=disable-bt` in config.txt gives
  the PL011 to GPIO 14 and 15). Only with a cable; the screen is the
  console otherwise (the last words and the watchdog of 8e14e1a5 are
  for that).
- **The start**: the firmware loads `kernel8.img` at 0x80000 and
  enters it at EL2 (`arm_64bit=1`, the Pi 4's default for
  `kernel8.img`), the other cores held in its stub (a spin table at
  0xd8). `l.s` and `start.s` already leave EL3 and EL2 and park the
  other cores by MPIDR. The GIC-400 is on by the firmware's default
  on a Pi 4 (from memory: `enable_gic=1`).
- **The caches**: `start.s` turns the MMU and the caches on (MAIR's
  attribute 2, write-back). What an emulator does not say: exec writes
  a program through the data cache, which the instruction side does
  not see without a clean to the point of unification and an
  invalidate (`mmu_switch`'s comment says so); a DMA engine (the
  sound's) reads the RAM, not the cache. The Pi 1's and the Pi 2's
  cache bugs were found on the boards only (bugs/ix.md).
- **The memory**: the firmware's answer (the ARM's part, under the
  VideoCore's, about 1 GB less its share) is the first GB; the rest of
  a 2, 4 or 8 GB board is said in the device tree the firmware passes
  in x0 (from memory: 0x40000000 to 0xFC000000, then above 4 GB).
  Today the kernel maps and uses 384 MB.
- **The card for three boards**: `kernels/firmware/pi1-pi2` (the
  September 2026 set) has no Pi 4 files: it wants `start4cd.elf` or
  `start4.elf`, `fixup4cd.dat` or `fixup4.dat`, from the same tag
  (`1.20260915`), and `config.txt`'s `[pi4]` with `kernel=mini9pi4.img`
  and `arm_64bit=1`; whether the board's `.dtb` must be there too
  (Circle puts `bcm2711-rpi-4-b.dtb` on its cards) is to be read. The
  programs are the arm ones, the same files as the Pi 1's and Pi 2's.
- **What else the board has**: GENET, its own Ethernet (0xFD580000,
  not a USB device as the Pi 1's); the jack's PWM (another channel and
  pins than the Pi 1's); four cores (plan_multicore.md, the Pi 2's
  done); the CYW43455 (plan_wifi.md).

## Decisions (proposed, for the author)

1. **`lib_machine/pi4/` as it is, the board's and QEMU's in one
   kernel**: what differs is asked of the machine (the firmware, a
   probe), not a flag, as the Pi 2's processor is told by its
   revision.
2. **QEMU first for what it shows** (the firmware's answers, the
   framebuffer's tags, EMMC2 if a card can be put on it); mini-qemu's
   Pi 4 follows each, as for the Pi 2: its lines counted and said.
3. **The keyboard by xHCI on PCIe**, the board's own way, in OCaml
   over a little C as the DWC2's: the hub and HID code shared. What
   else there would be: a serial cable to type on (no keyboard at
   all), or the USB-C port's DWC2 as a host (an OTG adapter, the board
   powered by its pins: mini-9pi's driver as it is; a stopgap, not the
   board as people use it).
4. **One card for the three boards**, the firmware's files of one tag.
5. **The kernel by ix's tools** (what this machine builds); gcc's
   `start.s` kept in step.

## The stages (each checked before the next)

0. **Under QEMU and mini-qemu again** (2026-10-23, the Status). Check:
   `make BOARD=pi4 COMPILER=ix check-ix`, the two emulators' consoles
   alike.
1. **What the firmware says, asked**: `board_rev`, `firmware_rev`, the
   memory, the clock of the SD's controller, by the property channel
   (QEMU answers them; the Pi 1's `pi1/machine.c` asks them already);
   the framebuffer by the property tags. The processes' pages above
   384 MB (the kernel's tables mapping more of the RAM). Check: the
   same sessions; the banner's lines QEMU's numbers, now asked.
2. **The SD card on EMMC2**: `Emmc`'s base the board's (0x340000),
   its clock from the firmware; QEMU with the card there if it can,
   mini-qemu's Pi 4 with an EMMC2. Then **the card**: the Pi 4's
   firmware files, `config.txt`'s `[pi4]`, `make card` with three
   kernels; QEMU's raspi4b with it (`/root` mounted).
3. **The board, its first boots**: the screen (the console, the
   banner's board revision, its memory), the last words if it stops;
   the caches told of exec's code. Then, with no keyboard yet,
   `boot.rc` running a program (a game's demo, `stats=on`) to show the
   processes and the screen work.
4. **The keyboard and the mouse**: PCIe, the VL805, xHCI. On the board
   by stages that each print (the link up, the controller's version,
   a device's descriptor, a key). mini-qemu's model of them if the
   board alone is too slow a loop: to say at stage 3's end.
5. **Not in this plan's first part**: GENET, the sound, the four
   cores, the gcc build on the board itself, WiFi (plan_wifi.md).

## Open questions

- **Which Pi 4**: its memory (1, 2, 4 or 8 GB) and its revision (the
  firmware's code, e.g. 0xc03114 for a 4 GB 1.4: from memory; the
  kernel will print it from stage 1).
- **A serial cable** (USB to 3.3 V TTL, on GPIO 14 and 15)? The first
  boots, and stage 4's, are far quicker with one.
- **The keyboard**: xHCI (decision 3), the large stage, or a stopgap
  first?
- **The screen**: HDMI0 (the port next to the power), at what size
  (the Pi 1's monitor is 1280 by 800)?

## Status

2026-10-23: plan written; **stage 0 done, not committed**. The Pi 4's
kernel built by ix's tools stopped under QEMU 11.1's raspi4b at the
end of its boot since 2026-10-11 (70b6b2bf, /dev/random by the board's
generator): `kernel fault: in the kernel, esr 0000000096000050, elr
ffffff8000082dc8, far ffffff80fe104000`, a bus error writing the
RNG200's control, which QEMU's raspi4b has not (bugs/ix.md's row).
mini-qemu's Pi 4 has one, so nothing said it. Now:
- `Machine.io_probe` on the Pi 4: the kernel's exception entry (`l.s`,
  `start.s`) takes a fault while `probing[0]` is set as the answer and
  goes on after the load, as the Pi 1's `start.s`; `Rng` probes first
  and says no generator. (mini-cc dropped the probe's `(void)*p`, as
  goken's 7c does, "result of operation not used": the value is kept
  in a global.)
- The kernel by ix's tools takes `libc.c`'s word-at-a-time `memmove`
  (now `lib_machine/move.c`, included by `libc.c` and `shim.c`), where
  it had the C library's, Plan 9's, a byte at a time: **the boot to
  rc's prompt under mini-qemu from 65 s to 46 s** (a sampled profile,
  `-prof`: memmove 49% of the instructions, then 23%; the Pi 1's
  kernel by gcc takes 14 s). The Pi 1's and Pi 2's kernels by ix's
  tools have it too (plan_pi2.md: "hello after 80 s ... not looked
  into"); not measured. What is left of it is mini-cc's code, each
  variable on the stack (plan_mini_toolchain_optimization.md's E,
  `mini-cc -simple -O`).
Checked: `make BOARD=pi4 COMPILER=ix check-ix`: the two sessions
under mini-qemu and QEMU give the same consoles byte for byte; against
the records they differ by the lines every board differs by today
(`status hello 28` for 24, four processes more at the boot; `/env/cpu`
and `/dev/cputhrottle`, added since the recording). `move.c`'s
memmove by mini-cc, for arm and arm64 (a program under qemu-arm and
qemu-aarch64): every alignment of the two, forward, backward and
overlapping, sizes 0 to 200, the same bytes as a byte's loop (and a
byte changed on purpose found); `libc.c` compiled by the Pi 1's and
the Pi 4's gcc. Not run: the
graphical checks (`check-menu`...), the Pi 1's and Pi 2's kernels by
ix's tools with the new `memmove`, mini-oberon, mini-squeak and
mini-singularity (their own `machine/` copies, not touched).

2026-10-23, later: **memmove and memset in assembly, in the C library**
(the author: "on principia and plan9 most archi provides their own
memmove in assembly ... Is move.c good enough?", "9front probably has
the arm64 assembly", and Plan 9's way, the assembly linked in the C's
place, both kept: "you can read both versions (and possibly switch and
benchmark too)"). `lib_core/libc/arch/arm64/memmove.s` and `memset.s`
(9front's: 56 and 32 lines, a pair of words 16 bytes a turn, then
bytes) and `arch/arm/` (principia's: 216 and 63), in the place of
`port/`'s C by `lib_core/mkfile`'s `LIBC_MEM5` and `LIBC_MEM7`; every
program by ix's tools has them, and the kernels by ix's tools through
`libc.a`: this morning's `move.c` is gone, `libc.c` (gcc's build) as
before. The Pi 4's boot to its prompt under mini-qemu, one command:

| memmove | time | instructions (sampled) | memmove's |
|---|---:|---:|---:|
| port's C, a byte a turn | 65 s | 722 k | 49% |
| move.c, words (this morning) | 46 s | 474 k | 23% |
| 9front's assembly | 32 s | 326 k | 2.2% |

Next in the profile: the runtime's `move_bytes` (9%: mini-ml's own word
copy in C, written because the library's memmove was a byte loop; it
could now call memmove), `phys_zero`, the Hashtbl's functions.
What the tools took: mini-asm reads 7a's write-back operands
(`(R1)16!`, `-16(R1)!`: its `.P`, `.W`) and 5a's `R(expr)` in a shift
and a list; mini-ld encodes `MOVP` (LDP, STP: 9front's 7l, goken's has
none) and `BIC`. One change to 9front's files: the size read as 32 bits
(`MOVWU`): a `ulong` is 32 bits for mini-cc, which writes only that
word of the argument's slot, and the kernel's heap was overwritten by a
memmove of a size with garbage above it. Checked: `lib_core/libc/tests/
mem_check.sh` (new, in `tests/lite.sh`: every alignment and overlap
against a byte's loop, and a call after one that left all ones in the
slots, on arm and arm64 under qemu); principia's arm files the same
bytes by mini-asm and mini-ld as by goken's 5a and 5l (two golden
cases more, `linker/tests/golden.sh`, 66); in a private copy of the
tree (HEAD and these changes alone): the Pi 4's kernel and the Pi 1's
by ix's tools, each booted under mini-qemu to `hello`;
`languages/ml/tests/run.sh` 5 and 7 on `runtime/` and `tiny/`, all
passing but two arm programs that fail with port's C as well (a
mini-ml bug, bugs/ix.md's row). Not run: `check-ix` and the graphical
checks. **The shared tree's Pi 4 kernel faults at its boot today with
either memmove**: other sessions' changes not committed (mini-ml's
runtime and code generation, the kernel's drawing), not this work.
