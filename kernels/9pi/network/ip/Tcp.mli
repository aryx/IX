(* TCP (principia's tcp.c, in a simple form): connect (blocking until
 * established, refused or timed out), announce and listen, a stream's
 * data out in segments of the peer's MSS within its window, in by
 * order only (a segment out of order dropped, the expected one asked
 * for again), go-back-N retransmission from the clock after a second
 * (10 tries), FIN both ways (a read then returns nothing). No
 * congestion control, no out-of-order queue, no keepalive: an emulated
 * link loses nothing. Sequence numbers are Int32s (32 bits, modular: a
 * Pi1 int has 31). *)

val init : unit -> unit

(* the retransmissions due (the clock's) *)
val tick : unit -> unit
