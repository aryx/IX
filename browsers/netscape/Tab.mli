(* Tab: a page being looked at, and the pages before it. Written for
 * ix after the author's mini-chrome's Browser_tab (its first version),
 * without what that one carries: scripts, sounds and videos, the
 * developer tools' lists.
 *
 * No threads and nothing on its way: [go] fetches the page, then its
 * style sheets one after the other (and theirs, @import), then its
 * pictures the same way (PNG, JPEG, GIF, SVG: Browser_picture), lays
 * the page out and returns; the window is still meanwhile
 * (plan_browser.md, decision 6).
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

(* the field that takes the keys, if one does *)
val focus : t -> Dom.element option

(* [go caps tab address]: a link followed: the address, against the
 * page's, fetched and shown, the page before kept behind it; an address
 * of the page shown with another #fragment only scrolls *)
val go : < Cap.network; Cap.open_in; .. > -> t -> string -> t

(* [visit caps tab typed]: an address as one types it: whole, or a
 * file's path, or a host's name (example.com is http://example.com) *)
val visit : < Cap.network; Cap.open_in; .. > -> t -> string -> t

val back : < Cap.network; Cap.open_in; .. > -> t -> t
val forward : < Cap.network; Cap.open_in; .. > -> t -> t
val reload : < Cap.network; Cap.open_in; .. > -> t -> t

(* the link at a point of the page, its address whole *)
val link_at : t -> x:float -> y:float -> string option

(* a click at a point of the page: a link followed, a field given the
 * keys, a button's form sent *)
val click : < Cap.network; Cap.open_in; .. > -> t -> x:float -> y:float -> t

(* text typed, and a key ("enter", "backspace"), for the field that has
 * the keys *)
val typed : t -> string -> t
val key : < Cap.network; Cap.open_in; .. > -> t -> string -> t
