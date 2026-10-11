(* IPv4 over the Ethernet (principia's ip.c, ipifc.c, arp.c, iproute.c,
 * in a simple form): the interface ipconfig binds and gives addresses,
 * ARP (a packet waiting for its next hop's address), a route to the
 * subnet or the default gateway, the header and its checksum; the
 * protocols (Icmp, Udp, Tcp) register their input, and their
 * connections (Plan 9's Conv) for Devip's files. An address is its 4
 * bytes (network order: a string; a Pi1 int has 31 bits). No IPv6,
 * no fragments, one interface.
 *
 * A write to a TCP connection, down to the wire and back up:
 *
 *     a program    write(fd, "GET / ...")       /net/tcp/0/data
 *     Devip        the connection's protocol: Tcp's write
 *     Tcp          a segment: ports, sequence numbers, checksum
 *     Ip.send      the header (20 bytes: addresses, protocol 6, a
 *                  checksum); the next hop: the destination when it
 *                  is on our subnet, else the gateway; its Ethernet
 *                  address from the ARP table, or the packet waits
 *                  and a request goes out: who has 10.0.2.2?
 *     Devether     the frame: 6 bytes to, 6 from, the type 0x0800,
 *                  the packet
 *     Etherusb     the adapter (USB's bulk endpoint: Usbdwc)
 *
 *     the clock    Devether.input: the frames in, each to the
 *                  function registered for its type: 0x0806 ARP's,
 *                  0x0800 this module's input
 *     Ip           the checksum, is it ours; by protocol: 1 Icmp,
 *                  6 Tcp (the functions they gave [register])
 *     Tcp          the data to its connection ([deliver]): the
 *                  program asleep in a read is woken
 *
 * Each layer's packet is the payload of the one under, behind a
 * header of its own, and knows nothing of that header: the idea
 * that lets IP run over anything and anything run over IP.
 *
 * An address has no meaning to Ethernet, which knows its own 6-byte
 * ones: ARP is the translation, asked aloud to everyone on the wire
 * and remembered. The checksum is the complement of the sum of the
 * header's 16-bit words, carries added back in ([cksum]): weak, and
 * cheap enough for a router to do again at each hop, as it must,
 * since it changes the header (the hops left).
 *
 * cs-history:
 * Vinton Cerf and Robert Kahn's protocol of 1974 was one layer;
 * its split in two in 1978, a datagram that may be lost (IP) under
 * a connection that mends it (TCP), is what let a second transport
 * (UDP) and every later one share the network. The versions here
 * are the RFCs of September 1981, which the ARPANET switched to on
 * the first of January 1983. Thirty-two bits for an address seemed
 * plenty for an experiment; IPv6 (1995), with 128, is the mending
 * of that, and is not here.
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

(* The interface (ipifc): its device, its addresses (local, mask);
 * [bind], [add], [remove], [unbind] ipifc's ctl commands *)
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

(* the routes (iproute: destination, mask, gateway; "add 0 0 gw" the
 * default), the ARP table, as their files read *)
val routes : (string * string * string) list ref
val routetext : unit -> string
val arptext : unit -> string

(* [send proto src dst payload]: an IP packet out; [register proto f]:
 * the packets of an IP protocol given to f (the whole packet) *)
val send : int -> string -> string -> string -> unit
val register : int -> (string -> unit) -> unit

(* A connection (Conv): its protocol's name and index, a key (its
 * sleeps'), how many hold it, its addresses and ports, the data waiting
 * for its reads, its state for the status file *)
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
  (* no more data: a read then returns nothing (TCP's FIN) *)
  mutable eof : bool;
}

(* A protocol (Proto): its name, its connections; its ctl's connect and
 * announce, its data's write, its status, its close; [listen] a new
 * connection called in (blocking); [ctl] its own commands (false: not
 * one) *)
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
(* "addr!port" (addr "*": any) *)
val addrport : string -> string * int
(* the next free local port *)
val nextport : unit -> int
(* data for a connection's reads, its readers woken *)
val deliver : conv -> string -> unit
