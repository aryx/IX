(* Browser_url: what a browser does with the URLs of a page. A link is
 * resolved against the page it is on, and the parts of a URL that the
 * server never sees (the #fragment) or that a form fills (the ?query)
 * are taken apart.
 *
 *   base  http://info.cern.ch/hypertext/WWW/TheProject.html
 *   href  "Help.html#people"
 *   -> http://info.cern.ch/hypertext/WWW/Help.html#people
 *   -> fetched: http://info.cern.ch/hypertext/WWW/Help.html
 *      then scrolled to "people" (the fragment is the browser's)
 *
 * It works over networking's Url (RFC 3986); see notes_browser.md
 * section 1. *)

(* a link's href, resolved against the page it is on (RFC 3986). The
 * href is given as it is if either does not parse, or if it is a data:
 * URL *)
val resolve : string -> string -> string

(* a URL and its #fragment, taken apart *)
val split_fragment : string -> string * string option

(* a URL and its ?query, taken apart *)
val split_query : string -> string * string option

(* a data: URL's bytes (RFC 2397: "data:image/svg+xml,<svg ...>", with
 * its payload percent-encoded, or with ";base64,"). This is how a
 * picture inside a style sheet is had at once. None for any other
 * URL *)
val data_url : string -> string option

(* whether [s] begins with [prefix] *)
val starts_with : string -> string -> bool
