(* '#I', the IP device (principia's devip.c): its protocols' directories
 * (ipifc, icmp, udp, tcp), each a clone and its connections (ctl: a
 * number read, "connect addr!port" or "announce" written; data; err;
 * listen: a new connection's ctl, when one calls in; local; remote;
 * status), and arp, iproute, ipselftab, ndb, log. ipifc's connections
 * are the interfaces: ctl's "bind ether /net/ether0", "add ip mask",
 * "remove", "unbind"; status as libip's readipifc parses it. *)

val init : unit -> unit
