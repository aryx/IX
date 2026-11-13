(* mini-xv6's machine, as the board's machine.c and runtime.c give it,
 * with the same names on the Pi1 and the Pi4. Addresses are ints. A
 * user's address and a physical one fit in OCaml's int (31 bits on the
 * Pi1, so they are below 1GB; 63 on the Pi4), and the kernel's own
 * addresses never reach OCaml (plan_kernel.md, decision 3;
 * kernels/steps/step4).
 *
 * For a reader who knows OCaml and not the hardware, what is under
 * these names:
 *
 *   a program's address ---- the MMU, by the process's table ---> a
 *   (virtual: what its                                            physical
 *   pointers hold)                                                address
 *
 *   physical addresses are the RAM from 0 and, far above it, the
 *   devices' registers (a register is a word that is not memory:
 *   writing it tells a device to do something, reading it asks what
 *   the device has)
 *
 * The kernel reaches both through the functions here, in C and
 * assembly underneath: OCaml has no pointers, and what a register
 * means is the device's affair, not the language's. Four things then
 * come up again and again:
 * - the MMU (memory management unit) is the part of the processor that
 *   does the translation drawn above, at every access, which is what
 *   keeps a program in its own memory;
 * - a trap is the processor leaving the user's program for the kernel,
 *   at a system call, a fault or an interrupt (a device asking for
 *   attention; IRQ, interrupt request, is the wire it asks by and the
 *   name of the event). The program's registers are saved, to be given
 *   back;
 * - time: a device is slower than the processor, and a driver waits
 *   for it (by the timer below);
 * - the firmware: the Pi's other processor (the VideoCore, its GPU or
 *   graphics processor, which on this board is also the master) starts
 *   first, sets the board up, loads the kernel, and stays there to be
 *   asked for things (the framebuffer, a clock's rate) through a pair
 *   of registers called the mailbox.
 *
 * Where it stands. Every kernel of this tree is OCaml above this
 * interface and C and assembly below it, and links the same file
 * (mini-oberon, mini-singularity and mini-squeak link it by a symbolic
 * link in their machine/ directory):
 *
 *     mini-xv6   mini-9pi   mini-oberon   mini-singularity   ...
 *     ------------------------- Machine --------------------------
 *     machine.c, start.s, board.h (pi1/, pi4/)   the board
 *     runtime.c, shim.c, libc.c     what OCaml's runtime asks of
 *                                   a system, there being none
 *
 * A kernel that has no processes uses a third of it (mini-oberon uses
 * the framebuffer, the timer and the UART); the trap frame and the
 * MMU's functions are for the kernels that run user programs. What the
 * emulators of this tree implement (mini-qemu's Board and its devices)
 * is the other side of the same registers.
 *
 * design:
 * An address is an int, and a register is accessed by a function:
 * there is no pointer type, and no record laid over memory. It is the
 * least a typed language needs to write a kernel, and it keeps the
 * unsafe part countable, since the externals below are all of it.
 * Other kernels in safe languages make the same cut with more types on
 * it (a typed view of a device's registers in Singularity and in
 * Rust's embedded crates). Oberon's own kernel has a pseudo-module,
 * SYSTEM, whose import marks a module as unsafe.
 *
 * References: "BCM2835 ARM Peripherals" (Broadcom, 2012), which gives
 * the Pi1's devices register by register (with known errors, whose
 * errata are kept at elinux.org); the "PrimeCell UART (PL011)
 * Technical Reference Manual" (ARM); the Raspberry Pi firmware's wiki,
 * "Mailbox property interface", for the tags asked of the VideoCore.
 * notes_kernel.md, the tutorial, on what OCaml's runtime needs with no
 * system under it. *)

(* Physical memory, by physical address: a page of a process, a page
 * table, a device's buffer. The kernel's own data is in OCaml's
 * values; this is the memory it manages for others, which no OCaml
 * value is in. get and set read and write one, two or four bytes (the
 * lowest byte first). *)
module Phys : sig
  external get8 : int -> int = "phys_get8"
  external set8 : int -> int -> unit = "phys_set8"
  external get16 : int -> int = "phys_get16"
  external set16 : int -> int -> unit = "phys_set16"
  external get32 : int -> int = "phys_get32"
  external set32 : int -> int -> unit = "phys_set32"
  (* [zero pa n] zeroes n bytes; n must be a multiple of 4 *)
  external zero : int -> int -> unit = "phys_zero"
  (* [copy dst src n], [write pa s], [read pa n] *)
  external copy : int -> int -> int -> unit = "phys_copy"
  external write : int -> string -> unit = "phys_write"
  (* [write_sub pa s off n] writes s's n bytes from off, without a
   * String.sub *)
  external write_sub : int -> string -> int -> int -> unit = "phys_write_sub"
  external read : int -> int -> string = "phys_read"
  (* [sync pa n] is for n bytes that a process wrote at pa and will
   * run: it puts them in memory, and takes them out of the
   * instructions' cache (segflush) *)
  external sync : int -> int -> unit = "phys_sync"
end

(* The images' memory, outside OCaml's heap (runtime.c says why:
 * principia's imagmem, and pixels copied while another core is in the
 * kernel).
 * - [init pa n] sets its arena: n bytes of physical memory at pa.
 * - [alloc n] gives n zeroed bytes there, which neither collector moves
 *   or looks at, and which are a Bytes.t like any other to read and
 *   write. It gives a Bytes.t of length 0 when there is no room (when
 *   n > 0, the caller then takes Bytes.make).
 * - [free b] gives them back (it does nothing for bytes of the heap).
 * - [used ()] gives the bytes taken, out of [size ()].
 * The copies below each give the kernel's lock back when what they
 * read and write is in the arena and is large:
 * - [copy dst src [| da; dbw; sa; sbw; n; dy; up |]] copies dy rows of
 *   n bytes, from sa in src every sbw to da in dst every dbw, the last
 *   row first when up is not 0;
 * - [rows b a0 bw len dy] repeats the len bytes at a0 in the dy - 1
 *   rows below, bw apart;
 * - [scale dst src [| da; dbw; sa; sbw; bpp; k; px; py; w; h |]] writes
 *   each of src's pixels of bpp bytes k by k into dst's w by h pixels
 *   from da; the first of those pixels is px columns and py rows into
 *   its source pixel's k by k (an ix extension of the draw device:
 *   Memdraw.scale);
 * - [flush b [| pa; pitch; off; bw; n; rows |]] copies rows of n bytes
 *   from off in b every bw, to physical memory at pa every pitch (the
 *   framebuffer).
 * Then there is what such a copy must not meet (runtime.c):
 * - [screen b] says which image is the screen's;
 * - [covers lo hi] says whether a copy is writing the screen's bytes
 *   lo to hi now (the cursor's clock then leaves them alone);
 * - [quiet ()] waits until no copy is under way, before an image is
 *   freed and before a window is made, moved, restacked or deleted;
 * - [switch n] says which copies give the lock back: 1 for a copy, 2
 *   for a fill, 4 for a flush (7 at the start; 0 for none, so that
 *   every copy holds the lock). *)
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

(* The trap frame holds the user's registers as they were when its
 * program was left for the kernel (the general registers, where the
 * program was, and its flags). The assembly saves them at the trap and
 * loads them back at the return. A system call's arguments are read
 * there and its result is written there, and a new process is given a
 * made-up one. Each process (a slot) has its own; these functions
 * access the running process's, by word (Arch gives the layout, which
 * is the board's). *)
external tf_get : int -> int = "tf_get"
external tf_set : int -> int -> unit = "tf_set"
(* sets a slot's trap frame to zeros, in user mode, with IRQs on *)
external tf_init : int -> unit = "tf_init"
(* copies the running process's trap frame to a slot's, with the first
 * register set to 0 (for fork's child) *)
external tf_copy : int -> unit = "tf_copy"
(* the running process's trap frame as bytes, whole: a word for each
 * register, in the board's layout. The registers keep their 32 bits
 * this way, and mini-9pi's notes save and restore them. *)
external tf_bytes : unit -> string = "tf_bytes"
external tf_set_bytes : string -> unit = "tf_set_bytes"
(* a slot's trap frame, whole: a stopped process's, for its debugger
 * (/proc/n/regs) *)
external tf_slot_bytes : int -> string = "tf_slot_bytes"
external tf_slot_set_bytes : int -> string -> unit = "tf_slot_set_bytes"

(* A process in the kernel has a stack of its own there (the kernel's
 * calls made for it, among them the one that waits), and going from
 * one process to another is changing stacks: the registers a function
 * must keep are saved on the one left and loaded from the other, and
 * the call returns in the other process, where it had called swtch
 * itself some time before. *)
(* [proc_context] makes a slot's kernel stack fresh, so that the first
 * switch to it enters "process_start"; [proc_free] frees a slot (the
 * collector no longer scans it) *)
external proc_context : int -> unit = "proc_context"
external proc_free : int -> unit = "proc_free"
(* [swtch] switches to a slot (a process's, or nproc for the
 * scheduler's); [current] gives the running one *)
external swtch : int -> unit = "k_swtch"
external current : unit -> int = "k_current"
(* goes back to user mode, from the running process's trap frame *)
external user_resume : unit -> unit = "user_resume"

(* The MMU translates each address a program uses by a table the
 * kernel wrote, the process's; the processor has a register that says
 * which table (TTBR0, translation table base register 0), and keeps
 * the translations it has done so as not to read the table each time
 * (the TLB, translation lookaside buffer), which are another
 * process's once the table changes: they are thrown away (flushed).
 * [mmu_switch pa] puts the user's table in TTBR0 (0 for the empty
 * one) and flushes the TLB. *)
external mmu_switch : int -> unit = "mmu_switch"

(* The system timer: a counter of microseconds that the board runs,
 * and an alarm on it. [timer_arm us] asks for an interrupt in [us]
 * microseconds, the kernel's tick; [timer_pending] says the alarm has
 * rung. An interrupt is only taken when the processor lets it (in
 * user mode here), so the kernel also looks. *)
external timer_arm : int -> unit = "timer_arm"
external timer_pending : unit -> bool = "timer_pending"
(* the counter, its 30 low bits. It gives the time when ticks were
 * missed, and it times a driver's waits (a device is given the time it
 * asks for). *)
external timer_now : unit -> int = "timer_now"
(* turns the processor's caches on. Memory is many times slower than
 * the processor; a cache is a small fast copy of the memory last used,
 * without which every instruction would wait for the memory. What is
 * in the cache and not yet in the memory is not seen by a device that
 * reads the memory itself: pi1/machine.c says what that asks of the
 * rest (elsewhere, it asks nothing). *)
external caches_on : unit -> unit = "caches_on"

(* starts the board's other cores and leaves them idle (the Pi 2:
 * plan_multicore.md, stage 2). It returns how many cores are up, this
 * one counted. When a core did not come up, it returns that core's
 * number plus 16 times how far its start went (pi1's machine.c). *)
external cores_start : unit -> int = "cores_start"

(* Several cores (plan_multicore.md), where the board has them and the
 * kernel is built for them; elsewhere there is one core, 0, and these
 * do nothing. The kernel has one lock. A core takes it where it enters
 * the kernel (a trap, an interrupt) and gives it back where it leaves
 * (to user mode, or in wait_interrupt), so one core at a time runs
 * what is above this interface, which needs no lock of its own. What a
 * kernel must know is less: a process may go on while the kernel runs
 * for another, [current] and the trap frame are this core's, and the
 * devices' interrupts and the clock go to the first core (the others
 * have a tick of their own, for a process's slice).
 * - [cores_run n]: from now on, the [n] cores started each run the
 *   function registered as "scheduler" (the first core is the caller,
 *   which goes on to call its own);
 * - [cores_test ()] says to do so under an emulator too (SMP=1 at the
 *   build);
 * - [cores_wake ()] says a process was made ready, so a core that waits
 *   looks;
 * - [core ()] gives this core's number;
 * - [core_tick ()], in an interrupt of a core other than the first,
 *   says whether it was the core's timer (which is then armed again) *)
external cores_run : int -> unit = "cores_run"
external cores_test : unit -> bool = "cores_test"
external cores_wake : unit -> unit = "cores_wake"
external core : unit -> int = "k_core"
(* whether a page's entry must say that several cores share the page
 * (used by the Pi 1's and the Pi 2's Arch; it is true on the Pi 2) *)
external pages_shared : unit -> bool = "pages_shared"
external core_tick : unit -> bool = "core_tick"
(* the microseconds core [c] has waited with nothing to run (in
 * wait_interrupt), as their 30 low bits. They turn round after 18
 * minutes, so two readings are subtracted and masked. The time a core
 * waits for the kernel's lock is not counted. *)
external core_idle : int -> int = "core_idle"
(* with true, both caches are emptied at each change of process, as
 * principia's 9pi does. It is slower, and it is what to try when
 * programs die with the caches on and not with them off. *)
external caches_careful : bool -> unit = "caches_careful"
(* the processor's speed in MHz, measured by its cycles during 10 ms:
 * 700 on a Pi1 unless its config.txt overclocks it, and 0 where cycles
 * are not counted (the emulators, the Pi4) *)
external cpu_mhz : unit -> int = "cpu_mhz"
(* stops the processor until an interrupt is pending (wfi, ARM's
 * instruction "wait for interrupt": there is nothing to do, and no
 * power is spent). IRQs stay masked, so the interrupt is not taken,
 * and the caller looks at what came. *)
external wait_interrupt : unit -> unit = "wait_interrupt"

(* The serial line is the simplest way a board talks: two wires, one
 * each way, carry a character at a time, and each of its bits is a
 * level held for a fixed time. The ends send so many bits a second
 * (the bauds, 115200 here), and they must agree on that number, since
 * there is no wire for a clock. It is the console of a board with no
 * screen, through a cable from three of the board's pins to another
 * computer's terminal, and it is what an emulator shows in its own
 * terminal.
 * The device that does it is a UART (universal asynchronous receiver
 * and transmitter; asynchronous means that there is no clock). Given a
 * byte in a register, it sends its bits at the right pace, and it
 * gathers the bits that come in into a byte to be read. PL011 is the
 * name of one design of UART, ARM's, the one in the Pi and in QEMU:
 * the name says which registers there are and what their bits mean.
 * [uart_putc] sends a character out; [uart_getc] reads one in, or
 * gives -1 when none has come; [uart_rx_enable] turns the receive
 * interrupt on (the UART then asks for attention at each character,
 * where otherwise the kernel would have to keep looking). *)
external uart_putc : int -> unit = "uart_putc"
external uart_getc : unit -> int = "uart_getc"
external uart_rx_enable : unit -> unit = "uart_rx_enable"
(* the keys, the mouse and the cursor of a web page, for the kernel
 * built for one (WEB=1: web/host.s; mini-9pi's Kweb and Swcursor).
 * [web_input] gives the next report in 8 bytes, and returns 1 for a
 * keyboard's, 2 for the mouse's, or 0 for none. [web_cursor] is given
 * the cursor's 66 bytes, and returns 1 when the page draws it. Both
 * return 0 on a board. *)
external web_input : bytes -> int = "web_input"
external web_cursor : bytes -> int = "web_cursor"
external halt : unit -> unit = "machine_halt"
(* [last_words] shows what the kernel says when it stops or is stuck,
 * on the screen too, over whatever is there (machine.c's lastwords
 * draws white on red lines from the top, in the kernel's font, into
 * the framebuffer's bytes; it takes nothing, so it works when the rest
 * is broken; it does nothing before fb_init). [doing pid program what]
 * records what this core runs, for the watchdog's words (in runtime.c,
 * a core that waits 10 seconds for the kernel's lock says who holds
 * it, and what each core was doing). *)
external last_words : string -> unit = "last_words"
external doing : int -> string -> string -> unit = "doing"

(* the kernel's own memory (libc.c's malloc, which only goes up): how
 * far it has gone, and how far it may go, since the processes' pages
 * are above it *)
external heap_top : unit -> int = "heap_top"
external heap_limit : unit -> int = "heap_limit"
(* the end of the memory the firmware gives the ARM; the VideoCore's
 * own memory is above it (set by the card's config.txt: gpu_mem). It
 * is 0 when the board does not ask. *)
external ram_top : unit -> int = "ram_top"
(* the end of the board's memory, the VideoCore's included (the 512 MB
 * a Pi 1 is sold with); 0 when the board does not ask *)
external ram_all : unit -> int = "ram_all"

(* The top 16 bits of where the RAM starts for a device that reads and
 * writes memory by itself (a DMA channel, whose address is a "bus"
 * address): 0x4000 on the Pi 1, 0xc000 on the Pi 2 and the Pi 4. A
 * driver adds it to the top half of a physical address. The wrong
 * value is not refused: on the Pi 2, the Pi 1's value reads the memory
 * through a cache that the processor does not write through, and the
 * device sees what the page held before. *)
external bus_alias16 : unit -> int = "bus_alias16"
(* the file system's image, linked in the kernel (a disk in memory):
 * its physical address and its size *)
external fs_base : unit -> int = "fs_base"
external fs_size : unit -> int = "fs_size"

(* The framebuffer is the screen's pixels as memory, a row after
 * another, which the VideoCore sends to the display; the kernel asks
 * the firmware for one of a size and writes in it. [fb_init w h depth]
 * (depth is the bits of a pixel) returns its physical address (0 when
 * there is none); [fb_pitch] gives its pitch (the bytes of a row,
 * which may be more than the width needs); [font_base] gives the
 * console's font (start.s). *)
external fb_init : int -> int -> int -> int = "fb_init"
external fb_pitch : unit -> int = "fb_pitch"

(* The display's own size, before a framebuffer is asked: the mode the
 * firmware chose for the monitor plugged in (a monitor says which sizes
 * it shows, and the firmware takes its preferred one). The width is in
 * the high 16 bits and the height in the low ones; it is 0 when the
 * size is not said.
 * A framebuffer of another size is stretched to it by the VideoCore:
 * the kernel draws in what it asked, the monitor shows it larger or
 * smaller, and blurred. The emulators say 640 by 480. *)
external display_size : unit -> int = "display_size"
external font_base : unit -> int = "font_base"

(* A clock's rate in Hz, as the firmware says it, or 0 when it does not.
 * Each of the board's devices runs from a clock (a signal that beats
 * so many times a second) that the VideoCore's firmware sets up before
 * the kernel starts, and may set differently on another board or in
 * another version. A driver that derives a speed from its device's
 * clock asks for the clock's rate here (the SD controller divides it
 * to make the card's clock, in Emmc, and a UART divides it for its
 * bauds). [id] is the firmware's number for the clock: 1 is the SD
 * controller's (2 the UART's, 3 the ARM's). On the Pi1 the rate is
 * asked by the mailbox's property tags; the emulators answer 50 MHz
 * for 1. *)
external clock_rate : int -> int = "clock_rate"
(* What the board says of its processor now, or 0 when it does not say
 * (the emulators, the Pi 4's kernel):
 * - [board_sense 0] is the chip's temperature in thousandths of a
 *   degree;
 * - 1 is the ARM's clock as measured now, in Hz (the firmware lowers it
 *   when the chip is hot or its power low);
 * - 2 is the firmware's throttling bits (bit 0 for under-voltage, 1 for
 *   the frequency capped, 2 for throttled, 3 for the soft temperature
 *   limit; each bit 16 higher says the same since the boot). *)
external board_sense : int -> int = "board_sense"

(* The board's revision, the firmware's number for which Pi this is
 * (0x900021 is an A+, which the emulators say; 2 to 0xf are the first
 * Model B's and A's), or 0 when it does not say. It tells what differs
 * between two boards of one family and cannot be asked of the device
 * itself (such as which of the jack's two pins is the left ear, for
 * mini-9pi's Devaudio). *)
external board_rev : unit -> int = "board_rev"

(* The board's Ethernet address, a byte at a time ([board_mac 0] is the
 * first of its six), or -1 when the firmware does not say. A Pi's
 * adapter has no memory for its address (a PC's card has an EEPROM).
 * The firmware makes the address from the board's serial number,
 * behind the Raspberry Pi Foundation's three bytes (b8:27:eb), and the
 * kernel asks for it and tells the adapter (mini-9pi's Etherusb). *)
external board_mac : int -> int = "board_mac"

(* The firmware's revision: the second its files were built at (since
 * 1970; 346337 under the emulators). It comes in two halves, because a
 * word of 32 bits does not fit in an int of 31: [firmware_rev 0] gives
 * its low 16 bits, and [firmware_rev 1] its high ones. It is 0 when
 * the firmware does not say. *)
external firmware_rev : int -> int = "firmware_rev"

(* [io_probe off] says whether there is a device at this register (an
 * offset, as for io_get16). It is false where a read of the register
 * faults, in an emulator that has no memory there (QEMU's raspi has no
 * PWM); without the question, that fault ends the kernel at the
 * driver's first write (QEMU's raspi4b has no RNG). For now, in the
 * Pi 1's kernel built by ix's own tools (l1.s, l2.s), there is no
 * answer but a halt. *)
external io_probe : int -> bool = "io_probe"

(* A device's register, by its offset from the devices' base
 * (0x20000000 on the Pi1). Registers are what a driver in OCaml is
 * made of (the SD controller's, the USB's). [io_get16 off high] reads
 * one 16-bit half of the 32-bit word, and [io_set32 off hi lo] writes
 * the word from its halves (a word does not fit in the Pi1's ints). A
 * register is read and written whole, as 32 bits and once, because
 * reading one may change the device. *)
external io_get16 : int -> bool -> int = "io_get16"
external io_set32 : int -> int -> int -> unit = "io_set32"
(* a data port is a register that gives the next word of a block at
 * each read, and takes one at each write. [io_read_fifo] reads [n]
 * bytes' worth from it (by 32-bit loads), and [io_write_fifo] writes a
 * string's words to it. *)
external io_read_fifo : int -> int -> string = "io_read_fifo"
external io_write_fifo : int -> string -> unit = "io_write_fifo"

(* writes to the console's output, as it is (with no CR before a
 * newline, as xv6-riscv does) *)
val putc : char -> unit

(* the output's other way: the framebuffer's console (Screen), once
 * there is one *)
val screen : (char -> unit) ref
val print : string -> unit

(* prints the message and stops the machine (xv6's panic). It writes on
 * the UART and on the screen (by last_words), not through screen,
 * which may be what is broken. *)
val panic : string -> 'a

(* little-endian bytes, as C lays out a short and an int *)
val le16 : int -> string
val le32 : int -> string

(* [get_le32 s off] reads a 32-bit word as C's int. On the Pi1, OCaml's
 * int has 31 bits: the words from -1GB to 1GB are exact, and the
 * others (as an address, 1GB and up, which is none of a user's) come
 * back as max_int, which every bound refuses. *)
val get_le32 : string -> int -> int
