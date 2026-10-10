(* Tcp: a connection to another computer, the operating system's side.

   Everything in networking/ is bytes in, bytes out; this module is
   where the bytes leave the machine. TCP (Vint Cerf and Bob Kahn, 1974;
   RFC 793, 1981) gives two programs a *stream*: the bytes written at
   one end arrive at the other, all of them, in order -- over a network
   that loses, duplicates and reorders packets (the retransmissions and
   the reordering are the kernel's work, not ours). The Berkeley sockets
   (4.2BSD, 1983) are the API every system kept:

     client                                server
     getaddrinfo "elm-lang.org" -> address
     socket                                socket, bind, listen
     connect  --------------------------->  accept
     write "GET / ..."  ----------------->  read
     read  <------------------------------  write "HTTP/1.1 200 ..."
     read = 0 (end of stream) <-----------  close
     close

   A name becomes an address through DNS (getaddrinfo asks the
   system's resolver, and where it has none, mini-ml's, Dns.mli asks;
   a name may have several addresses, IPv4 and IPv6,
   tried in the order given until one answers). A stream has no
   messages, only bytes: a read gives whatever has arrived, maybe half a
   header, so a protocol must say where its messages end (Http.mli) --
   or, as here, read until the other side closes.

   A read gives up after [timeout] seconds of silence (select), so a
   server that never answers doesn't freeze the program; the connect
   itself still waits for the kernel's own timeout (a minute or two)
   on a host that doesn't answer at all.

   Reaching another computer is an authority, not a right: every
   function here takes a capability, [< Cap.network; .. >] (plan_caps.md),
   which a program gets only from Cap.main and hands down to the code it
   trusts with it (the open row [..]: any capabilities that include the
   network, with no coercion at the call). A function without one in
   its type can't reach the network. (ix: with Cap.open_in, for the
   name server's address, /etc/resolv.conf.)

   Where it stands: under Http_client (http://) and under Tls_client
   (https://), and above the kernel. This module is the program's
   side, a dozen lines around the system calls; the work the first
   paragraph leaves to the kernel is in ix too, in mini-9pi's own Tcp
   (its network's ip): the segments, the window, a segment sent again
   after a second of silence, FIN both ways, in a simple form with no
   congestion control. Two modules of one name, one each side of the
   system call.

   cs-history:
   How the Internet got its stream. The ARPANET's first protocol (NCP,
   1970) trusted the network to deliver. Cerf and Kahn's design ("A
   Protocol for Packet Network Intercommunication", 1974) trusted
   nothing but the two ends: any network that can carry a packet,
   however badly, will do, and the hosts make a reliable stream out of
   it -- the "end-to-end" idea, and why the Internet could be built out
   of other people's networks. It was split in two in 1978, IP to
   carry packets and TCP to make streams; the ARPANET switched to them
   on one day, January 1, 1983. The same year Berkeley's Unix (4.2BSD,
   Bill Joy and his group, paid by DARPA to do it) shipped them with
   an API that made a connection look like a file: the sockets above.
   In October 1986 the network collapsed under its own retransmissions
   -- a thousandfold slowdown; Van Jacobson's congestion control (1988)
   is what every TCP has done since: send faster until a packet is
   lost, then halve.

   plan9-is-cleaner:
   A socket looks like a file only once it is connected: before that
   it is five calls of its own (socket, bind, listen, accept, connect)
   with addresses in binary structures, a different one per protocol.
   Plan 9 has no such calls. A connection is a directory under
   /net/tcp: open clone, write "connect 93.184.216.34!80" into the ctl
   file it gives, open data, and read and write; dial() is a library
   function that does it. So a program reaches the network of another
   machine by importing its /net, and the shell can make a connection.
   mini-9pi's Devip serves those files.

   Reference: Vinton Cerf and Robert Kahn, "A Protocol for Packet
   Network Intercommunication" (IEEE Transactions on Communications,
   1974); Van Jacobson, "Congestion Avoidance and Control" (SIGCOMM
   1988); Saltzer, Reed and Clark, "End-to-End Arguments in System
   Design" (1984); Dave Presotto and Phil Winterbottom, "The
   Organization of Networks in Plan 9" (USENIX Winter 1993), /net;
   W. Richard Stevens, "UNIX Network Programming" (1990;
   the calls above in the third edition's volume 1, 2003, chapter 4,
   "Elementary TCP Sockets");
   RFC 793 (TCP) and RFC 791 (IP), Jon Postel (1981). *)

(* ix: the seconds of silence after which a read gives up *)
val timeout : float

(* a connection to [host] (a name, or an address: "127.0.0.1")
 * on [port], each of its addresses tried in turn; raises Unix.Unix_error
 * (or Failure for a name that doesn't resolve) *)
val connect : < Cap.network; Cap.open_in; .. > -> host:string -> port:int -> Unix.file_descr

(* write all of [s] (a write may take only part of it) *)
val send_all : Unix.file_descr -> string -> unit

(* read until the other side closes the connection; Failure after
 * [timeout] seconds of silence *)
val receive_all : Unix.file_descr -> string

(* [exchange ~host ~port s]: connect, send [s], read everything the
 * other side sends until it closes, close: one request of a protocol
 * that closes after answering (HTTP with "Connection: close") *)
val exchange : < Cap.network; Cap.open_in; .. > -> host:string -> port:int -> string -> string
