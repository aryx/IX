(* mini-singularity: the software-isolated processes (decisions 2 and 6
 * of plan_system_singularity.md). A program is known when the image is
 * made: linked at its own address with its own run-time system and
 * heap, kept in the kernel's image as a pristine copy (Programs: the
 * mkfile's PROGRAMS). A process is a program started: the copy put at
 * the address it was linked for and called, on a stack at its slot's
 * end; no page table is made or switched. One instance of a program at
 * a time, one thread a process for now.
 *
 * Cooperative: a process runs until it calls the kernel (Abi) to
 * yield, to wait for another, or to end. In the kernel it has a stack
 * of its own (machine/runtime.c's slots, mini-xv6's), so that a call
 * may wait while others run.
 *
 * What a process holds of the kernel is a handle: a small number, an
 * index in its own table; no other process's handle means anything to
 * it. *)

(* [create parent name]: a process of the program of that name, not yet
 * started; parent is the running process, or the kernel (false: nobody
 * waits for it, its end is said on the console). Its handle in the
 * parent's table (the kernel's: its number), or -1: no program of
 * that name, one already running, no room *)
val create : bool -> string -> int
(* a handle of the running process (the kernel: a number): started; -1 for a wrong handle *)
val start : bool -> int -> int
(* the running process waits for the end of its handle's: its status,
 * the handle free again; -1 for a wrong handle *)
val join : int -> int
(* the running process lets the others run *)
val yield : unit -> unit
(* the running process ends: its status. Its call returns into the
 * kernel only *)
val exit : int -> unit

(* the kernel's loop: the processes that can run, each in its turn,
 * until none can *)
val schedule : unit -> unit
