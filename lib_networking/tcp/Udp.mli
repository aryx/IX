(* Udp: one packet to another computer and one back, the operating
   system's side -- what Tcp is for a stream.

   UDP (David Reed's proposal, RFC 768, Jon Postel, 1980: three pages)
   is IP's packet with two port numbers and a checksum: no connection,
   no order, nothing sent again. What is left to the program is all of
   it, and for one question and its answer that is little: ask, wait,
   ask again. The resolver (Dns) is its user here.

   The same two ways as Tcp's: on Linux a socket of another kind
   (SOCK_DGRAM); on Plan 9 a directory under /net/udp, whose ctl takes
   "connect 10.0.2.3!53" and whose data is then a packet a write and a
   packet a read (plan9/Udp.ml, for mini-9pi).

   Reference: RFC 768, "User Datagram Protocol" (1980). *)

(* [ask caps ~address ~port packet seconds]: the packet sent to the port
 * of the computer at [address] ("10.0.2.3"), and the first packet that
 * comes back; None after [seconds] of silence. Raises Unix.Unix_error
 * (a network that is not there) *)
val ask : < Cap.network; .. > -> address:string -> port:int -> string -> float -> string option

(* A socket kept, for a program that sends and takes packets at each of
 * its frames and never waits (a game: lib_playground/netcode's
 * Transport; the author's playground's libs/networking/unix/Udp, its
 * host and join). Two computers, one that hosts and one that joins:
 *
 *     host   waits on a port of one of its addresses ("0.0.0.0": all
 *            of them); the first computer that sends it a packet is
 *            the other one, from then on
 *     join   knows the host's address and port; its first packet says
 *            where it is itself
 *
 * No connection: whether the other one is there is what the packets
 * say. On Linux a socket, asked with select before each read; on Plan
 * 9 a conversation of /net/udp ("announce" with "headers": a read
 * gives each packet behind its sender's address, a write takes one
 * behind its destination's), read by a process of its own
 * (lib_core's Source: Plan 9 has no select), which is why the two ask
 * Cap.fork. Raises Unix.Unix_error (a port taken, no network) and
 * Failure (an address that is not one). *)
type peer

val host : < Cap.network; Cap.fork; .. > -> address:string -> port:int -> peer
val join : < Cap.network; Cap.fork; .. > -> address:string -> port:int -> peer

(* a packet to the other one; dropped while a host knows none, and when
 * the system refuses it: a packet may be lost anyway *)
val send : peer -> string -> unit

(* the other one's packets since the last time, the oldest first; never
 * waits *)
val arrived : peer -> string list

(* the other one, "192.168.1.12:7777", once known *)
val other : peer -> string option
