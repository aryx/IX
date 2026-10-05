(* What a program waits for from the system, as messages on a channel
 * (plan_rio.md, "Threads: the design"): a thread never reads a
 * descriptor that may block; it receives from a source's channel, and
 * may choose between several (Event.select).
 *
 * Two files, for the two kinds of threads. This directory's, for
 * OCaml's (dune's builds): a thread reads and sends. And
 * ../concurrency/'s, for mini-ml's, which are cooperative (a thread
 * that reads stops them all): a process of its own reads, and writes
 * each read, with the source's number and its length, to one pipe,
 * which the scheduler reads when no thread can run. *)

(* [reader caps fd n]: each read of fd (n bytes at most, 4000 at most)
 * a message; an empty one at its end, or when a read fails, the last *)
val reader : < Cap.fork; .. > -> Unix.file_descr -> int -> bytes Event.channel

(* [timer caps d]: a message every d seconds *)
val timer : < Cap.fork; .. > -> float -> unit Event.channel
