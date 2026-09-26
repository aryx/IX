(* claude: the network behind a usb-net, as QEMU's user networking
 * (slirp) looks from the guest: the guest 10.0.2.15, the host and
 * gateway 10.0.2.2 (MAC 52:55:0a:00:02:02). ARP answered for 10.0.2.2,
 * an ICMP echo to it too (TTL 255, as QEMU's), a TCP connection to it
 * made to the host's 127.0.0.1 on the same port (refused: a RST), the
 * data relayed both ways in order, each side's FIN passed on. No
 * retransmission (the guest's link is this process: nothing is lost),
 * no UDP, no DNS, no connection from the host. *)

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
