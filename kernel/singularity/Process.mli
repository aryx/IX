(* mini-singularity: a software-isolated process (decision 2 of
 * plan_system_singularity.md). A program is known when the image is
 * made: linked at its own address with its own run-time system and
 * heap, kept in the kernel's image as a pristine copy (the mkfile's
 * PROGRAMS, by their order there). Started, the copy is put at the
 * address it was linked for and called: no page table is made or
 * switched. One instance of a program at a time; one process at a time
 * for now. *)

(* the programs in the image *)
val count : unit -> int

(* [run i]: program i from its start to its end; its status *)
val run : int -> int

(* the running process ends (Abi's): [run] returns once the call does *)
val exit : int -> unit
