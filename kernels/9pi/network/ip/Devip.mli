(* '#I' is the IP device (principia's devip.c). It has a directory for
 * each protocol (ipifc, icmp, udp, tcp), and the files arp, iproute,
 * ipselftab, ndb and log. A protocol's directory has a clone file and
 * a directory for each connection, with these files:
 * - ctl: reading it gives the connection's number, and a program
 *   writes "connect addr!port" or "announce" to it;
 * - data and err;
 * - listen: its open gives a new connection's ctl, when someone calls
 *   in;
 * - local, remote and status.
 * ipifc's connections are the interfaces. Their ctl takes "bind ether
 * /net/ether0", "add ip mask", "remove" and "unbind", and their status
 * is written as libip's readipifc parses it.
 *
 * Here is a connection to a web server, made by hand (libc's dial does
 * this):
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
 * Below this module, each protocol is a record (Ip.proto, as in Tcp
 * and Icmp) and each connection is an Ip.conv; this file is only their
 * tree of files.
 *
 * plan9-is-cleaner:
 * There are no sockets. Berkeley's interface (4.2BSD, 1983) added to
 * Unix a second kind of descriptor with its own calls (socket, bind,
 * connect, listen, accept, send, recv, getsockname, setsockopt and
 * more), a structure of addresses for each family of protocols, and
 * numbers for everything; none of it had a name in the file system.
 * Here a network is a directory:
 * - the calls are open, read and write;
 * - an address is text ("tcp!10.0.2.2!80"), the same for any protocol;
 * - ls and cat are the diagnostic tools (cat /net/tcp/4/status);
 * - a machine without a network of its own uses another machine's by
 *   mounting its /net, which is all a gateway is.
 *
 * References: ip(3) and dial(2) in the Plan 9 manual. Dave Presotto
 * and Phil Winterbottom, "The Organization of Networks in Plan 9"
 * (USENIX Winter 1993). *)

val init : unit -> unit
