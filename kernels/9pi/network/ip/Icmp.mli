(* ICMP (principia's icmp.c). The kernel answers an echo request
 * itself. A connection (ping's, made with "connect 10.0.2.2!1") writes
 * room for an IP header and then an ICMP message, which is sent to its
 * remote address, with the connection's port as its echo identifier.
 * An echo reply with that identifier is read back whole, with its IP
 * header too (ping reads its TTL).
 *
 * ICMP is IP's own voice: the messages a host or a router sends about
 * packets rather than in them (no route, time exceeded, and this one,
 * "are you there"). It rides in IP as protocol 1. A message has a
 * type, a code, a checksum, and the rest depends on the type; an echo
 * has an identifier and a sequence number, which the answer repeats
 * with the data.
 *
 * cs-history:
 * ping was written by Mike Muuss, in an evening of December 1983, to
 * find a fault in a network, and it is named after sonar's sound. It
 * is still the first thing typed when a network does not work. *)

val init : unit -> unit
