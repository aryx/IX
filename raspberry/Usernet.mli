(* The network behind a usb-net, as QEMU's user networking
 * (slirp) looks from the guest: the guest 10.0.2.15, the host and
 * gateway 10.0.2.2 (MAC 52:55:0a:00:02:02). ARP answered for 10.0.2.2,
 * an ICMP echo to it too (TTL 255, as QEMU's), a TCP connection to it
 * made to the host's 127.0.0.1 on the same port (refused: a RST), the
 * data relayed both ways in order, each side's FIN passed on. And
 * beyond the gateway, as slirp: a TCP connection to any other address
 * is one of the host's to that address; a UDP datagram is sent from a
 * socket of the host's and the answers brought back; 10.0.2.3 is the
 * name server, the host's own (/etc/resolv.conf's), so a guest that
 * has UDP resolves names. No retransmission (the guest's link is this
 * process: nothing is lost), no connection from the host, no ping
 * beyond the gateway.
 *
 * The guest's kernel has a whole network stack, and sends Ethernet
 * frames; the host gives an ordinary program sockets, not frames.
 * So this module is the other end of every conversation at once: it
 * plays the gateway's network card, and for each TCP connection the
 * guest opens it is a TCP peer on one side and the owner of a host
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
 * What a real TCP spends most of its code on is absent, and rightly:
 * a frame handed over in the same process is never lost, late or
 * out of order, so there is no timer, no retransmission and no
 * control of congestion. It is a way to see TCP's skeleton, the
 * handshake and the numbering of bytes, without what makes it hard.
 *
 * cs-history:
 * QEMU's user networking is slirp, a program of 1995 that gave
 * a TCP/IP connection to a home computer over a dial-up shell
 * account, with no privilege on the host: it answered the home
 * machine's packets with its own socket calls. The
 * same trick suited an emulator that should need no root and no
 * network device on the host, and 10.0.2.15 and 10.0.2.2 are its
 * defaults still.
 *
 * others:
 * The other way to network a guest is to give it real frames: a tap
 * device or a bridge on the host, and the guest is a machine on the
 * network, reachable from outside, at the price of privileges and
 * of configuration on the host. *)

type t

(* [create send]: frames for the guest given to send *)
val create : (string -> unit) -> t

(* a frame from the guest *)
val input : t -> string -> unit

(* the host's side polled: data from the connections to the guest *)
val poll : t -> unit

(* -device usb-net on [path]: the device, its network made; every
 * network polled (mini-qemu's main loop) *)
val usb : path:string -> Usb.device
val poll_all : unit -> unit

(* the host's name server, which 10.0.2.3 stands for (127.0.0.1 until
 * set) *)
val resolver : Unix.inet_addr ref

(* for who watches (Monitor): what every network carried since the
 * start (the frames' bytes each way), the connections and UDP
 * conversations it holds, and the last things that happened ("tcp
 * 93.184.216.34:80", "udp 10.0.2.3:53", "refused ..."), the newest
 * first *)
type totals = { from_guest : int; to_guest : int; tcp : int; udp : int; events : string list }
val totals : unit -> totals
