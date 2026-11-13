(* Tiny network is what a kernel needs to talk over tiny-machine's
 * wire: the essence of a network stack. Its twins in ix are mini-9pi's
 * kernels/9pi/network/ip/, which is itself the twin of Plan 9's, and
 * lib_networking/ for the programs. This is not a program. It is the part of
 * the kernel that speaks to the network (plan_tiny_network.md), and
 * also the other end of the wire, in TinyMachine.ml:
 *
 *     ./tiny-machine -net tiny/tests/www -net-trace tiny-kernel
 *         then: ping, get il.txt
 *
 * There are two things here. The first is IP and ICMP, shown by a
 * ping going there and back:
 *
 *     tiny-kernel, 10.0.0.2                      the host, 10.0.0.1
 *
 *     ping: write "ping"
 *        | icmp_message: an echo request
 *        | ip_packet: the envelope
 *     the device: send  ======= the wire =======>  net_input:
 *                                                    ip_read (for me?)
 *                                                    icmp_read (a request)
 *     net_input:        <====== the wire ========  the reply, in its
 *       ip_read, icmp_read: a reply                  envelope
 *        | (who, the numbers, the bytes)
 *     ping: read "ping"
 *
 * A packet, byte by byte (a ping of four bytes, 32 bytes in all):
 *
 *     IP's header, 20 bytes
 *     45 00 | 00 20 | 00 00 00 00 | 40 | 01 | sum | 10.0.0.2 | 10.0.0.1
 *     version total   no fragment  hops 1 is  header from      to
 *     4, five length               left ICMP  checksum
 *     words
 *
 *     what it carries: ICMP, 8 bytes, then the data
 *     08 00 | sum | id | seq | p i n g
 *     echo    its   whose  which
 *     request own   ping   one
 *             checksum
 *
 * An address is kept as its four bytes in a string, because nothing is
 * ever computed on one, and tiny-ml's int has only 31 bits.
 *
 * The second thing is {b IL}, Plan 9's protocol that makes the wire
 * reliable. A program writes messages and reads messages; each message
 * arrives once and in the order written, or else the connection ends.
 * Here is all of it:
 *
 * - A connection is opened by a sync in each direction, in which each
 *   end gives the number its messages start from.
 * - Each message has a number (its id), one more than the one before.
 *   A message that comes twice is recognized by its id and dropped; a
 *   message that comes early is kept until the one before it arrives.
 * - Every packet carries the last number that its sender's program
 *   has read (its ack). The other end can then forget those messages,
 *   and a writer is never more than 20 messages ahead of its reader.
 * - Nothing is sent again blindly. An end that has heard no ack for a
 *   while asks (query); the other end answers with what it received
 *   (state); and the oldest message missing there is sent again, itself
 *   as a question (data?). So a program that merely reads slowly
 *   causes no resending.
 * - close ends the connection, and is sent only when everything
 *   written has arrived.
 *
 * A lost message, as tiny-machine -net-lose makes it happen and
 * -net-trace prints it:
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
 * An IL packet, after IP's 20 bytes (IP's protocol number for IL is
 * 40):
 *
 *     sum | length | kind | 00 | from port | to port | id, 4 bytes |
 *     of all, message      one of seven: sync 0, data 1, data? 2,
 *     included             ack 3, query 4, state 5, close 6
 *     ack, 4 bytes | the message
 *
 * One end of a connection is in one of five states:
 *
 *     Il_syncer  --- the other's sync --->  Il_established
 *     (dialed)                                ^      |
 *     Il_syncee  --- an ack, or data ---------+      | close sent
 *     (was dialed)                                   | or received
 *                                                    v
 *                                               Il_closing --> Il_closed
 *                                                         (both sent close)
 *                       from any state, after giving up: Il_closed
 *
 * The same two functions run the protocol at both ends: [net_input]
 * when a packet comes, and [net_tick] when time passes. Time is just a
 * number that the caller gives: the kernel's ticks, or a test's loop
 * counter. So the test (KNetwork_tests/Host.ml) is simply two stacks
 * and a list between them that loses packets, chosen by a seed; it
 * checks that every message arrives once and in order.
 *
 * Kept from Plan 9's il.c (principia's kernel/network/ip/il.c, 1,551
 * lines): the header and its numbers, the seven kinds of packet, the
 * window of 20 messages, the query before resending, and resending
 * only what was sent before the query.
 * Changed:
 * - An ack gives what the program has read. il.c's ack gives what was
 *   received, and il.c drops what its reader has no room for. (A state
 *   and a close here still give what was received.)
 * - The wait is fixed. It is 0.1 s, doubled each time, and the end
 *   gives up after six tries with nothing heard. il.c measures the
 *   round trip instead.
 * - The close is sent only when what was written has arrived (il.c
 *   drops what has not).
 * - The last of the four closes is not sent.
 * Left out: the query that il.c sends every ten seconds on a
 * connection where nothing is owed. So an end that is waiting to read
 * does not notice that the other end went silent; it does notice when
 * the other end closes, which giving up does.
 *
 * IL's numbers have 32 bits and tiny-ml's int has 31. Both ends here
 * start small and stay under 2^30; a packet with a larger number is
 * not read.
 *
 * twin:
 * mini-9pi's stack (kernels/9pi/network/: Ip, Icmp, Udp, Tcp, and
 * Devip's files) speaks to the Internet. It has Ethernet and ARP,
 * routes, UDP for name lookups and the time, and TCP (the twin of
 * principia's tcp.c, a stream of bytes; it has no IL). A program
 * reaches it through Plan 9's files, /net/tcp/clone with its ctl and
 * data files, which libc's dial writes. Here there is only IL, since a
 * request, a disk block or a drawing message is already a message. A
 * program reaches it by two of TinyKernel's system calls,
 * dial(address, port) and listen(port), each giving a descriptor of
 * messages; port 0 is the echo (ping). The world, which speaks TCP, is
 * reached through the wire's other end (TinyMachinePeer, which
 * translates).
 *
 * dropped:
 * Each of these is left out because the wire has two ends and one
 * program at each: Ethernet and its addresses, ARP (who has this
 * address?), routes, fragments (a packet cut in pieces to pass a link
 * with smaller packets), IP options, and counting the hops down. A
 * packet that is malformed or not for us is dropped silently.
 *
 * twist:
 * {b The stack is functions on strings}, whereas mini-9pi's is tied to
 * its devices. A packet is a string; given a packet that came, the
 * stack returns the packets to send back and what a program is to
 * receive. Nothing here reads a device, keeps a clock or knows who
 * calls. So the same file serves three purposes:
 * - the kernel's stack (the kernel takes the packets from the
 *   machine's device and gives them here);
 * - the host's test of it, with no machine;
 * - the wire's other end (TinyMachine.ml's -net): the host answers
 *   with this very code, where mini-qemu needed a second stack
 *   (raspberry/Usernet).
 *
 * cs-history:
 * IP is Cerf and Kahn's (1974). It was split from TCP in 1978 so that
 * traffic that needs no reliability (a voice, a question and its
 * answer) need not pay for it. IP is just an envelope with two
 * addresses: each network is free to carry it its own way, and
 * nothing is promised. The echo is ICMP's (RFC 792, 1981), and ping is
 * Mike Muuss's program of 1983, named after sonar. IL is by Presotto
 * and Winterbottom, from Plan 9's first years, for 9P between Plan 9
 * machines. It gives TCP's guarantees for messages, in less than half
 * the code (il.c against tcp.c). Nothing else spoke it, and Plan 9's fourth
 * edition (2002) went back to TCP (from memory: IL did badly over long
 * distances and through address translation).
 *
 * design:
 * The checksum is the one the Internet has used since then (RFC 1071):
 * add the 16-bit numbers, then add the carries back. It is weak (it
 * does not see two swapped words), and it is kept because it is cheap
 * on any machine and in any byte order; a link that damages more than
 * that has its own check below IP.
 *
 * references:
 *  - RFC 791: IP
 *  - RFC 792: ICMP
 *  - RFC 1071: the checksum
 *  - Presotto and Winterbottom, "The IL Protocol" (Plan 9's manual,
 *    volume 2)
 *)

