(* TinyKernel's machine: how the kernel, written in ML, reaches
 * tiny-machine. It is made of the externals of three files:
 * - kentry.s runs a process until it traps, and handles the timer and
 *   the interrupts;
 * - kcopy.s copies and zeroes bytes;
 * - kruntime.c reads and writes words, and moves strings to and from
 *   memory.
 * It also gives the addresses of the devices, at the top of memory.
 *
 *     the kernel in ML   ──peek/poke──►   a device's words (-16 is the
 *                                         last 16 bytes, whatever the size)
 *                        ──k_run──────►   a process runs until its trap;
 *                                         the cause (Trap_sys, Trap_fault...)
 *                                         comes back
 *
 * The first 32 MB belong to the kernel (kruntime.c explains how they
 * are used): its image, the processes' frames, the images it draws in,
 * the screen, and its heap. The processes' memory is above, managed by
 * KMemory. A device's address is a negative number, which the machine
 * takes modulo its memory size, so the kernel works whatever that
 * size is.
 *
 * others:
 * Plan 9's kernel reaches its hardware the same way, through a few
 * functions in assembly (each port's l.s) below the C code. Here they
 * are below ML, and the devices are words at fixed addresses.
 *)

(* From kentry.s. k_run runs a process's frame until a trap and returns
 * the cause; k_step runs one instruction. *)
external k_init : unit -> unit = "k_init"
external k_run : int -> int = "k_run"
external k_step : int -> int = "k_step"
external k_tval : unit -> int = "k_tval"
external k_timer : int -> unit = "k_timer"
external k_clock : unit -> int = "k_clock"

(* From kcopy.s and kruntime.c. k_end is where the kernel's image ends. *)
external k_copy : int -> int -> int -> unit = "k_copy"
external k_zero : int -> int -> unit = "k_zero"
external k_end : unit -> int = "k_end"
external peek : int -> int = "peek"
external poke : int -> int -> unit = "poke"
external k_string : int -> int -> string = "k_string"
external k_blit : string -> int -> int -> int -> unit = "k_blit"
external k_console : int -> int -> unit = "k_console"
external k_font : unit -> int = "k_font"
external k_font_size : unit -> int = "k_font_size"

(* [frame slot] is where kentry.s saves the slot's registers. *)
val nslots : int
val frame : int -> int

(* The devices' addresses. net_buf holds a packet, ring_at is the
 * speaker's position in its ring, date_dev holds the date at boot. *)
val cons_in : int
val mouse_dev : int
val net_dev : int
val net_buf : int
val speaker_dev : int
val ring_at : int
val disk_dev : int
val disk2_dev : int
val date_dev : int
val seed_dev : int

(* The cores (plan_tiny_multicore.md); ipi_dev interrupts another core. *)
val cores : int
val ipi_dev : int
val mailbox : int -> int

(* Chooses which interrupts are taken; with several cores, ipi is
 * added. *)
val k_ie : int -> unit

(* [cause_of n] decodes the number k_run, k_step or a mailbox gives; it
 * is read once. [cause_code] gives the number back, for a message. *)
type cause = Trap_sys | Trap_illegal | Trap_fault | Trap_intr
val cause_of : int -> cause
val cause_code : cause -> int

(* The timer's period is a 400th of a second, counted in machine
 * instructions. *)
val tick : int

(* [halt status] commits the disk's changes, then stops the machine. *)
val puts : string -> unit
val halt : int -> unit
