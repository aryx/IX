(* Tiny network: what a kernel needs to talk over tiny-machine's wire,
 * the essential of a network stack (ix's twins are mini-9pi's
 * kernels/9pi/network/ip/, the twin of Plan 9's, and the programs'
 * lib_networking/). Not a program: TinyKernel.ml's part that speaks to
 * the network (plan_tiny_network.md), in tiny-ml's ML, which is OCaml's
 * too, so that it is tested on the host first; and, by OCaml, the
 * other end of the wire in TinyMachine.ml:
 *
 *     tiny-ml -tm -o kernel.tm memory.ml TinyGraphics.ml TinyNetwork.ml TinyKernel.ml   (TinyKernel/Makefile)
 *     dune build ./tiny/tests/TinyNetwork_tests/Host.exe      (TinyNetwork_test.sh)
 *     ./tiny-machine -net dir -net-trace tiny-kernel          then: ping
 *
 * The idea kept: {b the stack is functions of strings}. A packet is a
 * string; a packet that came gives the packets to send back and what a
 * program is to hear. Nothing here reads a device, keeps a clock or
 * knows who calls. So the same file is three things: the kernel's
 * stack (TinyKernel.ml takes the packets from the machine's device and
 * gives them here), the host's test of it (no machine), and the wire's
 * other end (TinyMachine.ml's -net: the host answering with this very
 * code, where mini-qemu needed a second stack, raspberry/Usernet).
 *
 * What is here so far, a ping's way there and back:
 *
 *     tiny-kernel, 10.0.0.2                      the host, 10.0.0.1
 *
 *     ping: write "ping"
 *        | icmp_message: an echo's question
 *        | ip_packet: the envelope
 *     the device: send  ======= the wire =======>  net_input:
 *                                                    ip_read (for me?)
 *                                                    icmp_read (a question)
 *     net_input:        <====== the wire ========  the answer, in its
 *       ip_read, icmp_read: an answer                envelope
 *        | (who, the numbers, the bytes)
 *     ping: read "ping"
 *
 * A packet, byte by byte (a ping of four bytes: 32 in all):
 *
 *     IP's header, 20 bytes                 what it carries: ICMP, 8 and the bytes
 *     45 00 | 00 20 | 00 00 00 00 | 40 | 01 | sum | 10.0.0.2 | 10.0.0.1 | 08 00 | sum | id | seq | p i n g
 *     version  the    no fragment  hops what  the   from       to         echo?   its   whose  which
 *     4, five  whole               left it is header's                            own   ping   one
 *     words    length                   ICMP  check                               check
 *
 * What is left out, each because the wire has two ends and one
 * program at each: Ethernet and its addresses, ARP (who has this
 * address?), routes, fragments (a packet cut to pass a narrow road),
 * options, the hops counted down. A packet that is not well made or
 * not for us is dropped without a word.
 *
 * An address is its four bytes in a string, and every number is of 16
 * bits: tiny-ml's int has 31, and nothing here needs more.
 *
 * To come (plan_tiny_network.md's step 3): IL, Plan 9's protocol for
 * messages that arrive once and in order over a wire that loses.
 *
 * cs-history:
 * IP is Cerf and Kahn's (1974), split from TCP in 1978 so that what
 * needs no reliability (a voice, a question and its answer) need not
 * pay for it: an envelope with two addresses, each network free to
 * carry it its own way, nothing promised. The echo is ICMP's (RFC
 * 792, 1981), and ping is Mike Muuss's program of 1983, named after
 * sonar.
 *
 * design:
 * The checksum is the one the Internet has had since then (RFC 1071):
 * 16-bit numbers added, the carries added back. It is weak (two words
 * swapped are not seen) and kept because it is cheap, on any machine,
 * in any order of bytes; a wire that damages more than that has its
 * own check below.
 *
 * References: RFC 791 (IP), RFC 792 (ICMP), RFC 1071 (the checksum);
 * Presotto and Winterbottom, "The IL Protocol" (Plan 9's manual,
 * volume 2). *)

(* an address, its four bytes; "" when the text is not one *)
val net_address : string -> string
val net_dotted : string -> string

(* the machine's address and its host's, at the wire's two ends *)
val net_machine : string
val net_peer : string

(* 16 bits, the high byte first; the Internet's checksum of some bytes *)
val net16 : int -> string
val net_get16 : string -> int -> int
val net_sum : string -> int

(* IP: a packet (what it carries, from, to, the bytes), and one that
 * came read for an address: what it carries, who sent it, the bytes *)
val ip_icmp : int
val ip_packet : int -> string -> string -> string -> string
val ip_read : string -> string -> (int * string * string) option

(* ICMP's echo: a message (its kind, whose, which one, the bytes), read *)
val icmp_ask : int
val icmp_answer : int
val icmp_message : int -> int -> int -> string -> string
val icmp_read : string -> (int * int * int * string) option

(* A packet that came, for who has this address: the packets to send
 * back, and an echo's answer for who asked (who answers, the two
 * numbers, the bytes). The stack's heart. *)
val net_input : string -> string -> string list * (string * int * int * string) option

(* a packet in a few words, for who watches the wire *)
val net_describe : string -> string
