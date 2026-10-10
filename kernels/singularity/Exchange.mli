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
 * given.
 *
 * A block's life, its owner at each step (ping lends pong a block):
 *
 *     ping: Sip.alloc 4096           owner = ping
 *     ping: writes "hello" in it     no call of the kernel
 *     ping: Pong.Imp.lend e b        owner = in_message; ping's
 *                                    handle is no longer one
 *     pong: Pong.Exp.receive e       owner = pong; a handle of
 *                                    pong's, the same address
 *     pong: Sip.free b               owner = freed; the pages back
 *                                    in the holes
 *
 * The bytes never move, and at no step can two processes reach
 * them. A message closed with a block still in it frees the block
 * (Channel.close); a process that ends has its blocks freed
 * (Process): nothing is left that nobody owns.
 *
 * Why not let processes share their own heaps' values: each process
 * has its own collector, which moves and frees what it alone can
 * see. A value seen from two heaps would need the two collectors to
 * agree, and stopping one process would no longer free its memory
 * whole. So what crosses is bytes that point nowhere, outside
 * every collected heap.
 *
 * terminology:
 * Linear, or unique, ownership: a value that has exactly one
 * holder, and is moved, not copied, when passed. Sing# marks such
 * types and its compiler tracks them (Singularity's "exchangeable
 * types"); Rust (2015) made the rule its whole memory model, with
 * the same word, move. "Used after it was given away" is, there, a
 * compile-time error; here, Sip's Not_held.
 *
 * others:
 * Unix passes bytes between processes by copying them into the
 * kernel and out (a pipe: mini-xv6's File), or shares pages (mmap,
 * System V's shared memory) and leaves the two programs to agree
 * on who writes when. Zero-copy paths were added case by case
 * (sendfile, splice, io_uring's buffers).
 *
 * References: Hunt and Larus (2007), "Exchange heap"; Fahndrich and
 * others (EuroSys 2006), where the ownership rules and their static
 * checking are given. *)

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
