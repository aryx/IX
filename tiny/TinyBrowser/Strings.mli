(* The few string functions every part of TinyBrowser needs, which
 * TinyLibCore's String does not have (nor OCaml's, which dune builds
 * these files with): its lowest part, under Charset, Tokens, Html, Url
 * and Http. *)

(* [find s pat i] is the position of pat in s, searching from i *)
val find : string -> string -> int -> int option

val is_space : char -> bool

(* an attribute's number, 0 when it is not one *)
val number : string -> int
