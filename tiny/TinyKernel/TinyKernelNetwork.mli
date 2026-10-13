(* Tiny network: what a kernel needs to talk over tiny-machine's wire,
 * the essential of a network stack (ix's twins are mini-9pi's
 * kernels/9pi/network/ip/, the twin of Plan 9's, and the programs'
 * lib_networking/). Not a program: TinyKernel.ml's part that speaks to
 * the network (plan_tiny_network.md), in tiny-ml's ML, which is OCaml's
 * too, so that it is tested on the host first; and, by OCaml, the
 * other end of the wire in TinyMachine.ml:
 *
 *     tiny-ml -tm -o kernel.tm memory.ml TinyKernelGraphics.ml TinyKernelNetwork.ml TinyKernel.ml   (TinyKernel/Makefile)
 *     dune build ./tiny/tests/TinyKernelNetwork_tests/Host.exe      (TinyKernelNetwork_test.sh)
 *     ./tiny-machine -net tiny/tests/www -net-trace tiny-kernel     then: ping, get il.txt
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
 * Two things are here. The first, a ping's way there and back:
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
 * An address is its four bytes in a string: nothing is computed on
 * one, and tiny-ml's int has 31 bits.
 *
 * The second: {b IL}, Plan 9's protocol, which makes the wire
 * reliable. A program writes messages and reads messages; each arrives
 * once, in the order written, or the connection ends. All of it:
 *
 * - a connection is opened by a sync each way, each end saying the
 *   number its messages start from;
 * - a message has a number (its id), one more than the one before;
 *   what comes twice is known by it and dropped, what comes early is
 *   kept until the one before arrives;
 * - every packet says the last number its sender's program took (its
 *   ack): what the other end has is forgotten here, and who writes is
 *   never more than 20 messages ahead of who reads;
 * - nothing is sent again blindly: who has heard no ack for a while
 *   asks (query), the other end says what it received (state), and
 *   the oldest message missing there is sent again, as a question too
 *   (data?); a program that only reads slowly has nothing sent again;
 * - close ends it, said when all that was written has arrived.
 *
 * A message lost (tiny-machine -net-lose, as -net-trace says it):
 *
 *     > sync   id 1000 ack 0              "may I talk to your port 70?"
 *     < sync   id 5000 ack 1000           "yes"
 *     > ack    id 1001 ack 5000
 *     > data   id 1001 ack 5000, 4 bytes  the request, a message
 *     < data   id 5001 ack 1001           the answer's first message
 *     < data   id 5002 ack 1001
 *     x data   id 5003 ack 1001           its third, lost
 *     < data   id 5004 ack 1001           (kept: 5003 is not there)
 *     < data   id 5005 ack 1001
 *     > ack    id 1002 ack 5002           "my program read up to 5002"
 *     < query  id 5006 ack 1001           (0.1 s after) "where are you?"
 *     > state  id 1002 ack 5002           "I received up to 5002"
 *     < data?  id 5003 ack 1001           sent again, and "now?"
 *     > state  id 1002 ack 5005           "up to 5005"
 *     > ack    id 1002 ack 5005           "and my program read them"
 *     < close  id 5006 ack 1001           "I am done"
 *     > close  id 1002 ack 5006           "so am I"
 *     < close  id 5006 ack 1002           "heard"
 *
 * Its packet, after IP's 20 bytes (IP's number for it is 40):
 *
 *     sum | length | kind | 00 | from port | to port | id, 4 bytes | ack, 4 bytes | the message
 *     of all, with the      one of seven: sync 0, data 1, data? 2,
 *     message               ack 3, query 4, state 5, close 6
 *
 * One end of a connection is in one of five places:
 *
 *     Il_syncer  --- the other's sync --->  Il_established  --- close said --->  Il_closing --> Il_closed
 *     (dialed)                                ^                  or heard          (said by both)
 *     Il_syncee  --- an ack, or data ---------+
 *     (was dialed)                    any of them, patience over: Il_closed
 *
 * The same two functions run it at both ends ([net_input]: a packet
 * came; [net_tick]: time passed), and time is a number their caller
 * gives: the kernel's ticks, a test's loop. So two of these and a
 * list between them that loses by a seed is the test
 * (TinyKernelNetwork_tests/Host.ml): every message once and in order.
 *
 * Kept from Plan 9's il.c (principia's kernel/network/ip/il.c, 1,551
 * lines): the header and its numbers, the seven kinds, the window of
 * 20 messages, the query before sending again, only what was sent
 * before the query sent again. Changed: an ack says what the program
 * took, where il.c's says what was received and drops what its reader
 * has no room for (a state and a close still say what was received); the wait is fixed (0.1 s,
 * twice that each time, over after six with nothing heard) where il.c
 * measures the round trip; the end is said only when what was written has
 * arrived (il.c drops it); the last close of four is not sent. Left
 * out: the query every ten seconds of a connection where nothing is
 * owed, so an end that waits to read does not notice the other gone
 * silent (it does when the other says the end, which giving up does).
 *
 * A number of IL's has 32 bits and tiny-ml's int 31: both ends here
 * start small and stay under 2^30; a packet with more is not read.
 *
 * cs-history:
 * IP is Cerf and Kahn's (1974), split from TCP in 1978 so that what
 * needs no reliability (a voice, a question and its answer) need not
 * pay for it: an envelope with two addresses, each network free to
 * carry it its own way, nothing promised. The echo is ICMP's (RFC
 * 792, 1981), and ping is Mike Muuss's program of 1983, named after
 * sonar. IL is Presotto and Winterbottom's, of Plan 9's first years,
 * for 9P between its machines: TCP's guarantees for messages, in less
 * than half its code (il.c against tcp.c). Nothing else spoke it, and
 * Plan 9's fourth edition (2002) went back to TCP (from memory: IL
 * did badly on long roads and through address translation).
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

