(* What a process of mini-singularity asks of the kernel beyond what
 * the standard library does for it (print_string: the debug line;
 * exit: its end): the kernel's ABI (Abi), by lib/sip.c.
 *
 * What a process holds of the kernel is a handle, which means
 * something to this process only: another process, a channel's
 * endpoint, a block of the exchange heap. A handle given away (an
 * endpoint to a child, a block in a message) or let go (a process
 * joined, an endpoint closed, a block freed) is no longer one: using
 * it raises Not_held. Singularity's compiler refuses such a program;
 * here it is found when the program runs. *)

exception Not_held

(* the other processes run; back when the kernel's turn comes again *)
val yield : unit -> unit
(* microseconds, from the board's timer *)
val time : unit -> int

(* Processes *)

type process

(* a process of the program of that name, not started: None if there is
 * no such program, or one of it runs already *)
val create : string -> process option
val start : process -> unit
(* waits for its end: its status *)
val join : process -> int

(* Channels: the only way to another process *)

type endpoint

(* the other end is closed, and nothing is left to receive *)
exception Closed

(* a channel: its two endpoints *)
val channel : unit -> endpoint * endpoint
(* an endpoint to a child not started; there it is [given i], i the
 * number of endpoints it was given before *)
val give : process -> endpoint -> unit
val given : int -> endpoint

type block

type message = {
  tag : int;
  value : int;
  block : block option;
}

(* [send e tag value]: never waits; [send_block]: the block goes with
 * the message, and is the receiver's *)
val send : endpoint -> int -> int -> unit
val send_block : endpoint -> int -> int -> block -> unit
(* waits for a message *)
val receive : endpoint -> message
(* waits until one of them (three at most) has a message, or is
 * closed: its place in the list *)
val select : endpoint list -> int
val close : endpoint -> unit

(* The exchange heap: bytes outside this process's heap, which go to
 * another process without being copied. Their owner reads and writes
 * them where they are: none of these but alloc and free calls the
 * kernel. *)

(* a block of n bytes of zeros *)
val alloc : int -> block
val free : block -> unit
val size : block -> int
val get : block -> int -> char
val set : block -> int -> char -> unit
(* [sub b off n]: n of its bytes as a string (a copy, into this
 * process's heap); [write b off s]: s's bytes into it at off *)
val sub : block -> int -> int -> string
val write : block -> int -> string -> unit
