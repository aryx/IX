(* Tiny peer: the other end of tiny-machine's wire (plan_tiny_network.md),
 * what a host gives the machine to talk to. Not a second machine: the
 * host runs TinyNetwork.ml, the stack tiny-kernel has, at the other
 * address (10.0.0.1), with no CPU under it, and a few lines on top:
 *
 *     the machine                              the host
 *
 *     tiny-kernel, 10.0.0.2                    the peer, 10.0.0.1
 *       TinyNetwork.ml (by tiny-ml)              TinyNetwork.ml (by OCaml)
 *            |                                        |      |
 *     the network's device  == send ==========>  [send]      [document]:
 *     (TinyLibMachine)      <= give, later ====  [give]      a line to its
 *                                                            messages
 *
 * - a ping is answered (TinyNetwork's own);
 * - on port 70, a connection's first message is a line, a document's
 *   name; the document is sent, a message at a time as the machine
 *   acknowledges, and the connection closed. One line out, a document
 *   back, the end: Gopher's shape (1991), and its port.
 *
 * Where a document comes from is the host's, the one thing a terminal
 * and a page do differently: [document] is given the line and a
 * function to call with the messages, now (a file read) or later (a
 * page's fetch).
 *
 * Time is the machine's, in instructions: a packet of the peer's
 * lands [latency] after it was sent, and the peer's own clock (IL asks
 * again when nothing came) is an empty packet it gives itself, which
 * the machine returns to [send] a tick later and no kernel sees
 * (TinyLibMachine's landed). So a run is the same each time. What is
 * lost is said, not drawn at random: [lose].
 *
 * mini-qemu's wire has a second stack at its other end, written for
 * it (raspberry/Usernet); this one is the first again. *)

type t

(* The peer. [give after packet]: the machine's net_give, a packet to
 * land so many instructions from now. [said dir packet]: each packet
 * that crosses, for who watches (">" from the machine, "<" to it, "x"
 * to it and lost). [document line messages]: what the line names,
 * given to [messages] once, now or later. *)
val create : give:(int -> string -> unit) -> said:(string -> string -> unit) -> document:(string -> (string list -> unit) -> unit) -> t

(* the machine's [send]: a packet of its kernel's ("": the peer's own
 * clock) *)
val send : t -> string -> unit

(* the n-th packet the peer sends from now (1: the next) is lost *)
val lose : t -> int -> unit

(* a text as messages, of TinyNetwork.il_max bytes at most *)
val messages : string -> string list

(* the instructions a packet takes (5 ms of the machine's time), and
 * between two of the peer's looks at its clock (a tick of tiny-kernel) *)
val latency : int
val tick : int
