(* TinyKernel's machine: what the kernel in ML reaches tiny-machine by,
 * the externals of entry.tm (a process run until its trap, the timer,
 * the interrupts), memory.tm (bytes copied, zeroed) and runtime.c (a
 * word read and written, strings to and from memory), and the devices'
 * addresses at the top of memory.
 *
 *     the kernel in ML   ──peek/poke──►   a device's words (-16: the last
 *                                         16 bytes, whatever the size)
 *                        ──k_run──────►   a process, until its trap: the
 *                                         cause (c_sys, c_fault...) back
 *
 * The first 32 MB are the kernel's (runtime.c says how): its image,
 * the processes' frames, the images it draws, the screen, its heap;
 * the processes' memory is above, TinyKernelMemory's. A device's
 * address is a negative number, which the machine takes modulo its
 * memory's size, so the kernel works whatever that size is.
 *
 * others:
 * Plan 9's kernel reaches its hardware the same way, a few functions in
 * assembly (each port's l.s) below C; here they are below ML, and the
 * devices are words at addresses.
 *)

(* entry.tm's: the machine set up; a process's frame run until its trap
 * (the cause back), one instruction of it; the trap's value; the timer
 * armed; the machine's clock *)
external k_init : unit -> unit = "k_init"
external k_run : int -> int = "k_run"
external k_step : int -> int = "k_step"
external k_tval : unit -> int = "k_tval"
external k_timer : int -> unit = "k_timer"
external k_clock : unit -> int = "k_clock"

(* memory.tm's and runtime.c's: n bytes copied, zeroed; where the image
 * ends; a word read, written; bytes as a string, a string into memory;
 * a character on the console; the font's address *)
external k_copy : int -> int -> int -> unit = "k_copy"
external k_zero : int -> int -> unit = "k_zero"
external k_end : unit -> int = "k_end"
external peek : int -> int = "peek"
external poke : int -> int -> unit = "poke"
external k_string : int -> int -> string = "k_string"
external k_blit : string -> int -> int -> int -> unit = "k_blit"
external k_console : int -> int -> unit = "k_console"
external k_font : unit -> int = "k_font"

(* how many processes at most, and a slot's frame, where entry.tm saves
 * its registers *)
val nslots : int
val frame : int -> int

(* the devices' addresses: the console's input, the mouse, the network
 * (its words, its packet's buffer), the speaker (its ring's place), the
 * disk, the date at the boot, the programs' random seed *)
val cons_in : int
val mouse_dev : int
val net_dev : int
val net_buf : int
val speaker_dev : int
val ring_at : int
val disk_dev : int
val date_dev : int
val seed_dev : int

(* the cores (plan_tiny_multicore.md): how many, the interrupt between
 * them, core k's mailbox *)
val cores : int
val ipi_dev : int
val mailbox : int -> int

(* the interrupts taken, the cores' too when there are several *)
val k_ie : int -> unit

(* a trap's causes: a system call, an illegal instruction, a fault, an
 * interrupt *)
val c_sys : int
val c_illegal : int
val c_fault : int
val c_intr : int

(* the timer's period: a 400th of a second of the machine's instructions *)
val tick : int

(* the kernel's own message on the console; the machine stopped with a
 * status (the disk's changes committed first) *)
val puts : string -> unit
val halt : int -> unit
