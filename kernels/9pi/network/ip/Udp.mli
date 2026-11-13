(* UDP (principia's udp.c, in a simple form) sends a datagram to a port
 * of another machine, and takes the datagrams that come back from it.
 *
 * UDP is IP's packet with two ports and a checksum, and nothing more:
 * there is no connection, no order, nothing sent again, and no window.
 * It rides in IP as protocol 17, behind eight bytes:
 *
 *     source port (2)   destination port (2)
 *     length (2)        checksum (2)           then the data
 *
 * The checksum is IP's sum over the datagram and over a
 * "pseudo-header" of what IP knows (the two addresses, the protocol,
 * the length), as TCP's is, so that a datagram that reached the wrong
 * machine is caught. A sum of 0 is sent as 0xffff, because 0 means
 * that no checksum was made.
 *
 * A connection (/net/udp/n, after "connect 10.0.2.3!53" is written to
 * its ctl) is only where its writes go and whose datagrams its reads
 * take: nothing is said on the wire. A write to its data is one
 * datagram, and a read is one datagram, its data alone. Programs that
 * ask one question and wait for one answer use it, the resolver first
 * (lib_networking's Dns, through its plan9/Udp), since the three
 * packets of a connection's handshake would cost more than the
 * question.
 *
 * A server has no one to connect to. It announces a port ("announce
 * *!7777") and asks for headers ("headers"). Then each read is a
 * datagram from anyone, behind 52 bytes that say whose it is, and
 * each write goes to the one that its own 52 bytes name:
 *
 *     0   the remote address   16 bytes, IPv6's size: an IPv4 address
 *                              is the last 4, after ten 0s and two 0xff
 *     16  the local address    16
 *     32  the interface's      16
 *     48  the remote port      2
 *     50  the local port       2
 *
 * So one file answers many clients, where a socket needs two more
 * calls, recvfrom and sendto. Here the user of this is a game's host
 * (lib_networking's plan9/Udp, under the playground's Multiplayer).
 *
 * What is not done:
 * - an announced port without headers (Plan 9 makes a new conversation
 *   for each sender, to be listened for);
 * - a datagram larger than a frame (there are no fragments, as in Ip).
 *
 * cs-history:
 * UDP is what was left when TCP was cut out of IP in 1978. David Reed
 * argued for a way to reach the bare datagram, for those whom a stream
 * does not suit, speech first, where a late packet is worth nothing.
 * Jon Postel's RFC is three pages long.
 *
 * Reference: RFC 768, "User Datagram Protocol" (1980). *)

val init : unit -> unit
