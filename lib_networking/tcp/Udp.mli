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
