(* Tiny peer: the other end of tiny-machine's wire
 * (plan_tiny_network.md), what a host gives the machine to talk to. It
 * is not a second machine. The host runs KNetwork.ml, the same network
 * stack that tiny-kernel has, at the other address (10.0.0.1), with no
 * CPU under it, and adds a few lines on top:
 *
 *     the machine                              the host
 *
 *     tiny-kernel, 10.0.0.2                    the peer, 10.0.0.1
 *       KNetwork.ml (by tiny-ml)      KNetwork.ml (by OCaml)
 *            |                                        |      |
 *     the network's device  == send ==========>  [send]      [document]:
 *     (TinyMachineDevices)      <= give, later ====  [give]      a line to its
 *                                                            messages
 *
 * What the peer does:
 * - it answers a ping (KNetwork does that by itself);
 * - on port 70, the first message of a connection is a line naming a
 *   document. The peer sends the document, one message at a time as
 *   the machine acknowledges them, and closes the connection. One line
 *   out, a document back, then the end: this is Gopher's shape (1991),
 *   and Gopher's port. The programs on the machine send three kinds of
 *   lines:
 *   - a file name, from get, which wants a text;
 *   - "GET address HTTP/1.0", from www, which wants a web page; it is
 *     an HTTP request and is answered by an HTTP response;
 *   - "img w h address", from www, which wants a picture of a page; each
 *     row comes in its own message, so that the picture is painted as
 *     it arrives;
 * - in the other direction, put sends "put name size" then the file's
 *   bytes. The host keeps the file, so that it outlives the machine,
 *   and answers with a line, ok or the reason it failed.
 *
 * Where a document comes from is up to the host; it is the one thing a
 * terminal and a web page do differently. [document] is given the line
 * and a function to call with the messages, either at once (a file
 * read) or later (a page's fetch).
 *
 * Time is the machine's, counted in instructions. A packet from the
 * peer lands [latency] instructions after it was sent. The peer's own
 * clock (IL asks again when nothing came) is an empty packet that it
 * gives itself: the machine returns it to [send] a tick later, and no
 * kernel sees it (TinyMachineDevices's landed). So a run is the same
 * each time. For the same reason, which packets are lost is chosen
 * explicitly with [lose], not drawn at random.
 *
 * mini-qemu's wire has a second network stack at its other end, written
 * for it (raspberry/Usernet); here we reuse the machine's own stack. *)

type t

(* A way out to programs not on the wire: a terminal has a socket, a web
 * page has none. A relay is one connection. With an [outside], the peer
 * is a gateway: a connection to any other address goes to [connect]
 * (None: nothing answers), and the bytes coming back are cut into
 * messages wherever they arrived, so a program must not take a message
 * for a line. Port 53 of the peer answers a name with [name]'s address;
 * that is all there is of DNS. *)
type relay = {
  take : unit -> string option; (* "" when nothing came, None at the end *)
  put : string -> unit;
  shut : unit -> unit;
}
type outside = {
  name : string -> string; (* the address as text, "" when none *)
  connect : string -> int -> relay option;
}

(* [give after packet] is the machine's net_give. [said dir packet] shows
 * each packet that crosses (">" from the machine, "<" to it, "x" lost).
 * [document line messages] calls [messages] once, now or later; the
 * empty line, Gopher's menu, wants the names that were put. [store name
 * bytes] keeps a file sent by put, where [document] finds it again; it
 * returns "" or the reason it failed, which put prints. *)
val create :
  give:(int -> string -> unit) ->
  said:(string -> string -> unit) ->
  document:(string -> (string list -> unit) -> unit) ->
  store:(string -> string -> string) -> outside:outside option -> t

(* the machine's [send]; the packet "" is the peer's own clock *)
val send : t -> string -> unit

(* [poll], called between two packets, lets the relays send without
 * waiting for the machine. [dial] connects a relay to a port where a
 * program of the machine listens (a host's -net-forward). *)
val poll : t -> unit
val dial : t -> int -> relay -> unit

(* the n-th packet the peer sends from now (1: the next) is lost *)
val lose : t -> int -> unit

(* a text cut into messages of at most KNetwork.il_max bytes *)
val messages : string -> string list

(* A proxy's request "GET address HTTP/1.0" (TinyBrowser/Http.ml) gets an
 * HTTP/1.0 response: the site's status and headers (www goes by
 * Content-Type), then the page, chunks and gzip undone. The host
 * fetches, but where is decided here. [www_address] uses www's rules
 * (Url.absolute): a bare title (OCaml) is an English Wikipedia article,
 * a name with a dot gets https://, ?words is a search. An article
 * /wiki/X becomes /api/rest_v1/page/html/X, without the site's menus and
 * allowed to a web page; a #fragment is dropped. Kept copies serve the
 * tests and a machine with no way out: [www_kept] names X.html,
 * search-words.html, or the address's last part (korobeiniki.wav), and
 * [www_type] goes by the extension. [www_failed] is a 502 saying why. *)
val www_request : string -> Url.url option
val www_address : string -> Url.url
val www_kept : Url.url -> string option
val www_type : string -> string
val www_kept_response : string -> string -> string
val www_failed : string -> string

(* "img w h address" asks for a picture, which the host decodes and
 * scales to w by h in the machine's colours. [www_picture_request] gives
 * w and h 0 for a size no answer can carry (0, or w over a message).
 * [www_picture_kept] is the last part without its ?query. *)
val www_picture_request :
  string -> (int * int * Url.url) option
val www_picture_kept : Url.url -> string option

(* [picture text w h pixels] is the answer to "img": a message "t w h",
 * t messages of text, then one message per row, a byte per pixel in the
 * screen's 256 colours; w and h are 0 with no picture. *)
val picture : string -> int -> int -> string -> string list

(* In instructions, by TinyMachineDevices.rate: a packet crosses the wire
 * in 5 ms, and the peer looks at its clock every 2.5 ms (a kernel tick). *)
val latency : unit -> int
val tick : unit -> int

(* for -net-trace and the page's wire view *)
val net_dotted : KNetwork.ip_addr -> string
val net_describe : string -> string
