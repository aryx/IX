(* IPv4 over the Ethernet (principia's ip.c, ipifc.c, arp.c, iproute.c,
 * in a simple form): the interface ipconfig binds and gives addresses,
 * ARP (a packet waiting for its next hop's address), a route to the
 * subnet or the default gateway, the header and its checksum; the
 * protocols (Icmp, Udp, Tcp) register their input, and their
 * connections (Plan 9's Conv) for Devip's files. An address is its 4
 * bytes (network order: a string; a Pi1 int has 31 bits). No IPv6,
 * no fragments, one interface. *)

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
