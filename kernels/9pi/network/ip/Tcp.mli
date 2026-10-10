(* TCP (principia's tcp.c, in a simple form): connect (blocking until
 * established, refused or timed out), announce and listen, a stream's
 * data out in segments of the peer's MSS within its window, in by
 * order only (a segment out of order dropped, the expected one asked
 * for again), go-back-N retransmission from the clock after a second
 * (10 tries), FIN both ways (a read then returns nothing). No
 * congestion control, no out-of-order queue, no keepalive: an emulated
 * link loses nothing. Sequence numbers are Int32s (32 bits, modular: a
 * Pi1 int has 31).
 *
 *     us (connect)                        the server (listening)
 *     Syn_sent      SYN seq=100      -->
 *                   <--  SYN seq=300 ack=101
 *     Established   ACK ack=301      -->  Established
 *                   seq=101, 5 bytes -->
 *                   <--  ack=106          (the 5 bytes have arrived)
 *     close:
 *     Fin_wait1     FIN seq=106      -->  Close_wait
 *     Fin_wait2     <--  ack=107
 *                   <--  FIN seq=301      Last_ack (it closed too)
 *     Closed        ACK ack=302      -->  Closed
 *
 * Every byte of the stream has a number, the two directions each
 * their own, starting where its SYN said; an ack is the number of
 * the next byte wanted, so it says all before has arrived, and
 * saying it twice costs nothing. That one rule gives the whole
 * protocol: what is not acked after a while is sent again, what
 * comes twice is known by its number, what comes too early is
 * (here) dropped and will be sent again. A SYN and a FIN each take
 * a number, so that they too are acked.
 *
 * Where it stands: a record of functions given to Ip (Ip.proto) for
 * Devip's files, an input function registered for protocol 6, and a
 * tick from Main's clock for what was not acked.
 *
 * wib:
 * What is left out is what makes TCP work on a real network. With
 * no congestion control a sender fills the receiver's window at
 * once and, on a loss, sends everything again: when every host did
 * that, in 1986, the Internet's throughput collapsed, and Van
 * Jacobson's slow start and congestion avoidance (1988) are why it
 * has not since. With no queue of early segments and go-back-N, one
 * lost packet costs a window. Under an emulator neither happens;
 * over a real link this TCP is correct and slow, and unkind to the
 * others on the wire.
 *
 * References: RFC 793 (1981): the state diagram, whose names these
 * are. Van Jacobson, "Congestion Avoidance and Control" (SIGCOMM
 * 1988). principia's Kernel.nw (tcp.c, 3,600 lines of it). *)

val init : unit -> unit

(* the retransmissions due (the clock's) *)
val tick : unit -> unit
