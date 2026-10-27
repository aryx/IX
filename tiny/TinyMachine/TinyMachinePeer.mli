(* Tiny peer: the other end of tiny-machine's wire (plan_tiny_network.md),
 * what a host gives the machine to talk to. Not a second machine: the
 * host runs TinyKernelNetwork.ml, the stack tiny-kernel has, at the other
 * address (10.0.0.1), with no CPU under it, and a few lines on top:
 *
 *     the machine                              the host
 *
 *     tiny-kernel, 10.0.0.2                    the peer, 10.0.0.1
 *       TinyKernelNetwork.ml (by tiny-ml)      TinyKernelNetwork.ml (by OCaml)
 *            |                                        |      |
 *     the network's device  == send ==========>  [send]      [document]:
 *     (TinyMachineDevices)      <= give, later ====  [give]      a line to its
 *                                                            messages
 *
 * - a ping is answered (TinyKernelNetwork's own);
 * - on port 70, a connection's first message is a line, a document's
 *   name; the document is sent, a message at a time as the machine
 *   acknowledges, and the connection closed. One line out, a document
 *   back, the end: Gopher's shape (1991), and its port. The lines by
 *   the programs that write them: a name (get: a text), "www address"
 *   (www: a web page) and "img w h address" (www: a page's picture, its
 *   rows a message each, so that it is painted as it arrives);
 * - and the other way, "put name size" then the file's bytes (put):
 *   the host keeps the file, so that it outlives the machine, and the
 *   answer is a line, ok or why not.
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
 * (TinyMachineDevices's landed). So a run is the same each time. What is
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
type relay = {
  take : unit -> string option;
  put : string -> unit;
  shut : unit -> unit;
}
type outside = {
  name : string -> string;
  connect : string -> int -> relay option;
}

(* The peer. [give after packet]: the machine's net_give, a packet to
 * land so many instructions from now. [said dir packet]: each packet
 * that crosses, for who watches (">" from the machine, "<" to it, "x"
 * to it and lost). [document line messages]: what the line names,
 * given to [messages] once, now or later. [store name bytes]: a file
 * the machine put (tiny-kernel's put: a first line "put name size",
 * then its bytes), to keep where [document] finds it again; "" when it
 * is kept, why not otherwise, which put says. The empty line, Gopher's
 * menu, is [document]'s too: what was put, a name a line. *)
val create :
  give:(int -> string -> unit) ->
  said:(string -> string -> unit) ->
  document:(string -> (string list -> unit) -> unit) ->
  store:(string -> string -> string) -> outside:outside option -> t

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

(* a text as messages, of TinyKernelNetwork.il_max bytes at most *)
val messages : string -> string list

(* The line "www address" asks for a web page, for tiny-kernel's browser
 * (plan_tiny_browser.md). The peer answers with the page's bytes as the
 * site sent them, a message at a time, and an error as one line of
 * text. Fetching is the host's (a terminal's helper, or a page's
 * fetch), but where to fetch is decided here, the same for both:
 * [www_address] turns what was typed into a URL. A bare title (OCaml,
 * Plan 9 from Bell Labs) is an English Wikipedia article; a name with a
 * dot and no scheme (example.com) is https://; ?words a search
 * (TinyBrowserAddress.absolute, www's own rules). A Wikipedia article's
 * address (/wiki/X) becomes its REST HTML (/api/rest_v1/page/html/X):
 * the article without the site's menus, and the one a web page is
 * allowed to fetch. A #fragment is dropped. [www_kept] is the name of
 * the file that holds a kept copy of a Wikipedia article (X.html), for
 * the tests and for a machine with no way out. *)
val www_address : string -> string
val www_kept : string -> string option

(* The line "img w h address" asks for a picture of the page, w by h
 * pixels: the answer is [picture "" w h pixels] (below), with w and h 0
 * when there is none. The host decodes it and makes it that size, in
 * the machine's colours. [www_picture_kept] is the name of the file that
 * holds a kept copy: the address's last part, without its ?query
 * (250px-OCaml_Logo.svg.png). *)
val www_picture_kept : string -> string option

(* What "img w h address" is answered: a first message "t w h", then t
 * messages of text, then h messages of w bytes, a row of the picture
 * each, a byte a pixel in the screen's 256 colours (w no more than a
 * message's bytes; 0 0 with no picture). [picture text w h pixels]
 * makes them. *)
val picture : string -> int -> int -> string -> string list

(* How many instructions a packet takes to cross the wire (5 ms of the
 * machine's time), and how many pass between two of the peer's looks at
 * its clock (2.5 ms, a tick of tiny-kernel). Both depend on the
 * machine's speed, TinyMachineDevices.rate. *)
val latency : unit -> int
val tick : unit -> int

(* an address said ("10.0.0.2"); a packet in a few words, for who
 * watches the wire (-net-trace, the page's wire): the host's, which
 * the kernel has no use for *)
val net_dotted : string -> string
val net_describe : string -> string
