(* mini-xv6: the machine, as the board's machine.c and runtime.c give it
 * (the same names on the Pi1 and the Pi4). Addresses are ints: a
 * user's and a physical one fit OCaml's (31 bits on the Pi1: below
 * 1GB; 63 on the Pi4); the kernel's own never reach OCaml (plan_kernel.md,
 * decision 3; kernels/steps/step4).
 *
 * For a reader who knows OCaml and not the hardware, what is under
 * these names:
 *
 *   a program's address ---- the MMU, by the process's table ---> a
 *   (virtual: what its                                            physical
 *   pointers hold)                                                address
 *
 *   physical addresses: the RAM from 0, and, far above it, the devices'
 *   registers (a register is a word that is not memory: writing it
 *   tells a device to do something, reading it asks what it has)
 *
 * The kernel reaches both through the functions here, in C and
 * assembly underneath: OCaml has no pointers, and what a register
 * means is the device's affair, not the language's. Three things then
 * come up again and again:
 * - the MMU (memory management unit): the part of the processor that
 *   does the translation drawn above, at every access, which is what
 *   keeps a program in its own memory;
 * - a trap: the processor leaving the user's program for the kernel,
 *   at a system call, a fault or an interrupt (a device asking for
 *   attention; IRQ, interrupt request, is the wire it asks by and the
 *   name of the event), its registers saved to be given back;
 * - time: a device is slower than the processor, and a driver waits
 *   for it (the timer below);
 * - the firmware: the Pi's other processor (the VideoCore, its GPU,
 *   the graphics processor, which on this board is also the master)
 *   starts first, sets the board up, loads the kernel and stays there
 *   to be asked things (the framebuffer, a clock's rate), through a
 *   pair of registers called the mailbox.
 *
 * Where it stands. Every kernel of this tree is OCaml above this
 * interface and C and assembly below it, and links the same file
 * (mini-oberon, mini-singularity and mini-squeak by a symbolic link
 * in their machine/ directory):
 *
 *     mini-xv6   mini-9pi   mini-oberon   mini-singularity   ...
 *     ------------------------- Machine --------------------------
 *     machine.c, start.s, board.h (pi1/, pi4/)   the board
 *     runtime.c, shim.c, libc.c     what OCaml's runtime asks of
 *                                   a system, there being none
 *
 * A kernel that has no processes uses a third of it (mini-oberon:
 * the framebuffer, the timer, the UART); the trap frame and the
 * MMU's functions are for those that run user programs. What the
 * emulators of this tree implement (mini-qemu's Board and its
 * devices) is the other side of the same registers.
 *
 * design:
 * An address is an int, a register's access a function: no pointer
 * type, no record laid over memory. It is the least a typed language
 * needs to be a kernel's, and it keeps the unsafe part countable:
 * the externals below are all of it. Other kernels in safe
 * languages make the same cut with more types on it (a typed view
 * of a device's registers in Singularity and in Rust's embedded
 * crates); Oberon's own has a pseudo-module, SYSTEM, whose import
 * marks a module as unsafe.
 *
 * References: "BCM2835 ARM Peripherals" (Broadcom, 2012), the Pi1's
 * devices register by register (with known errors: its errata are
 * kept at elinux.org); the "PrimeCell UART (PL011) Technical
 * Reference Manual" (ARM); the Raspberry Pi firmware's wiki,
 * "Mailbox property interface", for the tags asked of the
 * VideoCore. notes_kernel.md, the tutorial: what OCaml's runtime
 * needs with no system under it. *)

(* Physical memory, by physical address: a page of a process, a page
 * table, a device's buffer. The kernel's own data is OCaml's values;
 * this is the memory it manages for others, which no OCaml value is
 * in. get and set are a byte, two or four (the lowest byte first). *)
