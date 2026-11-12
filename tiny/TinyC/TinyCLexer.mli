(* tiny-cc's lexer and preprocessor: a C file's tokens, its #includes'
 * in their place and its #defines expanded. *)

type token =
  | Id of string                      (* a name or a keyword *)
  | Num of int64 * bool * bool        (* unsigned, long long *)
  | Str of string
  | P of string                       (* a punctuation *)
  | EOF

(* where a token is, for the errors: its file (an #include's own) and
 * line *)
type loc = string * int
type located = token * loc

(* [tokens macros open_ chan]: the file's tokens; open_ reads an
 * #include's file, and macros keeps the #defines' tokens *)
val tokens :
  (string, located list) Hashtbl.t ->
  ((Chan.i -> located list) -> Fpath.t -> located list) ->
  Chan.i -> located list
