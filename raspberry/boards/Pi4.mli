(* The Raspberry Pi 4 as QEMU's raspi4b models it, for xv6 arm64-pi4
 * (plan_pi.md, phase G): Cortex-A72 cores in AArch64 (machine/'s Arm64
 * with its exception levels, Mmu64, each), the RAM from 0, and the
 * BCM2711's devices the kernel uses: the PL011 at 0xfe201000 (the
 * console, SPI 153), GPIO, the GIC-400 at 0xff841000, and each core's
 * generic timer (CNTV and CNTP at 62.5 MHz, QEMU's cortex-a72, on
 * PPIs 27 and 30). Unassigned I/O reads zero, written to nowhere (a
 * note with -d).
 *
 * The cores (1 to 4, QEMU's -smp) take turns of [quantum] instructions
 * in one thread, deterministic (decision 3); a round of turns is one
 * quantum of time, the cores running side by side. WFI sleeps until an
 * interrupt, WFE until an event (SEV) or an interrupt; a sleeping core
 * skips its turns. The secondary cores start parked in QEMU's spin
 * stub (its Linux boot: the Pi4's firmware's behaviour), released by
 * the kernel's write to the spin table; QEMU starts them at an ELF's
 * entry instead, a race xv6 wins by timing under QEMU and would lose
 * here. xv6's idle cores spin (its scheduler never waits), so with 4
 * cores the kernel runs about 4 times slower than with one.
 *
 * Time: the counter advances 62.5 ticks per [ips] instructions (a
 * simulated microsecond, plan_pi.md decision 6); with every core
 * asleep and nothing pending, it skips to the next timer's deadline
 * (at most 10ms).
 *
 * Each core's decode cache is by virtual address and privilege,
 * emptied by writes to its translation registers; any TLBI or IC
 * empties every core's.
 *
 * Where it stands: Board's sister, read after it (its header draws
 * what a board is). The two side by side are seven years of the
 * same product:
 *
 *                 Pi 1 (Board)             Pi 4 (here)
 *     the chip    BCM2835                  BCM2711
 *     the core    one ARM1176, 32 bits     four Cortex-A72, 64 bits
 *                 Arm32, Mmu32             Arm64, Mmu64
 *     I/O at      0x20000000               0xfe000000
 *     interrupts  Intc: 64 bits to test    Gic: priorities, a
 *                                          register to acknowledge
 *     the clock   Systimer, a device       each core's own timer,
 *                                          system registers
 *     a kernel    at 0x8000, in svc mode   at 0x80000, at EL2 (EL3
 *                                          for an ELF): it must come
 *                                          down to EL1 itself
 *
 * and the same PL011, mailbox, SD controller and USB controller, at
 * other addresses: the devices' modules are shared.
 *
 * design:
 * Several cores in one thread, by turns. A real Pi 4 runs its cores
 * at once, and a kernel's locks are there for that; here core 0
 * runs [quantum] instructions, then core 1, and so on, so two cores
 * are never inside the same instruction, and a race needs the turn
 * to end at the wrong place. What is kept is what a kernel can see:
 * four program counters, four sets of registers, interrupts sent to
 * one core and not another, a lock that is found taken. What is
 * given up is finding the races real hardware would; what is gained
 * is that a run is the same every time, and a bug met once is met
 * again. *)

type config = {
  ram_size : int;
  ips : int;
  log : string -> unit;
  serial : char -> unit;               (* the PL011 *)
  trace : int;                         (* the first N instructions to the log, or every -N-th; 0 none *)
  cores : int;                         (* 1 to 4 *)
  usb_devices : string list;           (* -device usb-kbd, usb-mouse, in order *)
  sd : Sdhost.storage option;          (* claude: -drive if=sd, on the EMMC *)
}

type t

val create : config -> t

(* an ELF kernel, as QEMU's -kernel loads one that is not Linux: its
 * segments at their physical addresses, core 0 at the entry (by the
 * segment that holds it, physical) at EL3, interrupts masked; the
 * others parked (above) *)
val load_elf : t -> string -> unit

(* a raw image, as QEMU's -kernel boots one and the firmware
 * kernel8.img: at 0x80000, core 0 there at EL2, interrupts masked *)
val load_raw : t -> string -> unit

(* a character from the host, for the PL011 *)
val input : t -> char -> unit

(* [batch] instructions, then the timers *)
val run : t -> batch:int -> unit

(* the time, in instructions of a core *)
val instructions : t -> int

(* each core's PC, after a batch: mini-qemu's -status *)
val where : t -> Status.cpu list

(* the board's time, microseconds (its generic timer's) *)
val now : t -> int

(* the framebuffer (the mailbox's): as RGB (QMP's screendump), as the
 * kernel wrote it (the window); None before a kernel asks for one *)
val screen : t -> (int * int * string) option
val frame : t -> (Framebuffer.geometry * string) option

(* the USB keyboard and mouse (-device usb-kbd, usb-mouse, on the DWC2):
 * a key now, keys pressed then released (QMP's send-key), the mouse's
 * input *)
val key : t -> int -> bool -> unit
val send_keys : t -> int list -> hold:int -> unit
val pointer : t -> Usb.input list -> unit
