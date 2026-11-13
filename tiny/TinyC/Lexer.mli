(* tiny-cc's lexer and preprocessor: turns a C file into tokens, with
 * the tokens of each #include in its place and the #defines expanded. *)

type token =
  | Id of string                      (* a name or a keyword *)
  | Num of int64 * bool * bool        (* unsigned, long long *)
  | Str of string
  | P of string                       (* a punctuation *)
  | EOF

(* The file and the line, for error messages; a token from an #include
 * has the included file's name. *)
type loc = string * int
type located = token * loc

(* lx_incl are the -I directories. [lx_find here others] picks the file:
 * it looks here (next to the including file) first, then in the others.
 * lx_open lexes an included file, and its errors are given with that
 * file's name. The labels have the lx_ prefix because tiny-ml, which
 * compiles tiny-cc for tiny-kernel, has one name space for all record
 * labels. *)
type env = {
  lx_macros : (string, located list) Hashtbl.t;
  lx_incl : Fpath.t list;
  lx_find : Fpath.t -> Fpath.t list -> Fpath.t;
  lx_open : (Chan.i -> located list) -> Fpath.t -> located list;
}

val tokens : env -> Chan.i -> located list
