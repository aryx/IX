type token =
    Id of string
  | Num of int64 * bool
  | Str of string
  | P of string
  | EOF
type loc = string * int
val tokens :
  (string, (token * loc) list) Hashtbl.t ->
  (Fpath.t -> string) -> Fpath.t -> (token * loc) list
