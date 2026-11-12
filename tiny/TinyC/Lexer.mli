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

(* what lexing a file needs besides it: the #defines' tokens so far; the
 * directories an #include's file is looked for in after the file's own
 * (-I's); the place chosen among its places (find here others: beside
 * the file, then -I's); a file opened and read, an #include's (its
 * errors said with its name). (lx_: a record's labels are one name
 * space in tiny-ml, tiny-cc's program on tiny-kernel) *)
type env = {
  lx_macros : (string, located list) Hashtbl.t;
  lx_incl : Fpath.t list;
  lx_find : Fpath.t -> Fpath.t list -> Fpath.t;
  lx_open : (Chan.i -> located list) -> Fpath.t -> located list;
}

(* [tokens env chan]: the file's tokens, each #include's in its place,
 * the #defines expanded *)
val tokens : env -> Chan.i -> located list
