(* The few string functions that every part of TinyBrowser needs and
 * that TinyLibCore's String does not have (nor does OCaml's, with which
 * dune builds these files). This is the lowest module of the browser,
 * under Charset, Tokens, Html, Url and Http. *)

(* [find s pat i] is the position of pat in s, searching from i *)
val find : string -> string -> int -> int option

val is_space : char -> bool

(* an attribute's value as a number, 0 when it is not one *)
val number : string -> int