module Phys : sig
  external get8 : int -> int = "phys_get8"
  external set8 : int -> int -> unit = "phys_set8"
  external get16 : int -> int = "phys_get16"
  external set16 : int -> int -> unit = "phys_set16"
  external get32 : int -> int = "phys_get32"
  external set32 : int -> int -> unit = "phys_set32"
  (* [zero pa n]: n a multiple of 4 *)
  external zero : int -> int -> unit = "phys_zero"
  (* [copy dst src n], [write pa s], [read pa n] *)
  external copy : int -> int -> int -> unit = "phys_copy"
  external write : int -> string -> unit = "phys_write"
  (* [write_sub pa s off n]: s's n bytes at off, no String.sub *)
  external write_sub : int -> string -> int -> int -> unit = "phys_write_sub"
  external read : int -> int -> string = "phys_read"
  (* [sync pa n]: n bytes a process wrote at pa, which it will run: in
   * memory, and not in the instructions' cache (segflush) *)
  external sync : int -> int -> unit = "phys_sync"
end

(* The trap frame: the user's registers as they were when its program
 * was left for the kernel (the general ones, where it was, its flags),
 * saved by the assembly at the trap and loaded back at the return. A
 * system call's arguments are read there and its result written there;
 * a new process is given one made up. Each process (a slot) has its
 * own; these are the running one's, by word (Arch: its layout, the
 * board's). *)
(* The images' memory, outside OCaml's heap (runtime.c says why:
 * principia's imagmem, and pixels copied while another core is in the
 * kernel). [init pa n]: its arena, n bytes of physical memory at pa.
 * [alloc n]: n zeroed bytes there, which neither collector moves or
 * looks at, and are a Bytes.t like any to read and write; of length 0
 * when there is no room (n > 0: the caller then takes Bytes.make).
 * [free b]: given back (one of the heap's: nothing). [used ()]: the
 * bytes taken, of [size ()]. The copies, each with the kernel's lock given back
 * when what it reads and writes is the arena's and it is large:
 * - [copy dst src [| da; dbw; sa; sbw; n; dy; up |]]: dy rows of n
 *   bytes, from sa in src every sbw to da in dst every dbw, the last
 *   row first when up is not 0;
 * - [rows b a0 bw len dy]: the len bytes at a0 repeated in the dy - 1
 *   rows below, bw apart;
 * - [scale dst src [| da; dbw; sa; sbw; bpp; k; px; py; w; h |]]: src's
 *   pixels of bpp bytes each k by k in dst's w by h from da, the first
 *   px columns and py rows into its pixel's k by k (an ix extension
 *   of the draw device's: Memdraw.scale);
 * - [flush b [| pa; pitch; off; bw; n; rows |]]: rows of n bytes from
 *   off in b every bw, to physical memory at pa every pitch (the
 *   framebuffer).
 * And what such a copy must not meet (runtime.c): [screen b] says
 * which image is the screen's, [covers lo hi] whether a copy is
 * writing its bytes lo to hi now (the cursor's clock then leaves
 * them), [quiet ()] waits until no copy is under way: before an image
 * is freed, a window made, moved, restacked or deleted. [switch n]:
 * which copies give the lock back, 1 a copy, 2 a fill, 4 a flush (7
 * at the start; 0: none, every copy with the lock held). *)
module Imag : sig
  external init : int -> int -> unit = "imag_init"
  external alloc : int -> Bytes.t = "imag_alloc"
  external free : Bytes.t -> unit = "imag_free"
  external used : unit -> int = "imag_stats"
  external size : unit -> int = "imag_size"
  external copy : Bytes.t -> Bytes.t -> int array -> unit = "imag_copy"
  external rows : Bytes.t -> int -> int -> int -> int -> unit = "imag_rows"
  external scale : Bytes.t -> Bytes.t -> int array -> unit = "imag_scale"
  external flush : Bytes.t -> int array -> unit = "imag_flush"
  external screen : Bytes.t -> unit = "imag_screen"
  external covers : int -> int -> bool = "imag_covers"
  external quiet : unit -> unit = "imag_quiet"
  external switch : int -> unit = "imag_switch"
end
external tf_get : int -> int = "tf_get"
external tf_set : int -> int -> unit = "tf_set"
(* a slot's trap frame: zeros, user mode, IRQs on *)
external tf_init : int -> unit = "tf_init"
(* the running process's copied to a slot's, the first register 0
 * (fork's child) *)
external tf_copy : int -> unit = "tf_copy"
(* the running process's trap frame as bytes, whole (a word a
 * register, the board's layout; their 32 bits: mini-9pi's notes) *)
external tf_bytes : unit -> string = "tf_bytes"
external tf_set_bytes : string -> unit = "tf_set_bytes"
(* a slot's, whole: a stopped process's, for its debugger (/proc/n/regs) *)
external tf_slot_bytes : int -> string = "tf_slot_bytes"
external tf_slot_set_bytes : int -> string -> unit = "tf_slot_set_bytes"

(* A process in the kernel has a stack of its own there (the kernel's
 * calls made for it, among them the one that waits), and going from
 * one process to another is changing stacks: the registers a function
 * must keep are saved on the one left and loaded from the other, and
 * the call returns in the other process, where it had called swtch
 * itself some time before. *)
(* a slot's kernel stack made fresh: its first switch enters
 * "process_start"; a slot freed (the collector no longer scans it) *)
external proc_context : int -> unit = "proc_context"
external proc_free : int -> unit = "proc_free"
(* to a slot (a process's, or nproc: the scheduler's); the running one *)
external swtch : int -> unit = "k_swtch"
external current : unit -> int = "k_current"
(* back to user mode, from the running process's trap frame *)
external user_resume : unit -> unit = "user_resume"

(* The MMU translates each address a program uses by a table the
 * kernel wrote, the process's; the processor has a register that says
 * which table (TTBR0, translation table base register 0), and keeps
 * the translations it has done so as not to read the table each time
 * (the TLB, translation lookaside buffer), which are another
 * process's once the table changes: they are thrown away (flushed).
 * [mmu_switch pa]: the user's table in TTBR0 (0: the empty one), the
 * TLB flushed. *)
external mmu_switch : int -> unit = "mmu_switch"

(* The system timer: a counter of microseconds that the board runs,
 * and an alarm on it. [timer_arm us]: an interrupt in [us]
 * microseconds, the kernel's tick; [timer_pending]: the alarm has
 * rung. An interrupt is only taken when the processor lets it (in
 * user mode here), so the kernel also looks. *)
external timer_arm : int -> unit = "timer_arm"
external timer_pending : unit -> bool = "timer_pending"
(* the counter, the 30 low bits of it: the time, when ticks were
 * missed, and a driver's waits (a device given the time it asks) *)
external timer_now : unit -> int = "timer_now"
(* The processor's caches on. Memory is many times slower than
 * the processor; a cache is a small fast copy of the memory last
 * used, without which every instruction waits for the memory. What is
 * in the cache and not yet in the memory is not seen by a device that
 * reads the memory itself: pi1/machine.c says what that asks of the
 * rest (elsewhere, nothing). *)
external caches_on : unit -> unit = "caches_on"

(* the board's other cores started and left idle (the Pi 2: plan_multicore.md,
 * stage 2); how many cores are up, this one counted; when one did not
 * come up, its number, plus 16 times how far its start went (pi1's
 * machine.c) *)
external cores_start : unit -> int = "cores_start"

(* Several cores (plan_multicore.md), where the board has them and the
 * kernel is built for them; elsewhere there is one core, 0, and these
 * do nothing. The kernel has one lock, taken by a core where it
 * enters the kernel (a trap, an interrupt) and given back where it
 * leaves (user mode, wait_interrupt): one core at a time runs what is
 * above this interface, which needs no lock of its own. What a kernel
 * must know is less: that a process may go on while the kernel runs
 * for another, that [current] and the trap frame are this core's,
 * that the devices' interrupts and the clock are the first core's
 * (the others have a tick of their own, for a process's slice).
 * - [cores_run n]: from now on the [n] cores started each run the
 *   function registered as "scheduler" (the first is the caller,
 *   which goes on to call its own);
 * - [cores_test ()]: do so under an emulator too (SMP=1 at the build);
 * - [cores_wake ()]: a process was made ready; a core that waits looks;
 * - [core ()]: this core's number;
 * - [core_tick ()]: in an interrupt of a core other than the first,
 *   was it its timer's (armed again) *)
external cores_run : int -> unit = "cores_run"
external cores_test : unit -> bool = "cores_test"
external cores_wake : unit -> unit = "cores_wake"
external core : unit -> int = "k_core"
(* is a page's entry to say that several cores share it (the Pi 1's
 * and the Pi 2's Arch; the Pi 2: yes) *)
external pages_shared : unit -> bool = "pages_shared"
external core_tick : unit -> bool = "core_tick"
(* the microseconds core [c] has waited with nothing to run
 * (wait_interrupt), their 30 low bits: 18 minutes before it turns
 * round, so two readings are subtracted and masked. The time a core
 * waits for the kernel's lock is not in it *)
external core_idle : int -> int = "core_idle"
(* both caches emptied at each change of process, as principia's 9pi
 * does (true): slower, and what to try when programs die with the
 * caches on and not with them off *)
external caches_careful : bool -> unit = "caches_careful"
(* the processor's speed in MHz, measured (its cycles during 10 ms): 700
 * on a Pi1 unless its config.txt overclocks it; 0 where cycles are not
 * counted (the emulators, the Pi4) *)
external cpu_mhz : unit -> int = "cpu_mhz"
(* the processor stopped until an interrupt is pending (wfi, ARM's
 * instruction wait for interrupt: nothing to do, no power spent),
 * IRQs masked: it is not taken, the caller looks at what came *)
external wait_interrupt : unit -> unit = "wait_interrupt"

(* The serial line: the simplest way a board talks, two wires, one
 * each way, a character at a time, each of its bits a level held for
 * a fixed time (so many bits a second: the bauds, 115200 here, which
 * the two ends must agree on, there being no wire for a clock). It is
 * the console of a board with no screen, a cable from three of the
 * board's pins to another computer's terminal, and what an emulator
 * shows in its own terminal.
 * The device that does it is a UART (universal asynchronous receiver
 * and transmitter: asynchronous is that absence of a clock): given a
 * byte in a register it sends its bits at the right pace, and it
 * gathers the bits that come into a byte to be read. PL011 is the
 * name of one design of UART, ARM's, the one in the Pi and in QEMU:
 * its name says which registers there are and what their bits mean.
 * A character out; one in, or -1 when none has come; its receive
 * interrupt on (the UART then asks for attention at each character,
 * where the kernel would have to keep looking). *)
external uart_putc : int -> unit = "uart_putc"
external uart_getc : unit -> int = "uart_getc"
external uart_rx_enable : unit -> unit = "uart_rx_enable"
(* the keys, the mouse and the cursor of a web page (the kernel built
 * for one, WEB=1: web/host.s; mini-9pi's Kweb and Swcursor): the next
 * report in 8 bytes (1 a keyboard's, 2 the mouse's, 0 none); the
 * cursor's 66 bytes given, 1 when the page draws it. 0 on a board. *)
external web_input : bytes -> int = "web_input"
external web_cursor : bytes -> int = "web_cursor"
external halt : unit -> unit = "machine_halt"
(* what the kernel says when it stops or is stuck, on the screen too,
 * over whatever is there (machine.c's lastwords: white on red lines
 * from the top, the kernel's font, the framebuffer's bytes, nothing
 * taken: it works when the rest is broken; nothing before fb_init).
 * [doing pid program what]: what this core runs, for the watchdog's
 * words (runtime.c: a core that waits 10 seconds for the kernel's lock
 * says who holds it, and what each core was doing) *)
external last_words : string -> unit = "last_words"
external doing : int -> string -> string -> unit = "doing"

(* the file system's image, linked in the kernel (a disk in memory):
 * its physical address, its size *)
(* the kernel's own memory (libc.c's malloc, which only goes up): how far
 * it has gone, and how far it may: the processes' pages are above *)
external heap_top : unit -> int = "heap_top"
external heap_limit : unit -> int = "heap_limit"
(* the end of the memory the firmware gives the ARM, the VideoCore's
 * own being above it (the card's config.txt: gpu_mem); 0 when the
 * board does not ask *)
external ram_top : unit -> int = "ram_top"
(* the end of the board's memory, the VideoCore's included (the 512 MB
 * a Pi 1 is sold with); 0 when the board does not ask *)
external ram_all : unit -> int = "ram_all"

(* The top 16 bits of where the RAM starts for a device that reads and
 * writes memory by itself (a DMA channel: its "bus" address): 0x4000
 * on the Pi 1, 0xc000 on the Pi 2 and the Pi 4. A driver adds it to a
 * physical address's own top half. The wrong one is not refused: on
 * the Pi 2 the Pi 1's reads the memory through a cache the processor
 * does not write through, and the device sees what the page held
 * before. *)
external bus_alias16 : unit -> int = "bus_alias16"
external fs_base : unit -> int = "fs_base"
external fs_size : unit -> int = "fs_size"

(* The framebuffer: the screen's pixels as memory, a row after
 * another, which the VideoCore sends to the display; the kernel asks
 * the firmware for one of a size and writes in it. [fb_init w h depth]
 * (depth: bits a pixel), its physical address (0: none); its pitch
 * (bytes a row, which may be more than the width's); the console's
 * font (start.s). *)
external fb_init : int -> int -> int -> int = "fb_init"
external fb_pitch : unit -> int = "fb_pitch"

(* The display's own size, before a framebuffer is asked: the mode the
 * firmware chose for the monitor plugged in (a monitor says which sizes
 * it shows, and the firmware takes its preferred one). The width in
 * the high 16 bits, the height in the low ones; 0 when it is not said.
 * A framebuffer of another size is stretched to it by the VideoCore:
 * the kernel draws in what it asked, the monitor shows it larger or
 * smaller, and blurred. The emulators say 640 by 480. *)
external display_size : unit -> int = "display_size"
external font_base : unit -> int = "font_base"

(* A clock's rate in Hz, as the firmware says it, 0 when it does not.
 * The board's devices each run from a clock (a signal that beats so
 * many times a second) that the VideoCore's firmware sets up before
 * the kernel starts, and may set differently on another board or in
 * another version: a driver that derives a speed from its device's
 * clock (the SD controller divides it to make the card's: Emmc; a
 * UART its bauds) asks for it, here. [id] is the firmware's number
 * for the clock: 1 the SD controller's (2 the UART's, 3 the ARM's).
 * On the Pi1, by the mailbox's property tags; the emulators answer 50
 * MHz for 1. *)
external clock_rate : int -> int = "clock_rate"
(* What the board says of its processor now, 0 when it does not (the
 * emulators, the Pi 4's kernel): [board_sense 0] the chip's temperature
 * in thousandths of a degree; 1 the ARM's clock as measured now, in Hz
 * (lowered by the firmware when the chip is hot or its power low); 2
 * the firmware's throttling bits (0 under-voltage, 1 the frequency
 * capped, 2 throttled, 3 the soft temperature limit; each 16 higher:
 * since the boot). *)
external board_sense : int -> int = "board_sense"

(* The board's revision, the firmware's number for which Pi this is
 * (0x900021 an A+, what the emulators say; 2 to 0xf the first Model
 * B's and A's), 0 when it does not say: what differs between two
 * boards of one family and cannot be asked of the device itself (which
 * of the jack's two pins is the left ear: mini-9pi's Devaudio). *)
external board_rev : unit -> int = "board_rev"

(* The board's Ethernet address, a byte at a time ([board_mac 0] the
 * first of its six), -1 when the firmware does not say. A Pi's
 * adapter has no memory for its address (a PC's card has an EEPROM):
 * the firmware makes it from the board's serial number, behind the
 * Raspberry Pi Foundation's three bytes (b8:27:eb), and the kernel
 * asks for it and tells the adapter (mini-9pi's Etherusb). *)
external board_mac : int -> int = "board_mac"

(* The firmware's revision, the second its files were built at (since
 * 1970; 346337 under the emulators), in two halves, a word of 32 bits
 * not fitting an int of 31: [firmware_rev 0] its low 16 bits,
 * [firmware_rev 1] its high ones. 0 when the firmware does not say. *)
external firmware_rev : int -> int = "firmware_rev"

(* [io_probe off]: is there a device at this register (an offset as
 * io_get16's)? False where a read of it faults: an emulator that has
 * no memory there (QEMU's raspi has no PWM), which without the
 * question is the kernel's end at the driver's first write (QEMU's
 * raspi4b has no RNG). No answer but a halt in the Pi 1's kernel by
 * ix's own tools (l1.s, l2.s), for now. *)
external io_probe : int -> bool = "io_probe"

(* A device's register, by its offset from the devices' base
 * (0x20000000 on the Pi1): what a driver in OCaml is made of (the SD
 * controller's, the USB's). [io_get16 off high] one 16-bit half of the
 * 32-bit word, [io_set32 off hi lo] the word written from its halves
 * (a word is past the Pi1's ints). A register is read and written
 * whole, as 32 bits and once: reading one may change the device. *)
external io_get16 : int -> bool -> int = "io_get16"
external io_set32 : int -> int -> int -> unit = "io_set32"
(* a data port (a register that gives the next word of a block at each
 * read, takes one at each write) read [n] bytes' worth (32-bit loads),
 * or written a string's words *)
external io_read_fifo : int -> int -> string = "io_read_fifo"
external io_write_fifo : int -> string -> unit = "io_write_fifo"

(* the console's output, as it is (no CR before a newline: xv6-riscv's) *)
val putc : char -> unit

(* the output's other way: the framebuffer's console (Screen), once
 * there is one *)
val screen : (char -> unit) ref
val print : string -> unit

(* the message, the machine stopped (xv6's panic): on the UART and on
 * the screen (last_words), not through screen, which may be what is
 * broken *)
val panic : string -> 'a

(* little-endian bytes, as C lays out a short and an int *)
val le16 : int -> string
val le32 : int -> string

(* [get_le32 s off]: a 32-bit word as C's int. On the Pi1 OCaml's int
 * has 31 bits: the words from -1GB to 1GB are exact; the others (as an
 * address, 1GB and up: none of a user's) come back as max_int, which
 * every bound refuses *)
val get_le32 : string -> int -> int
