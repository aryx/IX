(* '#l', the Ethernet device (principia's devether.c and netif.c): #l0
 * is ether0, the adapter Etherusb drives, its files netif's: clone (a
 * new connection: its ctl), addr (the MAC's 12 hex digits), stats,
 * ifstats, and each connection's directory: ctl ("connect TYPE": the
 * frames of an Ethernet type it gets, -1 all; its read, its number),
 * data (a frame read or written: the source address filled in), type,
 * stats, ifstats. The IP stack (devip's ethermedium) uses it directly:
 * [register], [transmit].
 *
 *     a frame, as a read of data gives it and a write takes it
 *     0   the destination's address    6 bytes (all ones: everyone)
 *     6   the source's                 6 bytes
 *     12  the type                     2 bytes: 0x0800 IP, 0x0806 ARP
 *     14  the payload                  up to 1500 bytes
 *
 * The type is the whole of the dispatch: a frame goes to whoever
 * asked for its type, the kernel's Ip (by [register]) and any
 * program with a connection of that type. Under it Etherusb moves
 * the bytes; Main's clock calls [input] at each tick to take in
 * what has arrived, so nothing here runs from an interrupt.
 *
 * plan9-is-cleaner:
 * Watching a network needs nothing special: a program opens a
 * connection, writes "connect -1" to its ctl, and reads every
 * frame from data. That is all of Plan 9's snoopy. Unix needed a
 * mechanism of its own for the same (Berkeley's packet filter, with
 * a small virtual machine in the kernel to choose the frames).
 *
 * cs-history:
 * Ethernet is Bob Metcalfe's and David Boggs's, at Xerox PARC in
 * 1973: one cable everyone listens to, a sender that waits for
 * silence and tries again after a random time when two collide.
 * The cable and the collisions are gone (a switch gives each
 * machine its own wire); the frame above is what stayed, and what
 * Wi-Fi and a USB adapter still pretend to carry.
 *
 * References: ether(3) in the Plan 9 manual. R. Metcalfe and D.
 * Boggs, "Ethernet: Distributed Packet Switching for Local Computer
 * Networks" (CACM, 1976). *)

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
