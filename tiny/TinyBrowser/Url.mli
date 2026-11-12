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

type url = string

(* an address split from its #fragment *)
val fragment : url -> url * string option

(* What was typed, as a full address: a title is an English Wikipedia
 * article, a name with a dot is https://, and ?words a search of
 * DuckDuckGo's page for text browsers (lite.duckduckgo.com). *)
val absolute : string -> url

(* the query's words are appended to it *)
val search_engine : url

(* the "https://host" part of an address *)
val site : url -> url

(* [resolve url base href], [base] being the page's <base> or "" *)
val resolve : url -> url -> string -> url
