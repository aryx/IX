(* The Raspberry Pi 1 as QEMU's raspi1ap models it (plan_pi.md, phase
 * A): an ARM1176 (machine/'s Arm32 with its privileged state, Mmu32),
 * 512MB of RAM (the VideoCore's 64MB at the top), and the BCM2835's
 * devices the kernels use: the interrupt controller, the system timer,
 * the PL011, AUX's mini UART, GPIO, the mailbox, the DWC2's registers;
 * the rest of the I/O space reads zero.
 *
 * The loop: before each instruction the IRQ line (when unmasked); the
 * fetch through the MMU into a decode cache by virtual address (and
 * privilege), emptied with the TLB and by I-cache invalidations;
 * aborts, undefined instructions and svc as the architecture's
 * exceptions, DFSR and DFAR, IFSR and IFAR set. Time is counted in
 * instructions: the system timer's microsecond every [ips].
 *
 * This is mini-qemu's main module (Main has QEMU's command line and
 * the terminal, MiniQemuWeb the same board in a page; Pi4 is the
 * other board). A computer, to the kernel that runs on it, is a
 * processor and a map of addresses:
 *
 *     0x00000000  RAM, 512 MB           the kernel's image at 0x8000
 *                 (the top 64 MB the    (or 0x10000, QEMU's -kernel)
 *                 VideoCore's: the framebuffer is there)
 *     0x20000000  the I/O space, 16 MB: registers, not memory
 *       + 0x003000  Systimer    a counter of microseconds, 4 alarms
 *       + 0x007000  Dma         copies memory to and from a device
 *       + 0x00b200  Intc        which devices ask for attention
 *       + 0x00b880  Devices' mailbox   questions to the firmware:
 *                               the memory's size, a framebuffer
 *       + 0x200000  GPIO        the pins (registers kept, no pin)
 *       + 0x201000  Pl011       a serial line: the console
 *       + 0x215000  Miniuart    another
 *       + 0x300000  Sdhost      the SD card: the disk
 *       + 0x980000  Dwc2        USB: a keyboard, a mouse, a network
 *
 * and one wire the other way, the interrupt:
 *
 *     Pl011 (a character arrived)      line 57 --.
 *     Systimer (an alarm)              lines 0-3 -+-> Intc: enabled?
 *     Sdhost 62, Miniuart 29, Dwc2 9,           -'      |
 *     Dma 16 and up                                     v  irq
 *                       [run], before each instruction: if the CPSR
 *                       does not mask it, Arm32.take Irq: the pc
 *                       becomes 0x18, the kernel's handler
 *
 * The handler asks Intc which line, calls that driver, the driver
 * reads the device's register, which lowers the line. That loop,
 * device to controller to processor to kernel to device, is all of
 * what "hardware" means to an operating system, and each module of
 * this directory is one box of it, its registers answering as the
 * BCM2835's manual and QEMU's model say.
 *
 * The modules:
 *
 *     Main, MiniQemuWeb     the host's side: a terminal, a window,
 *        |                  a page; QEMU's options
 *        | Qmp, Status, Prof   asked from outside: a screen dump, a
 *        |                  key, where the guest is, a profile
 *     Board (Pi4)           the map above, the loop
 *        |-- Arm32, Mmu32, Memory     machine/'s: the processor
 *        |-- Intc (Gic), Systimer     interrupts and time
 *        |-- Pl011, Miniuart          characters
 *        |-- Devices -> Framebuffer -> Display (Sdl_display)   pixels
 *        |-- Sdhost <- Storage, Dma   blocks
 *        '-- Dwc2 -> Usb -> Usernet   keys, a mouse, packets
 *
 * Where it stands: the kernels of ix (mini-9pi, mini-xv6) are
 * linked by mini-ld, started here by [load_kernel] or [load_raw],
 * and run the programs of the whole tree; the same core runs one
 * program without a kernel in mini-5i (machine's CLI.mli says how
 * the two differ). What boots here is meant to boot under QEMU
 * with the same command line, and on a real Pi 1.
 *
 * design:
 * Time is the count of instructions: a microsecond of the board is
 * [ips] of them, whatever the host's clock did meanwhile. So a run
 * is repeatable, the same keys at the same instructions giving the
 * same screen, which is what lets a boot be a test with a recorded
 * session, and a bug be found again. The price is that the board's
 * second is not ours; Main holds the two together when there is a
 * window, and only then.
 *
 * cs-history:
 * The Raspberry Pi (2012) was made to be a cheap computer for
 * learning to program, around a chip that existed for other
 * things: the BCM2835 is a graphics processor, the VideoCore, with
 * an ARM beside it. It shows in how it starts. The VideoCore boots
 * first, reads its firmware and the kernel's image from the SD
 * card, puts the image in memory at 0x8000 and only then lets the
 * ARM run; and the ARM asks the VideoCore for what a PC's BIOS
 * would tell, the memory's size and a framebuffer, through the
 * mailbox. An emulator skips the first half: [load_raw] is the
 * firmware's last act.
 *
 * others:
 * QEMU (Fabrice Bellard, from 2003) is this for many machines and
 * many processors, with a translator to the host's code
 * where this interprets (Cpu.mli), and devices written against the
 * same manuals: its raspi1ap is the model followed here, register
 * by register where a kernel could see a difference, so that one
 * can be run against the other.
 *
 * References: BCM2835 ARM Peripherals (Broadcom, 2012; from
 * memory), the manual of the map above; QEMU's hw/arm/raspi.c and
 * bcm2835_peripherals.c (from memory) for the model; Fabrice
 * Bellard, "QEMU, a Fast and Portable Dynamic Translator" (USENIX,
 * 2005). *)

type config = {
  ram_size : int;
  ips : int;                      (* instructions per microsecond *)
  log : string -> unit;           (* what a user may want to know: unassigned I/O, undefined instructions *)
  usb_devices : string list;     (* -device usb-kbd, usb-mouse, in order *)
  sd : Sdhost.storage option;     (* -drive ...,if=sd *)
  serial0 : char -> unit;         (* the PL011's output (QEMU's first -serial) *)
  serial1 : char -> unit;         (* the mini UART's (the second) *)
  console : int;                  (* the serial the host's input goes to *)
}

type t

val create : config -> t

(* a raw kernel image, as QEMU's -kernel loads it *)
val load_kernel : t -> string -> unit

(* a raw image at an address, the CPU starting there (-device loader,
 * -bios) *)
val load_raw : t -> addr:int -> string -> unit

(* a character typed, for the console's UART *)
val input : t -> char -> unit

(* [batch] instructions, then time and the UART's input *)
val run : t -> batch:int -> unit

(* the screen: width, height, RGB bytes; none before the kernel asked for
 * a framebuffer *)
val screen : t -> (int * int * string) option

(* the framebuffer as the kernel wrote it, for a display *)
val frame : t -> (Framebuffer.geometry * string) option

(* the same in place, not copied: the RAM's bytes and where the pixels
 * start (Framebuffer.direct) *)
val frame_direct : t -> (Framebuffer.geometry * Bytes.t * int) option

(* the board's time, microseconds *)
val now : t -> int

(* where the CPU is, after a batch: mini-qemu's -status *)
val where : t -> Status.cpu list

(* a key down or up on the USB keyboard (-device usb-kbd), by HID usage *)
val key : t -> int -> bool -> unit

(* the mouse's input now (QMP's input-send-event), then synced *)
val pointer : t -> Usb.input list -> unit

(* keys pressed now and released after [hold] microseconds of the
 * board's time (QMP's send-key) *)
val send_keys : t -> int list -> hold:int -> unit

(* Faster, each a switch (Board.ml says what they do): the decode
 * cache emptied by the slots used, a word's decoding kept *)
val forget_used : bool ref
val keep_decoded : bool ref
