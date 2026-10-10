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
 * it. A child, a channel's endpoint, a block of the exchange heap; and
 * what its program's manifest asks of the machine, given at its start
 * (Programs.grants: its first handles): a device's registers, an
 * interrupt.
 *
 * A process's start and a call of the kernel, with what a hardware
 * process would do at the same steps:
 *
 *     start hello     the pristine copy's bytes copied to the
 *                     address the program was linked for, its slot
 *                     of 16 MB; a call into it, on a stack at the
 *                     slot's end. (An address space made, the
 *                     program's file mapped, a return to user mode:
 *                     mini-xv6's Exec.)
 *     Sip.yield ()    a call of abi_entry, whose address the program
 *                     was given: two registers saved and set (the
 *                     program's static base and its value stack),
 *                     the stack changed for the process's kernel
 *                     one. (A trap: the mode changed, every register
 *                     saved, and at the switch the table changed and
 *                     the TLB flushed.)
 *     exit, or an     its handles are let go one by one: endpoints
 *     exception       closed, blocks freed; its children are
 *     escaping        nobody's. Its memory needs no freeing: the
 *                     next start copies over it. The slot is free
 *                     once its parent has joined it.
 *
 * The pristine copy is why a program can be run again: a process
 * changes its own data, and there is no file to read it from anew.
 * That each program is linked at its own address is why there is
 * one process of a program at a time (no relocation in mini-ld).
 *
 * terminology:
 * SIP, software-isolated process: Singularity's word, against the
 * hardware-isolated process of every other system. Sealed: once
 * started, a SIP's code does not change, nothing is loaded into it
 * and no memory is shared with it; an extension is another SIP and
 * a channel. Closed, as opposed to the open process of Unix or
 * Windows that libraries, plug-ins and debuggers write into.
 *
 * design:
 * A handle is a capability: the kernel's reference to a thing, held
 * in a table of the process's, named by its index there. A process
 * cannot forge one (a number that is not in its table is -2) and
 * can only get one by being given it, by its parent, its manifest
 * or a message. Unix's file descriptors are the same idea kept for
 * files only; here it is everything a process has, there being no
 * file names, no pids and no addresses to reach around it.
 *
 * others:
 * mini-xv6's Proc is the same table of 64 over the same C slots
 * (runtime.c), with what this one lacks: a page table each, the
 * timer taking the processor back. Preemption is not against the
 * model (Singularity has it); it needs the collector to know where
 * a process may be stopped, which cooperative switching gives for
 * free.
 *
 * References: Hunt and Larus (2007), on SIPs and their cost (table
 * 1); Hunt and others, "Sealing OS Processes to Improve
 * Dependability and Safety" (EuroSys 2007). Dennis and Van Horn,
 * "Programming Semantics for Multiprogrammed Computations"
 * (Communications of the ACM, 1966): where capabilities come from.
 * cross.c, for what a crossing keeps and why no more. *)

type held =
  | Nothing
  | Child of int
  | Endpoint of Channel.endpoint
  | Block of Exchange.block
  | Registers of int * int              (* a device's: where among the peripherals', how many bytes *)
  | Interrupt of int

(* a process's number: its slot; the running one's program's name *)
val running : unit -> int
val name : unit -> string
(* the running process's: what a handle is (Nothing for a number that
 * is none); a new handle, or -1 for no room; a handle no longer one *)
val handle : int -> held
val hold : held -> int
val drop : int -> unit

(* [create parent name]: a process of the program of that name, not yet
 * started; parent is the running process, or the kernel (false: nobody
 * waits for it, its end is said on the console). Its handle in the
 * parent's table (the kernel's: its number), or -1: no program of
 * that name, one already running, no room *)
val create : bool -> string -> int
(* a handle of the running process (the kernel: a number): started; -2 for a wrong handle *)
val start : bool -> int -> int
(* the running process's endpoint given to its child not yet started,
 * whose handle it becomes: the child's handle; -1 if started, or no
 * room; -2 for a wrong handle *)
val give : int -> int -> int
(* the running process waits for the end of its handle's: its status (0
 * to 255), the handle free again; -2 for a wrong handle *)
val join : int -> int
(* the running process waits until woken; a waiting process may run
 * again (it looks again at what it waited for) *)
val wait : unit -> unit
val wake : int -> unit
(* the running process waits for an interrupt: it runs again when one
 * has come and nothing else can run, and looks at its device *)
val sleep : unit -> unit
(* the running process's child is ended, with 255; -2 for a wrong handle *)
val stop : int -> int
(* the processes, a line each (its number, its program, its state), or
 * the image's programs *)
val listing : bool -> string
(* the running process lets the others run *)
val yield : unit -> unit
(* the running process ends: its status. Its call returns into the
 * kernel only *)
val exit : int -> unit

(* the kernel's loop: the processes that can run, each in its turn,
 * until none can *)
val schedule : unit -> unit