(* An address is four bytes in a string. [net_address text] is "" for a
 * bad text. *)
type ip_addr = string
val net_address : string -> ip_addr

(* These are the addresses of the machine and of its host, at the two
 * ends of the wire. *)
val net_machine : ip_addr
val net_peer : ip_addr

(* 16-bit numbers are high byte first. *)
val net16 : int -> string
val net_get16 : string -> int -> int
val net_sum : string -> int

(* IP. [ip_read me p] is None unless p is for address me; else it gives
 * the protocol, the sender and the bytes. *)
val ip_icmp : int
val ip_packet : int -> ip_addr -> ip_addr -> string -> string
val ip_read : ip_addr -> string -> (int * ip_addr * string) option

(* ICMP has an echo request (8) and an echo reply (0). A message has a
 * kind, an id (which ping), a sequence number and bytes. *)
type icmp_kind = Echo_ask | Echo_answer | Icmp_other of int
val icmp_message : icmp_kind -> int -> int -> string -> string
val icmp_read : string -> (icmp_kind * int * int * string) option

(* IL is IP's protocol 40. ih_ack is the last number received in order.
 * [il_read] is None for a packet cut short, damaged, or numbered over
 * 2^30. *)
val ip_il : int
type il_kind =
  | Il_sync | Il_data | Il_dataquery | Il_ack | Il_query | Il_state | Il_close
