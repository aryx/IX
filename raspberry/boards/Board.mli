(* This is the Raspberry Pi 1 as QEMU's raspi1ap models it (plan_pi.md,
 * phase A). It has an ARM1176 (machine/'s Arm32 with its privileged
 * state, and an Mmu32), 512MB of RAM (with the VideoCore's 64MB at the
 * top), and the BCM2835's devices that the kernels use: the interrupt
 * controller, the system timer, the PL011, AUX's mini UART, GPIO, the
 * mailbox, the random number generator, the DMA, the SD host, the PWM
 * and its clock, and the DWC2 USB controller. The rest of the I/O space
 * reads zero.
 *
 * The loop works as follows. Before each instruction, it looks at the
 * IRQ line (when it is unmasked). It fetches through the MMU into a
 * decode cache indexed by virtual address (and privilege), which is
 * emptied with the TLB and by I-cache invalidations. Aborts, undefined
 * instructions and svc are taken as the architecture's exceptions,
 * with DFSR and DFAR, or IFSR and IFAR, set. Time is counted in
 * instructions: the system timer advances by a microsecond every
 * [ips] instructions.
 *
 * This is mini-qemu's main module. Main has QEMU's command line and
 * the terminal, MiniQemuWeb has the same board in a page, and Pi4 is
 * the other board. To the kernel that runs on it, a computer is a
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
 *       + 0x104000  Devices' rng   random numbers
 *       + 0x200000  GPIO        the pins (registers kept, no pin)
 *       + 0x1010a0  Pwm's clock  how fast its periods are
 *       + 0x201000  Pl011       a serial line: the console
 *       + 0x20c000  Pwm         the jack: a sample a period, two ears
 *       + 0x215000  Miniuart    another
 *       + 0x300000  Sdhost      the SD card: the disk
 *       + 0x980000  Dwc2        USB: a keyboard, a mouse, a network
 *
 * The Pi 2 (config's [pi2], QEMU's raspi2b) is this board with a few
 * differences: 1 GB of RAM, the same devices at 0x3F000000 (the
 * BCM2836's place for them, over the last 16 MB of that GB), and a
 * Cortex-A7's identification and cache registers for an ARMv7 kernel
 * to read. It has four cores, once they are started (start_core,
 * below). They take turns in one thread, a batch of instructions
 * each, so a run is the same each time. A core that waits skips its
 * turns, and four busy cores take four times one core's time on the
 * host. (Or each core runs on a domain of the host's, when this is
 * asked and under OCaml 5: see [cores_parallel], below.) With the
 * cores come the cores' controller at 0x40000000 (each core's
 * mailboxes, and which of its timers and mailboxes interrupt it) and
 * each core's virtual timer (CNTV). What is not there: the other three
 * generic timers, the controller's own timer, and a core other than
 * the first taking the devices' interrupts.
 *
 * There is also one wire the other way, the interrupt:
 *
 *     Pl011 (a character arrived)      line 57 --.
 *     Systimer (an alarm)              lines 0-3 -+-> Intc: enabled?
 *     Sdhost 62, Miniuart 29, Dwc2 9,           -'      |
 *     Dma 16 and up                                     v  irq
 *                       [run], before each instruction: if the CPSR
 *                       does not mask it, Arm32.take Irq: the pc
 *                       becomes 0x18, the kernel's handler
 *
 * The handler asks Intc which line is up, and calls that line's
 * driver. The driver reads the device's register, which lowers the
 * line. That loop, from device to controller to processor to kernel
 * to device, is all that "hardware" means to an operating system. Each
 * module of this directory is one box of it, and its registers answer
 * as the BCM2835's manual and QEMU's model say.
 *
 * Here are the modules:
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
 * Where it stands: the kernels of ix (mini-9pi, mini-xv6) are linked
 * by mini-ld, started here by [load_kernel] or [load_raw], and run the
 * programs of the whole tree. The same core runs one program without
 * a kernel in mini-5i (machine's CLI.mli says how the two differ).
 * What boots here is meant to boot under QEMU with the same command
 * line, and on a real Pi 1.
 *
 * design:
 * Time is the count of instructions: a microsecond of the board is
 * [ips] instructions, whatever the host's clock did meanwhile. So a
 * run is repeatable: the same keys at the same instructions give the
 * same screen. That is what lets a boot be a test with a recorded
 * session, and lets a bug be found again. The price is that the
 * board's second is not ours. Main holds the two together when there
 * is a window, and only then.
 *
 * cs-history:
 * The Raspberry Pi (2012) was made to be a cheap computer for
 * learning to program, around a chip that existed for other things:
 * the BCM2835 is a graphics processor, the VideoCore, with an ARM
 * beside it. It shows in how the board starts. The VideoCore boots
 * first, reads its firmware and the kernel's image from the SD card,
 * puts the image in memory at 0x8000, and only then lets the ARM run.
 * Then the ARM asks the VideoCore, through the mailbox, for what a
 * PC's BIOS would tell: the memory's size and a framebuffer. An
 * emulator skips the first half, and [load_raw] does the firmware's
 * last act.
 *
 * others:
 * QEMU (Fabrice Bellard, from 2003) does this for many machines and
 * many processors. It has a translator to the host's code where this
 * module interprets (Cpu.mli), and devices written against the same
 * manuals. Its raspi1ap is the model followed here, register by
 * register wherever a kernel could see a difference, so that one can
 * be run against the other.
 *
 * References: BCM2835 ARM Peripherals (Broadcom, 2012), the manual
 * of the map above; QEMU's hw/arm/raspi.c and
 * bcm2835_peripherals.c for the model; Fabrice
 * Bellard, "QEMU, a Fast and Portable Dynamic Translator" (USENIX,
 * 2005). *)

