(* Tiny peer: the other end of tiny-machine's wire (plan_tiny_network.md),
 * what a host gives the machine to talk to. Not a second machine: the
 * host runs TinyLibNetwork.ml, the stack tiny-kernel has, at the other
 * address (10.0.0.1), with no CPU under it, and a few lines on top:
 *
 *     the machine                              the host
 *
 *     tiny-kernel, 10.0.0.2                    the peer, 10.0.0.1
 *       TinyLibNetwork.ml (by tiny-ml)              TinyLibNetwork.ml (by OCaml)
 *            |                                        |      |
 *     the network's device  == send ==========>  [send]      [document]:
 *     (TinyLibMachine)      <= give, later ====  [give]      a line to its
 *                                                            messages
 *
 * - a ping is answered (TinyLibNetwork's own);
 * - on port 70, a connection's first message is a line, a document's
 *   name; the document is sent, a message at a time as the machine
 *   acknowledges, and the connection closed. One line out, a document
 *   back, the end: Gopher's shape (1991), and its port. Two kinds of
 *   lines by the programs that write them: a name (get: a text), and
 *   "wiki" then words (wiki: a text and a picture, its rows a message
 *   each, so that the program paints it as it arrives).
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

(* A way to a program that is not on the wire, which a host may have
 * (a terminal's: a socket; a page has none). A relay is one
 * connection's: the bytes that came from there ("" when none has,
 * None at its end), bytes sent there, its end. With an [outside] the
 * peer is a gateway: a connection the machine asks for to any other
 * address is asked of [connect] (an address as text, a port; None:
 * nothing answers), and its messages go there as bytes and come back
 * as messages, cut where the bytes happened to arrive: the machine
 * speaks IL, the outside TCP, and a program that reads lines must not
 * take a message for one. And port 53 of the peer answers a name by
 * its address as text, from [name] ("" when it has none), which is
 * all there is of DNS. *)
type relay = { take : unit -> string option; put : string -> unit; shut : unit -> unit }
type outside = { name : string -> string; connect : string -> int -> relay option }

(* The peer. [give after packet]: the machine's net_give, a packet to
 * land so many instructions from now. [said dir packet]: each packet
 * that crosses, for who watches (">" from the machine, "<" to it, "x"
 * to it and lost). [document line messages]: what the line names,
 * given to [messages] once, now or later. *)
val create :
  give:(int -> string -> unit) -> said:(string -> string -> unit) -> document:(string -> (string list -> unit) -> unit) ->
  outside:outside option -> t

(* the machine's [send]: a packet of its kernel's ("": the peer's own
 * clock) *)
val send : t -> string -> unit

(* What the host does between two packets: the relays have their turn
 * (called often enough, a relay's bytes do not wait for the machine to
 * send something). And a connection from the outside to a port of the
 * machine's, where a program of its listens: the relay is its other
 * side (a host's -net-forward). *)
val poll : t -> unit
val dial : t -> int -> relay -> unit

(* the n-th packet the peer sends from now (1: the next) is lost *)
val lose : t -> int -> unit

(* a text as messages, of TinyLibNetwork.il_max bytes at most *)
val messages : string -> string list

(* What "wiki words" is answered: a first message "t w h", then t
 * messages of text, then h messages of w bytes, a row of the picture
 * each, a byte a pixel in the screen's 256 colours (w no more than a
 * message's bytes; 0 0 with no picture). [picture text w h pixels]
 * makes them; [kept] reads a picture kept in a file, already reduced
 * (a line "w h", the pixels, the text; None when it is not one). *)
val picture : string -> int -> int -> string -> string list
val kept : string -> string list option

(* the instructions a packet takes (5 ms of the machine's time), and
 * between two of the peer's looks at its clock (a tick of tiny-kernel) *)
val latency : int
val tick : int
