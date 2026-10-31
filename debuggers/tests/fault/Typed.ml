(* an uncaught exception whose arguments are of the unit's types
 * (debuggers/tests/walk.sh): by mini-ml -g's descriptions, the runtime
 * prints them as OCaml's toplevel would *)
type shape = Empty | Circle of float | Rect of int * int
type point = { x : int; y : int; name : string }

exception Bad of shape * point * int list * string option
exception Plain of int

let check n = if n > 2 then raise (Bad (Rect (3, -4), { x = 1; y = 2; name = "origin" }, [ 1; 2 ], Some "why")) else Plain n

let () = ignore (check (Array.length Sys.argv + 2))
