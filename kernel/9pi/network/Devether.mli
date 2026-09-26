(* '#l', the Ethernet device (principia's devether.c and netif.c): #l0
 * is ether0, the adapter Etherusb drives, its files netif's: clone (a
 * new connection: its ctl), addr (the MAC's 12 hex digits), stats,
 * ifstats, and each connection's directory: ctl ("connect TYPE": the
 * frames of an Ethernet type it gets, -1 all; its read, its number),
 * data (a frame read or written: the source address filled in), type,
 * stats, ifstats. The IP stack (devip's ethermedium) uses it directly:
 * [register], [transmit]. *)

(* the device registered *)
val init : unit -> unit

(* the adapter's MAC (6 bytes): Enodev without one *)
val mac : unit -> string

(* [register type f]: the frames of an Ethernet type given to f (on the
 * clock); [transmit frame]: one sent, its source address ours *)
val register : int -> (string -> unit) -> unit
val transmit : string -> unit

(* the frames in since the last time, to their connections (the clock's) *)
val input : unit -> unit