type il_header =
  { ih_kind : il_kind; ih_sport : int; ih_dport : int; ih_id : int;
    ih_ack : int }
val il_message : il_header -> string -> string
val il_read : string -> (il_header * string) option

(* These types describe one end of a connection (KNetwork.ml explains
 * each field). *)
type il_at = Il_syncer | Il_syncee | Il_established | Il_closing | Il_closed

type il_sending = {
  mutable il_next : int; mutable il_unacked : (int * string) list;
  mutable il_leaving : bool; mutable il_asked : int;
  mutable il_timeout : int; mutable il_tries : int; mutable il_silent : int;
}

type il_receiving = {
  mutable il_rstart : int; mutable il_recvd : int; mutable il_told : int;
  mutable il_early : (int * string) list;
  mutable il_heard : string list;
}

type il = {
  il_me : ip_addr; il_peer : ip_addr; il_lport : int; il_rport : int;
  mutable il_at : il_at; il_start : int; il_s : il_sending;
  il_r : il_receiving;
}

(* The largest message in bytes, and the most messages one end holds
 * unacknowledged, or received and unread. *)
val il_max : int
val il_window : int

(* [il_room c] is true when c is established and fewer than [il_window]
 * messages wait for an ack. [il_write c msg time] returns the packet.
 * [il_hear] gives each message once, in order. [il_readable c] is true
 * when a message, or the end of the connection, is there to read. After
 * [il_done], [net_tick] sends the close once everything written has
 * arrived. *)
val il_room : il -> bool
val il_write : il -> string -> int -> string
val il_hear : il -> string option
val il_readable : il -> bool
val il_over : il -> bool
val il_done : il -> unit

(* A net_stack is the network state of one address. [ns_ports] is set by
 * listeners; [ns_fresh] holds connections not accepted yet. In
 * [net_stack addr start], the first connection's messages are numbered
 * from start, and each next connection's start is 1,000 further. A
 * gateway ([ns_gate]) leads to other machines: it reads packets for
 * other addresses, and answers a sync for one of [ns_others] (address
 * and port, once each) as that address would, which becomes the
 * connection's [il_me]. *)
type net_stack = {
  ns_me : ip_addr; mutable ns_conns : il list; mutable ns_ports : int list;
  mutable ns_fresh : il list; mutable ns_start : int;
  mutable ns_port : int; mutable ns_gate : bool;
  mutable ns_others : (ip_addr * int) list;
}

val net_stack : ip_addr -> int -> net_stack

(* [net_dial ns addr port time] also returns the packet to send. The
 * connection becomes Il_established when the other end agrees, and
 * Il_closed when it refuses or never answers. *)
val net_dial : net_stack -> ip_addr -> int -> int -> il * string

(* {b The heart of the stack} is these two functions. They read no
 * device and no clock, and they return the packets to send.
 * [net_input ns time packet] also returns an echo reply (who, the two
 * numbers, the bytes) for whoever pinged. [net_tick ns time] runs at
 * each tick of the caller's clock (IL waits 40 ticks, then twice that,
 * and so on). *)
val net_input :
  net_stack -> int -> string ->
  string list * (ip_addr * int * int * string) option
val net_tick : net_stack -> int -> string list
