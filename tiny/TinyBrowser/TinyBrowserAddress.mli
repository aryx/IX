(* Addresses, for TinyBrowser: what was typed as a full address, and
 * where a link goes from the page it is on.
 *
 *     typed "OCaml"           https://en.wikipedia.org/wiki/OCaml
 *     typed "ocaml.org"       https://ocaml.org
 *     typed "?plan 9 rio"     https://lite.duckduckgo.com/lite/?q=plan+9+rio
 *     on https://en.wikipedia.org/wiki/OCaml, whose <base> is
 *       //en.wikipedia.org/wiki/:
 *       ./ML                  https://en.wikipedia.org/wiki/ML
 *       #History              https://en.wikipedia.org/wiki/OCaml#History
 *       /static/x.png         https://en.wikipedia.org/static/x.png
 *
 * The wire's other end takes a typed address by the same function
 * (TinyMachinePeer.www_address).
 *)

(* an address and its #fragment, apart ("" when there is none) *)
val fragment : string -> string * string

(* What was typed, as a full address: a title is an English Wikipedia
 * article, a name with a dot is https://, and ?words a search of
 * DuckDuckGo's page for text browsers (lite.duckduckgo.com). *)
val absolute : string -> string

(* "https://host" of an address *)
val site : string -> string

(* [resolve url base href]: where a link goes, from the page at [url]
 * whose <base> is [base] ("" when it has none). *)
val resolve : string -> string -> string -> string
