(* Tab: a page being looked at, and the pages before it. Written for
 * ix after the author's mini-chrome's Browser_tab (its first version),
 * without what that one carries: scripts, sounds and videos, the
 * developer tools' lists.
 *
 * No threads and nothing on its way (plan_browser.md, decision 6): a
 * page asked for ([go]) is fetched by [step], which the window calls
 * between two frames while the tab is [busy]: first the page and its
 * style sheets one after the other (and theirs, @import), laid out
 * and shown; then a picture a call (PNG, JPEG, GIF, SVG:
 * Browser_picture). The window is still during a piece, and says
 * between two what is being done.
 *
 * A PDF file is shown as a page of the browser's (Pdf_viewer): its
 * pages are pictures, drawn when [go] or [scrolled] brings them into
 * view, a window's height before and after too, and let go when they
 * are out of it.
 *
 * An address is http://, https:// (Http_client: ix's own TLS), file://
 * or a file's path, data:, or about:name, a page of the browser's
 * own. *)

type t

(* a tab with no page, [width] wide; [about name]: the browser's own
 * page of that name (about:name), its HTML *)
val empty : float -> (string -> string option) -> t

(* the page shown, if one came; its address; what the last load said
 * (the status bar's) *)
val page : t -> Browser_page.t option
val url : t -> string
val said : t -> string

(* how far down the page the window's top is *)
val scroll : t -> float

(* [scrolled by ~visible tab]: moved by [by] (down: positive), kept
 * within the page, [visible] of it seen at once *)
val scrolled : float -> visible:float -> t -> t

(* how wide the page is laid out; [resized width tab]: laid out again
 * at another width (the window's, divided by the zoom) *)
val width : t -> float
val resized : float -> t -> t

(* the field that takes the keys, if one does *)
val focus : t -> Dom.element option

(* The four below ask for a page and return at once: [step] fetches
 * it, a piece a call, so that the window says what is on its way
 * between two pieces. *)

(* [go tab address]: a link followed: the address, against the page's,
 * asked for, the page before kept behind it; an address of the page
 * shown with another #fragment only scrolls *)
val go : t -> string -> t

(* [visit tab typed]: an address as one types it: whole, or a file's
 * path, or a host's name (example.com is http://example.com) *)
val visit : t -> string -> t

val back : t -> t
val forward : t -> t
val reload : t -> t

(* is something left to fetch? Then [url] is the address asked for,
 * and [said] what is being done ("Loading http://... ...", "Loading
 * pictures: 3 of 19") *)
val busy : t -> bool

(* a piece of it done: the page with its style sheets, read and laid
 * out, shown without its pictures; then a picture a call, and after
 * the last the page laid out again with them all *)
val step : < Cap.network; Cap.open_in; .. > -> t -> t

(* the link at a point of the page, its address whole *)
val link_at : t -> x:float -> y:float -> string option

(* what is at a point of the page, for the cursor: a link (its address
 * whole), a field one types in, a button or a box to click *)
type under = Nothing | Link of string | Field | Button

val under : t -> x:float -> y:float -> under

(* a click at a point of the page: a link followed, a field given the
 * keys, a button's form sent *)
val click : t -> x:float -> y:float -> t

(* text typed, and a key ("enter", "backspace"), for the field that has
 * the keys *)
val typed : t -> string -> t
val key : t -> string -> t
