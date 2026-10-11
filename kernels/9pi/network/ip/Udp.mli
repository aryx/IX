(* UDP (principia's udp.c, in a simple form): a datagram to a port of
 * another machine, and the datagrams that come back from it.
 *
 * UDP is IP's packet with two ports and a checksum, and nothing
 * more: no connection, no order, nothing sent again, no window. It
 * rides in IP as protocol 17 behind eight bytes:
 *
 *     source port (2)   destination port (2)
 *     length (2)        checksum (2)           then the data
 *
 * The checksum is IP's sum over the datagram and a "pseudo-header"
 * of what IP knows (the two addresses, the protocol, the length), as
 * TCP's: a datagram that reached the wrong machine is caught. A sum
 * of 0 is sent as 0xffff, 0 meaning none was made.
 *
 * A connection (/net/udp/n: "connect 10.0.2.3!53" written to its ctl)
 * is only where its writes go and whose datagrams its reads take:
 * nothing is said on the wire. A write to its data is one datagram, a
 * read is one, its data alone. What asks one question and waits for
 * one answer uses it, the resolver first (lib_networking's Dns, by
 * its plan9/Udp), since a connection's three packets of handshake
 * would cost more than the question.
 *
 * Not done: an announced port's datagrams with their sender's address
 * before the data (Plan 9's "headers"), so no server; a datagram
 * larger than a frame (no fragments, as Ip).
 *
 * cs-history:
 * UDP is what was left when TCP was cut out of IP in 1978: David
 * Reed argued for a way to the bare datagram for those whom a
 * stream does not suit, speech first, where a late packet is worth
 * nothing. Jon Postel's RFC is three pages.
 *
 * Reference: RFC 768, "User Datagram Protocol" (1980). *)

val init : unit -> unit
