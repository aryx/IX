(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelMachine.mli *)
open TinyMemory
open TinyKernelFS

(*****************************************************************************)
(* The machine: entry.tm's, memory.tm's and runtime.c's functions *)
(*****************************************************************************)

external k_init : unit -> unit = "k_init"
external k_run : int -> int = "k_run"
external k_step : int -> int = "k_step"
external k_tval : unit -> int = "k_tval"
external k_timer : int -> unit = "k_timer"
external k_ie : int -> unit = "k_ie"
external k_clock : unit -> int = "k_clock"
external k_rate : unit -> int = "k_rate"
external k_cores : unit -> int = "k_cores"
external k_window : int -> int -> int -> int -> int -> unit = "k_window"
external k_copy : int -> int -> int -> unit = "k_copy"
external k_zero : int -> int -> unit = "k_zero"
external k_end : unit -> int = "k_end"
external peek : int -> int = "peek"
external poke : int -> int -> unit = "poke"
external k_string : int -> int -> string = "k_string"
external k_blit : string -> int -> int -> int -> unit = "k_blit"
external k_console : int -> int -> unit = "k_console"
external k_font : unit -> int = "k_font"

(* The memory. The first 32 MB are the kernel's (runtime.c says how they
 * are used): its image, the processes' frames, the images it draws, the
 * screen, its heap. The processes' memory is above, TinyKernelMemory's:
 * a partition of the size a program asks for (1 MB if it does not say),
 * found when it starts. There are at most [nslots] processes; a slot is
 * a process's frame. (old: 8 slots and 128 MB, before the cores:
 * tiny-build -j 4 runs four rc and four compilers of 32 MB) *)
let nslots = 16
let frame slot = 0xb40000 + (slot * 68)
(* The devices are at the top of memory. Their addresses are written as
 * negative numbers, which the machine takes modulo its memory size, so
 * the kernel works whatever that size is (-16 is the last 16 bytes). *)
let cons_out = -16
let halt_dev = -12
let cons_in = -8
let mouse_dev = -4
(* the network's four words (an address, a length, a command, whether
 * there is a wire), and a packet's place in memory, after the frames *)
let net_dev = -48
let net_buf = 0xb50000
(* the speaker's word (its ring's address written, the samples played
 * read), and its ring, in the megabytes nothing else uses *)
let speaker_dev = -52
let ring_at = 0xc00000
(* the disk's four words: a block, an address, a command, a status; the
 * first, read, is the disk's size in blocks (0: no disk) *)
let disk_dev = -32
(* the date at the boot, seconds since 2000-01-01 (the machine's) *)
let date_dev = -56
(* the seed, for the programs' first random numbers (the machine's;
 * 0: none) *)
let seed_dev = -60
(* The cores (plan_tiny_multicore.md): the kernel is core 0's, the
 * others run processes only (entry.tm's slave). Core k's mailbox: the
 * frame to run (0: none), the window (base, size), the slice; then
 * the trap's cause and value, posted. The interrupt between cores:
 * core k's raised by storing k at -64(r0); read, the cores that raised
 * this one's. *)
let cores = k_cores ()
let ipi_dev = -64
let mailbox k = 0xb41000 + (64 * k)
(* the interrupts taken, the cores' always when there are several *)
let k_ie sources = k_ie (if cores > 1 then sources lor 32 else sources)

(* a trap's causes (TinyMachine.ml's), the timer's period *)
let c_sys = 1
let c_illegal = 2
let c_fault = 3
let c_intr = 4
(* The timer's period is 2.5 ms of the machine's time, whatever its
 * speed: 20,000 instructions at 8 million a second. The programs count
 * time in these ticks (a game's frames, IL's waits, ping), so they run
 * at the same pace on a faster machine. *)
let tick = let r = k_rate () in if r < 400 then 20000 else r / 400

let puts s =
  for i = 0 to String.length s - 1 do pokeb cons_out (Char.code s.[i]) done
(* (what the disk has not been told yet is told first) *)
let halt status = fs_commit (); poke halt_dev status
