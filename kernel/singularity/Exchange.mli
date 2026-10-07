(* mini-singularity: the exchange heap (decision 4 of
 * plan_system_singularity.md): blocks of bytes that are no process's
 * heap, each with one owner. A block goes from a process to another in
 * a message: its owner changes, its bytes are not copied. A process
 * reaches its blocks' bytes by calls (Abi), which copy between the
 * block and its own heap: no pointer of a process points here, so a
 * process is collected, and ended, without the others.
 *
 * Singularity's compiler proves that a block given away is not used
 * again; here the owner is looked at when the program runs: the
 * sender's handle is no longer one (Process). *)

type block = {
  mutable owner : int;          (* a process; in_message; freed *)
  data : Bytes.t;
}
val in_message : int
val freed : int

(* a block's bytes at most, and all the blocks' *)
val max_block : int
val max_bytes : int

(* [alloc owner n]: n bytes of zeros; None past a limit *)
val alloc : int -> int -> block option
val free : block -> unit
(* the bytes of the blocks not freed *)
val bytes : unit -> int
