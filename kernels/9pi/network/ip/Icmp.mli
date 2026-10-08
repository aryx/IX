(* ICMP (principia's icmp.c): an echo request answered by the kernel; a
 * connection's (ping's: "connect 10.0.2.2!1") writes an IP header's
 * room and an ICMP message, sent to its remote address, its echo
 * identifier the connection's port; an echo reply with that
 * identifier read back whole, its IP header too (ping reads its TTL). *)

val init : unit -> unit
