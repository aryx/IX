(* This is the Raspberry Pi 4 as QEMU's raspi4b models it, for xv6
 * arm64-pi4 (plan_pi.md, phase G). It has Cortex-A72 cores in AArch64
 * (each is machine/'s Arm64, with its exception levels, and an Mmu64),
 * the RAM from 0, and the BCM2711's devices that the kernels use: the
 * PL011 at 0xfe201000 (the console, SPI 153), GPIO, the GIC-400 at
 * 0xff841000, and each core's generic timer (CNTV and CNTP at 62.5
 * MHz, as QEMU's cortex-a72, on PPIs 27 and 30), and also the random
 * number generator, the mailbox and its framebuffer, the DWC2 USB
 * controller, the EMMC and the DMA. A core also runs AArch32 programs
 * at EL0 (mini-9pi's arm programs) with Arm32. Unassigned I/O reads
 * zero, and what is written to it goes nowhere (with a note under -d).
 *
 * The cores (1 to 4, QEMU's -smp) take turns of [quantum] instructions
 * in one thread, which is deterministic (decision 3). A round of turns
 * is one quantum of time, as if the cores ran side by side. WFI sleeps
 * until an interrupt, and WFE until an event (SEV) or an interrupt; a
 * sleeping core skips its turns. The secondary cores start parked in
 * QEMU's spin stub (QEMU's Linux boot, which behaves as the Pi4's
 * firmware), and the kernel releases them by writing to the spin
 * table. For an ELF, QEMU starts them at its entry instead, which is a
 * race that xv6 wins by timing under QEMU and would lose here. xv6's
 * idle cores spin (its scheduler never waits), so with 4 cores the
 * kernel runs about 4 times slower than with one.
 *
 * Time: the counter advances 62.5 ticks per [ips] instructions (a
 * simulated microsecond, plan_pi.md decision 6). When every core is
 * asleep and nothing is pending, it skips to the next timer's deadline
 * (at most 10ms).
 *
 * Each core's decode cache is indexed by virtual address and
 * privilege, and is emptied by writes to the core's translation
 * registers. Any TLBI or IC empties every core's cache.
 *
 * Where it stands: this is Board's sister, to be read after it (Board's
 * header draws what a board is). The two side by side show seven years
 * of the same product:
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
 * Both have the same PL011, mailbox, SD controller and USB controller,
 * at other addresses, so the devices' modules are shared.
 *
 * design:
 * Several cores run in one thread, by turns. A real Pi 4 runs its
 * cores at once, and a kernel's locks are there for that. Here core 0
 * runs [quantum] instructions, then core 1, and so on. So two cores
 * are never inside the same instruction, and a race needs the turn to
 * end at the wrong place. What is kept is what a kernel can see: four
 * program counters, four sets of registers, interrupts sent to one
 * core and not another, a lock that is found taken. What is given up
 * is finding the races that real hardware would find. What is gained
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
  sd : Sdhost.storage option;          (* -drive if=sd, on the EMMC *)
}

type t

val create : config -> t

(* [load_elf] loads an ELF kernel, as QEMU's -kernel loads one that is
 * not Linux. Its segments go at their physical addresses. Core 0
 * starts at the entry (made physical by the segment that holds it), at
 * EL3, with interrupts masked. The other cores are parked (see
 * above). *)
val load_elf : t -> string -> unit

(* [load_raw] loads a raw image, as QEMU's -kernel boots one and as the
 * firmware boots kernel8.img. It goes at 0x80000, and core 0 starts
 * there at EL2, with interrupts masked. *)
val load_raw : t -> string -> unit

(* a character from the host, for the PL011 *)
val input : t -> char -> unit

(* [run] runs [batch] instructions, then the timers *)
val run : t -> batch:int -> unit

(* the time, counted in the instructions of a core *)
val instructions : t -> int

(* each core's PC after a batch, for mini-qemu's -status *)
val where : t -> Status.cpu list

(* the board's time in microseconds (from its generic timer) *)
val now : t -> int

(* the framebuffer (given out by the mailbox): [screen] gives it as RGB
 * (for QMP's screendump), and [frame] as the kernel wrote it (for the
 * window); both give None before a kernel asks for one *)
val screen : t -> (int * int * string) option
val frame : t -> (Framebuffer.geometry * string) option

(* the USB keyboard and mouse (-device usb-kbd, usb-mouse, on the
 * DWC2): [key] presses or releases a key now, [send_keys] presses keys
 * then releases them (QMP's send-key), and [pointer] gives the mouse's
 * input *)
val key : t -> int -> bool -> unit
val send_keys : t -> int list -> hold:int -> unit
val pointer : t -> Usb.input list -> unit
