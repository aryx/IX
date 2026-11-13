(* '#l' is the Ethernet device (principia's devether.c and netif.c).
 * #l0 is ether0, the adapter that Etherusb drives, and its files are
 * netif's:
 * - clone, whose open makes a new connection and gives its ctl;
 * - addr, the MAC address as 12 hex digits;
 * - stats and ifstats;
 * - a directory for each connection, with:
 *   - ctl: writing "connect TYPE" makes the connection get the frames
 *     of that Ethernet type (-1 for all of them), and reading it gives
 *     the connection's number;
 *   - data: a read gives a frame and a write sends one, with the source
 *     address filled in;
 *   - type, stats and ifstats.
 * The IP stack (devip's ethermedium) uses the device directly, with
 * [register] and [transmit].
 *
 *     a frame, as a read of data gives it and a write takes it
 *     0   the destination's address    6 bytes (all ones: everyone)
 *     6   the source's address         6 bytes
 *     12  the type                     2 bytes: 0x0800 IP, 0x0806 ARP
 *     14  the payload                  up to 1500 bytes
 *
 * The type is all there is to the dispatch: a frame goes to whoever
 * asked for its type, which is the kernel's Ip (through [register])
 * and any program with a connection of that type. Below this module,
 * Etherusb moves the bytes. Main's clock calls [input] at each tick to
 * take in what has arrived, so nothing here runs from an interrupt.
 *
 * plan9-is-cleaner:
 * Watching a network needs nothing special: a program opens a
 * connection, writes "connect -1" to its ctl, and reads every frame
 * from data. That is all Plan 9's snoopy does. Unix needed a mechanism
 * of its own for the same thing (Berkeley's packet filter, with a
 * small virtual machine in the kernel to choose the frames).
 *
 * cs-history:
 * Ethernet was made by Bob Metcalfe and David Boggs, at Xerox PARC in
 * 1973: one cable that everyone listens to, and a sender that waits
 * for silence and tries again after a random time when two senders
 * collide. The cable and the collisions are gone (a switch gives each
 * machine its own wire). The frame above is what stayed, and it is
 * what Wi-Fi and a USB adapter still pretend to carry.
 *
 * References: ether(3) in the Plan 9 manual. R. Metcalfe and D.
 * Boggs, "Ethernet: Distributed Packet Switching for Local Computer
 * Networks" (CACM, 1976). *)

(* registers the device *)
val init : unit -> unit

(* the adapter's MAC address (6 bytes); it raises Enodev when there is
 * no adapter *)
val mac : unit -> string

(* [register type f] gives the frames of an Ethernet type to f (on the
 * clock). [transmit frame] sends a frame, with our source address. *)
val register : int -> (string -> unit) -> unit
val transmit : string -> unit

(* gives the frames that came in since the last time to their
 * connections (the clock calls it) *)
val input : unit -> unit
