(* mini-singularity: the exchange heap (decision 4 of
 * plan_system_singularity.md): memory that is no process's heap, in
 * blocks, each with one owner. A block goes from a process to another
 * in a message: its owner changes, its bytes stay where they are. Its
 * owner reads and writes them where they are too, with no call of the
 * kernel: the kernel tells it the block's address, which only the
 * process's trusted library sees (lib/sip.c; a program has an abstract
 * Sip.block, and forgets the address when the block is sent or freed).
 * Nothing in a block points anywhere: bytes, which no collector reads.
 *
 * Singularity's compiler proves that a block given away is not used
 * again; here that library looks at each use, when the program runs.
 *
 * The heap is a piece of the board's memory between the kernel and the
 * programs (the mkfile says where), its blocks whole pages, zeros when
 * given. *)

type block = {
  mutable owner : int;          (* a process; in_message; freed *)
  addr : int;                   (* physical *)
  size : int;                   (* the bytes asked for *)
}
val in_message : int
val freed : int

(* [alloc owner n]: n bytes of zeros; None when there is no room *)
val alloc : int -> int -> block option
val free : block -> unit
(* the bytes of the blocks not freed (their pages') *)
val bytes : unit -> int