(* IL (IP's number 40). A packet: its kind (one of seven), the sender's
 * port, the other's, its number, the last number its sender received
 * in order, a message; read back, None when cut, damaged, or its
 * numbers over 2^30 *)
val ip_il : int
val il_sync : int
val il_data : int
val il_dataquery : int
val il_ack : int
val il_query : int
val il_state : int
val il_close : int
val il_message : int -> int -> int -> int -> int -> string -> string
val il_read : string -> (int * int * int * int * int * string) option

(* One end of a connection: where it is, what it sends, what it
 * receives (TinyKernelNetwork.ml says each field) *)
type il_at = Il_syncer | Il_syncee | Il_established | Il_closing | Il_closed

type il_sending = {
  mutable il_next : int; mutable il_unacked : (int * string) list; mutable il_leaving : bool; mutable il_asked : int;
  mutable il_timeout : int; mutable il_tries : int; mutable il_silent : int;
}

type il_receiving = {
  mutable il_rstart : int; mutable il_recvd : int; mutable il_told : int; mutable il_early : (int * string) list;
  mutable il_heard : string list;
}

type il = {
  il_me : string; il_peer : string; il_lport : int; il_rport : int; mutable il_at : il_at; il_start : int; il_s : il_sending;
  il_r : il_receiving;
}

(* a message's bytes at most; the messages one end holds at most, sent
 * and not acknowledged or received and not read *)
val il_max : int
val il_window : int

(* A program's part of a connection. Whether a message may be written
 * now (the two ends talk, fewer than [il_window] wait to be
 * acknowledged), and one written at a time: its packet. The next
 * message that arrived, taken: each once, in the order written there;
 * whether a read would not wait (a message, or the end); whether
 * nothing more will come. The program done: the end is said, by
 * [net_tick], when all it wrote has arrived. *)
val il_room : il -> bool
val il_write : il -> string -> int -> string
val il_hear : il -> string option
val il_readable : il -> bool
val il_over : il -> bool
val il_done : il -> unit

(* What one address has: its connections, the ports it listens on
 * ([ns_ports], set by who listens), the connections others made there
 * that nobody took yet ([ns_fresh], taken off by who accepts). Made
 * for an address and the number its first connection's messages start
 * from (each connection's are 1,000 further). A gateway ([ns_gate]:
 * the wire's end that is the way to other machines) also reads what
 * is for other addresses, and answers a sync for one of [ns_others]
 * (an address, a port; once each) as that address would: the
 * connection's [il_me] is then that address, and what is at the
 * gateway's other side is its caller's. *)
type net_stack = {
  ns_me : string; mutable ns_conns : il list; mutable ns_ports : int list; mutable ns_fresh : il list; mutable ns_start : int;
  mutable ns_port : int; mutable ns_gate : bool; mutable ns_others : (string * int) list;
}

val net_stack : string -> int -> net_stack

(* a connection asked for, to an address and a port, at a time: it and
 * the packet to send. It is Il_established when the other end agreed,
 * Il_closed when it refused or never answered. *)
val net_dial : net_stack -> string -> int -> int -> il * string

(* {b The stack's heart}: two functions, which read no device and no
 * clock. A packet that came, at a time: the packets to send back, and
 * an echo's answer for who asked (who answers, the two numbers, the
 * bytes). Time passed (called at each tick of whoever counts: IL's
 * waits are 40 of them, then twice that): the packets to send. Both
 * change the connections: messages heard, a state, [ns_fresh]. *)
val net_input : net_stack -> int -> string -> string list * (string * int * int * string) option
val net_tick : net_stack -> int -> string list
