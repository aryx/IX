(* This is the network behind a usb-net, as QEMU's user networking
 * (slirp) looks from the guest. The guest is 10.0.2.15, and the host
 * and gateway is 10.0.2.2 (MAC 52:55:0a:00:02:02). ARP is answered
 * for 10.0.2.2, and so is an ICMP echo to it (with TTL 255, as in
 * QEMU). A TCP connection to it is made to the host's 127.0.0.1 on the
 * same port (if that is refused, the guest gets a RST). The data is
 * relayed both ways in order, and each side's FIN is passed on. Beyond
 * the gateway, as in slirp, a TCP connection to any other address is
 * made by the host to that address. A UDP datagram is sent from one of
 * the host's sockets, and the answers are brought back. 10.0.2.3 is
 * the name server, which is the host's own (from /etc/resolv.conf), so
 * a guest that has UDP resolves names. There is no retransmission
 * (the guest's link is this process, so nothing is lost), no
 * connection from the host, and no ping beyond the gateway.
 *
 * The guest's kernel has a whole network stack, and sends Ethernet
 * frames. The host gives an ordinary program sockets, not frames. So
 * this module is the other end of every conversation at once. It plays
 * the gateway's network card, and for each TCP connection that the
 * guest opens, it is a TCP peer on one side and the owner of a host
 * socket on the other.
 *
 *     guest's stack                 here                 the host
 *     ARP who has 10.0.2.2?  ->     "I do" (a made-up MAC)
 *     SYN to 10.0.2.2:80     ->     connect 127.0.0.1:80
 *                            <-     SYN+ACK (or RST: refused)
 *     data, seq n            ->     write to the socket; ACK back
 *                            <-     data read from the socket,
 *     ACK                    ->     under our own sequence numbers
 *     FIN                    ->     shutdown; and the socket's end
 *                            <-     of file is our FIN
 *
 * What a real TCP spends most of its code on is absent, and rightly so.
 * A frame handed over in the same process is never lost, late or out
 * of order, so there is no timer, no retransmission and no congestion
 * control. It is a way to see TCP's skeleton, the handshake and the
 * numbering of bytes, without what makes it hard.
 *
 * cs-history:
 * QEMU's user networking is slirp, a program of 1995 that gave a
 * TCP/IP connection to a home computer over a dial-up shell account,
 * with no privilege on the host: it answered the home machine's
 * packets with its own socket calls. The same trick suited an
 * emulator that should need no root and no network device on the
 * host, and 10.0.2.15 and 10.0.2.2 are still its defaults.
 *
 * others:
 * The other way to network a guest is to give it real frames, through
 * a tap device or a bridge on the host. Then the guest is a machine on
 * the network, reachable from outside, at the price of privileges and
 * of configuration on the host. *)

type t

(* [create send] makes a network that gives the frames for the guest to
 * [send] *)
val create : (string -> unit) -> t

(* a frame from the guest *)
val input : t -> string -> unit

(* [poll] polls the host's side, and passes the data from the
 * connections to the guest *)
val poll : t -> unit

(* [usb] makes the device of -device usb-net on [path], with its network.
 * [poll_all] polls every network (from mini-qemu's main loop). *)
val usb : path:string -> Usb.device
val poll_all : unit -> unit

(* the host's name server, which 10.0.2.3 stands for (127.0.0.1 until
 * set) *)
val resolver : Unix.inet_addr ref

(* the host's clock, which Main sets from its Cap.clock (it gives 0
 * before) *)
val clock : (unit -> float) ref

(* for whoever watches (Monitor): what every network carried since the
 * start (the frames' bytes in each direction), the connections and UDP
 * conversations it holds, and the last things that happened ("tcp
 * 93.184.216.34:80", "udp 10.0.2.3:53", "refused ..."), the newest
 * first *)
type totals = { from_guest : int; to_guest : int; tcp : int; udp : int; events : string list }
val totals : unit -> totals
