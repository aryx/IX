(* IPv4 over the Ethernet (principia's ip.c, ipifc.c, arp.c and
 * iproute.c, in a simple form). This module has:
 * - the interface, which ipconfig binds and gives addresses to;
 * - ARP (a packet waits here for its next hop's address);
 * - a route to the subnet or to the default gateway;
 * - the header and its checksum.
 * The protocols (Icmp, Udp, Tcp) register their input here, and their
 * connections (Plan 9's Conv) are kept here for Devip's files. An
 * address is its 4 bytes, in network order, in a string (because a
 * Pi1 int has only 31 bits). There is no IPv6, there are no fragments,
 * and there is one interface.
 *
 * Here is a write to a TCP connection, down to the wire and back up:
 *
 *     a program    write(fd, "GET / ...")       /net/tcp/0/data
 *     Devip        calls the connection's protocol: Tcp's write
 *     Tcp          makes a segment: ports, sequence numbers, checksum
 *     Ip.send      adds the header (20 bytes: the addresses, protocol
 *                  6, a checksum); picks the next hop: the destination
 *                  when it is on our subnet, else the gateway; finds
 *                  its Ethernet address in the ARP table, or else the
 *                  packet waits and a request goes out: who has
 *                  10.0.2.2?
 *     Devether     makes the frame: 6 bytes to, 6 from, the type
 *                  0x0800, then the packet
 *     Etherusb     drives the adapter (USB's bulk endpoint, in Usbdwc)
 *
 *     the clock    calls Devether.input: it gives each frame in to the
 *                  function registered for its type: ARP's for 0x0806,
 *                  this module's input for 0x0800
 *     Ip           checks the checksum and whether the packet is ours,
 *                  then dispatches by protocol: 1 to Icmp, 6 to Tcp
 *                  (the functions they gave [register])
 *     Tcp          gives the data to its connection ([deliver]): the
 *                  program asleep in a read is woken
 *
 * Each layer's packet is the payload of the layer under it, behind a
 * header of that layer's own, and it knows nothing of that header.
 * This is the idea that lets IP run over anything, and anything run
 * over IP.
 *
 * An IP address has no meaning to Ethernet, which knows only its own
 * 6-byte addresses. ARP is the translation: the question is asked
 * aloud to everyone on the wire, and the answer is remembered. The
 * checksum is the complement of the sum of the header's 16-bit words,
 * with the carries added back in ([cksum]). It is weak, and cheap
 * enough for a router to compute again at each hop, as it must, since
 * it changes the header (the count of hops left).
 *
 * cs-history:
 * Vinton Cerf and Robert Kahn's protocol of 1974 was one layer. It was
 * split in two in 1978, into a datagram that may be lost (IP) under a
 * connection that mends the losses (TCP), and that split is what let a
 * second transport (UDP) and every later one share the network. The
 * versions here are the RFCs of September 1981, which the ARPANET
 * switched to on the first of January 1983. Thirty-two bits for an
 * address seemed plenty for an experiment; IPv6 (1995), with 128 bits,
 * is the mending of that, and it is not here.
 *
 * References: RFC 791 (IP, 1981), RFC 826 (ARP, 1982), RFC 1071
 * (the checksum, 1988). V. Cerf and R. Kahn, "A Protocol for Packet
 * Network Intercommunication" (IEEE Transactions on Communications,
 * 1974). Dave Presotto and Phil Winterbottom, "The Organization of
 * Networks in Plan 9" (USENIX Winter 1993), for Conv and Proto.
 * principia's Kernel.nw (the network chapters). *)

(* addresses *)
val parse : string -> string
val show : string -> string
val parsemask : string -> string
val noaddr : string
val get16 : string -> int -> int
val put16 : int -> string
val cksum : string -> int -> int -> int -> int

(* The interface (ipifc), with its device and its addresses (local and
 * mask). [bind], [add], [remove] and [unbind] are ipifc's ctl
 * commands. *)
type lifc = { local : string; mask : string }
type ifc = { mutable dev : string; mutable lifcs : lifc list; mutable mtu : int;
             mutable pktin : int; mutable pktout : int }
val ifc : ifc
val bind : string -> unit
val add : string -> string -> unit
val remove : string -> string -> unit
val unbind : unit -> unit
val ours : string -> bool
(* the source address for a destination *)
val source : string -> string

(* the routes (iproute: destination, mask, gateway; "add 0 0 gw" adds
 * the default route), and the routes and the ARP table as their files
 * read them *)
val routes : (string * string * string) list ref
val routetext : unit -> string
val arptext : unit -> string

(* [send proto src dst payload] sends an IP packet out. [register proto
 * f] gives the packets of an IP protocol to f (the whole packet). *)
val send : int -> string -> string -> string -> unit
val register : int -> (string -> unit) -> unit

(* A connection (Conv). Besides its protocol's name, its index, its
 * addresses and ports, it has a key (what its sleeps wait on), how
 * many hold it, the data waiting for its reads, and its state for the
 * status file. *)
type conv = {
  proto : string;
  cid : int;
  key : int;
  mutable held : int;
  mutable laddr : string;
  mutable lport : int;
  mutable raddr : string;
  mutable rport : int;
  rq : string Queue.t;
  mutable cstate : string;
  mutable headers : bool;
  (* there is no more data, and a read then returns nothing (TCP's
   * FIN) *)
  mutable eof : bool;
}

(* A protocol (Proto). It has its name and its connections, and the
 * functions for a connection's ctl commands connect and announce, for
 * a write to its data, for its status and for its close. [listen]
 * waits for a caller and returns the new connection. [ctl] handles
 * the protocol's own commands, and returns false when the command is
 * not one of them. *)
type proto = {
  pname : string;
  convs : conv option array;
  connect : conv -> string -> unit;
  announce : conv -> string -> unit;
  write : conv -> string -> unit;
  state : conv -> string;
  close : conv -> unit;
  listen : conv -> conv;
  ctl : conv -> string list -> bool;
}

val protos : proto list ref
val newconv : proto -> conv
(* parses "addr!port" (an addr of "*" means any) *)
val addrport : string -> string * int
(* the next free local port *)
val nextport : unit -> int
(* queues data for a connection's reads, and wakes its readers *)
val deliver : conv -> string -> unit