type config = {
  pi2 : bool;                     (* a Pi 2 as QEMU's raspi2b: see above *)
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

(* [set_audio] says where the jack's samples go (Pwm). The function is
 * given the rate, the left ear's sample and the right one's (with the
 * A+'s wiring, where the PWM's second channel is the left ear).
 * Without it, the samples are dropped. *)
val set_audio : t -> (rate:int -> int -> int -> unit) -> unit

(* a raw kernel image, as QEMU's -kernel loads it *)
val load_kernel : t -> string -> unit

(* a raw image at an address, with the CPU starting there (-device
 * loader, -bios) *)
val load_raw : t -> addr:int -> string -> unit
(* The Pi 2's other cores (1 to 3): [start_core] starts one at an
 * address, in its reset state, as QEMU's -device
 * loader,addr=,cpu-num=n does. None is started unless asked. The
 * cores take turns, a batch each, in one thread, so a run is the same
 * each time. Each core has its registers, its MMU and its decode
 * cache, its virtual timer (CNTV) and its mailboxes, and the cores'
 * controller (the BCM2836's, at 0x40000000) routes those to it. The
 * devices' interrupts go to the first core. *)
val start_core : t -> int -> addr:int -> unit
(* [cores_parallel] runs the started cores each on a domain of the
 * host's, and not by turns (Board.ml says what they share and how).
 * It is set before [create], for a Pi 2, and works only where the
 * compiler has domains (OCaml 5: Parallel.available); otherwise the
 * cores take turns. Four busy cores then take one core's time, but a
 * run is no longer the same each time. [parallel] says what a board
 * got. In parallel, what touches the board from outside while its
 * cores run (a key, a character typed, the output of [serial0] taken,
 * a network's packets) is done inside [locked]; [run] and [where] are
 * not. Without domains, [locked t f] is [f ()]. *)
val cores_parallel : bool ref
val parallel : t -> bool
val locked : t -> (unit -> 'a) -> 'a

(* a word put in memory (-device loader,addr=,data=,data-len=4) *)
val poke : t -> addr:int -> int -> unit

(* a character typed, for the console's UART *)
val input : t -> char -> unit

(* [run] runs [batch] instructions, then time and the UART's input *)
val run : t -> batch:int -> unit

(* the screen: the width, the height and the RGB bytes; none before the
 * kernel asked for a framebuffer *)
val screen : t -> (int * int * string) option

(* the framebuffer as the kernel wrote it, for a display *)
val frame : t -> (Framebuffer.geometry * string) option

(* the same in place, not copied: the RAM's bytes, and where the pixels
 * start in them (Framebuffer.direct) *)
val frame_direct : t -> (Framebuffer.geometry * Bytes.t * int) option

(* the board's time, in microseconds *)
val now : t -> int

(* sets the instructions in a microsecond, from now on (config's ips) *)
val set_ips : t -> int -> unit

(* where the CPU is after a batch, for mini-qemu's -status *)
val where : t -> Status.cpu list

(* a key down or up on the USB keyboard (-device usb-kbd), by HID usage *)
val key : t -> int -> bool -> unit

(* the mouse's input, given now (QMP's input-send-event), then synced *)
val pointer : t -> Usb.input list -> unit

(* keys pressed now and released after [hold] microseconds of the
 * board's time (QMP's send-key) *)
val send_keys : t -> int list -> hold:int -> unit

(* Two switches that make the board faster (Board.ml says what they
 * do): [forget_used] empties the decode cache by the slots used, and
 * [keep_decoded] keeps a word's decoding. *)
val forget_used : bool ref
val keep_decoded : bool ref

(* a kernel built for a page may ask the board to move and fill bytes
 * itself (kernels/lib_machine/web/). When this is off, its request is
 * an undefined instruction, as on the Pi. *)
val host_calls : bool ref

(* Blocks of instructions translated by the host (Board.ml says how
 * they are asked for; web/jit's Jit sets these). They are: whether
 * blocks are on, the translator's entry, the instructions done by a
 * block that raised, the decode cache emptied, and instructions
 * written. [parts] gives the state, the MMU and the memory. *)
val blocks_on : bool ref
val blocks : (int -> int) ref
val blocks_done : (unit -> int) ref
val blocks_forget : (unit -> unit) ref
val blocks_written : (int -> int -> unit) ref
val parts : t -> Arm32_isa.state * Mmu32.t * Memory.t
(* [code_page] says an instruction was fetched from this physical
 * address. The translator says so too, so that a kernel's notice that
 * a page was written is then acted on for that page. *)
val code_page : int -> unit

(* Such a kernel's keys, mouse and cursor, when its host is a page
 * (Board.ml has the requests). [host_key] gives a key by its USB
 * usage, down or up. *)
val host_key : int -> bool -> unit

(* memdraw's general loop for such a kernel (Board.ml; web/draw's
 * Hostdraw sets it). It is given the memory, a function that finds n
 * bytes at an address of the kernel's (to write them or not, and
 * gives where they are, or -1), and the request's address. It returns
 * 1 when it drew, 0 when it does not draw this one, and -1 when there
 * is no host that draws. *)
val host_draw : (Memory.t -> (int -> int -> bool -> int) -> int -> int) ref
(* [host_pointer] gives the mouse at (x, y) of the screen, with its
 * buttons (1 left, 2 middle, 4 right). When [host_cursor] is set, the
 * host draws the cursor and the kernel does not. *)
val host_pointer : int -> int -> int -> unit
val host_cursor : bool ref

(* the screen's rows that such a kernel wrote since the host last asked
 * ([first, after)), once the host said where the framebuffer is
 * ([host_watch]: its first byte's physical address, the bytes in a
 * row, the rows) *)
val host_watch : base:int -> pitch:int -> rows:int -> unit
val host_rows : unit -> (int * int) option
(* [host_shape] is the count of the cursors given, and the last one's
 * 66 bytes (its offset in two signed bytes, then the clr bits and the
 * set bits, 16 by 16). *)
val host_shape : (int * string) ref
