(* ICMP (principia's icmp.c): an echo request answered by the kernel; a
 * connection's (ping's: "connect 10.0.2.2!1") writes an IP header's
 * room and an ICMP message, sent to its remote address, its echo
 * identifier the connection's port; an echo reply with that
 * identifier read back whole, its IP header too (ping reads its TTL).
 *
 * ICMP is IP's own voice: the messages a host or a router sends
 * about packets rather than in them (no route, time exceeded, and
 * this one, are you there). It rides in IP as protocol 1, a type, a
 * code, a checksum and the rest by type; for an echo, an identifier
 * and a sequence number that the answer repeats with the data.
 *
 * cs-history:
 * ping is Mike Muuss's, written in an evening of December 1983 to
 * find a fault in a network, and named after sonar's sound; it is
 * still the first thing typed when a network does not work. *)

val init : unit -> unit
