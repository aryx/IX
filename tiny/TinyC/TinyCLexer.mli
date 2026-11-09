type token =
    Id of string
  | Num of int64 * bool * bool (* unsigned, long long *)
  | Str of string
  | P of string
  | EOF
type loc = string * int
val tokens :
  (string, (token * loc) list) Hashtbl.t ->
  ((Chan.i -> (token * loc) list) -> Fpath.t -> (token * loc) list) ->
  Chan.i -> (token * loc) list
