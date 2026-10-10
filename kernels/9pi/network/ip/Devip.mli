(* '#I', the IP device (principia's devip.c): its protocols' directories
 * (ipifc, icmp, udp, tcp), each a clone and its connections (ctl: a
 * number read, "connect addr!port" or "announce" written; data; err;
 * listen: a new connection's ctl, when one calls in; local; remote;
 * status), and arp, iproute, ipselftab, ndb, log. ipifc's connections
 * are the interfaces: ctl's "bind ether /net/ether0", "add ip mask",
 * "remove", "unbind"; status as libip's readipifc parses it.
 *
 * A connection to a web server, by hand (libc's dial does this):
 *
 *     fd = open("/net/tcp/clone", ORDWR)    a new connection, and fd
 *                                           is its ctl file
 *     read(fd)                              "4": it is /net/tcp/4
 *     write(fd, "connect 10.0.2.2!80")      returns when connected,
 *                                           or fails with the reason
 *     d = open("/net/tcp/4/data", ORDWR)    the stream: read, write
 *     close(d); close(fd)                   hung up, at the last close
 *
 *     a server: "announce *!80" to a clone's ctl, then an open of
 *     its listen file, which waits for a caller and is the ctl of a
 *     new connection, the caller's
 *
 * Under it each protocol is a record (Ip.proto: Tcp, Icmp) and each
 * connection an Ip.conv; this file is only their tree of files.
 *
 * plan9-is-cleaner:
 * No sockets. Berkeley's interface (4.2BSD, 1983) added to Unix a
 * second kind of descriptor with its own calls, socket, bind,
 * connect, listen, accept, send, recv, getsockname, setsockopt and
 * more, a structure of addresses per family of protocols, and
 * numbers for everything; nothing of it had a name in the file
 * system. Here a network is a directory. The calls are open, read,
 * write; an address is text ("tcp!10.0.2.2!80"), the same for any
 * protocol; ls and cat are the diagnostic tools (cat
 * /net/tcp/4/status); and a machine without a network of its own
 * uses another's by mounting its /net, which is all a gateway is.
 *
 * References: ip(3) and dial(2) in the Plan 9 manual. Dave Presotto
 * and Phil Winterbottom, "The Organization of Networks in Plan 9"
 * (USENIX Winter 1993). *)

val init : unit -> unit
