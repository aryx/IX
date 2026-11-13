(* Udp sends one packet to another computer and gets one back, on the
   operating system's side. It is what Tcp is for a stream.

   UDP (David Reed's proposal; RFC 768, by Jon Postel, 1980, in three
   pages) is IP's packet with two port numbers and a checksum. There is
   no connection and no order, and nothing is sent again. All of that
   is left to the program, and for one question and its answer it is
   little: ask, wait, and ask again. The resolver (Dns) is its user
   here.

   It works the same two ways as Tcp. On Linux it is a socket of
   another kind (SOCK_DGRAM). On Plan 9 it is a directory under
   /net/udp, whose ctl takes "connect 10.0.2.3!53", and whose data then
   sends a packet at each write and gives a packet at each read
   (plan9/Udp.ml, for mini-9pi).

   Reference: RFC 768, "User Datagram Protocol" (1980). *)

(* [ask caps ~address ~port packet seconds] sends the packet to the port
 * of the computer at [address] ("10.0.2.3"), and returns the first
 * packet that comes back, or None after [seconds] of silence. It
 * raises Unix.Unix_error when the network is not there. *)
val ask : < Cap.network; .. > -> address:string -> port:int -> string -> float -> string option

(* A socket kept, for a program that sends and takes packets at each of
 * its frames and never waits (a game, through lib_playground/netcode's
 * Transport). They are the host and join of libs/networking/unix/Udp
 * in the author's playground. There are two computers, one that hosts
 * and one that joins:
 *
 *     host   waits on a port of one of its addresses ("0.0.0.0": all
 *            of them); the first computer that sends it a packet is
 *            the other one, from then on
 *     join   knows the host's address and port; its first packet says
 *            where it is itself
 *
 * There is no connection: only the packets say whether the other one
 * is there. On Linux a peer is a socket, asked with select before each
 * read. On Plan 9 it is a conversation of /net/udp ("announce" with
 * "headers": a read gives each packet behind its sender's address, and
 * a write takes one behind its destination's address), read by a
 * process of its own (lib_core's Source, because Plan 9 has no
 * select); that is why the two functions ask for Cap.fork. They raise
 * Unix.Unix_error (for a port taken, or no network) and Failure (for
 * an address that is not one). *)
type peer

val host : < Cap.network; Cap.fork; .. > -> address:string -> port:int -> peer
val join : < Cap.network; Cap.fork; .. > -> address:string -> port:int -> peer

(* Sends a packet to the other one. The packet is dropped while a host
 * knows no other one, and when the system refuses it, since a packet
 * may be lost anyway. *)
val send : peer -> string -> unit

(* The other one's packets since the last call, the oldest first. It
 * never waits. *)
val arrived : peer -> string list

(* The other one's address, such as "192.168.1.12:7777", once it is
 * known. *)
val other : peer -> string option
