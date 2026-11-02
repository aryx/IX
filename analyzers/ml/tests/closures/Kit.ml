(* a unit of functions, some reached only as values: through a list, a
 * record's field, a ref, an exception's argument, a partial application *)
type handler = { name : string; run : int -> int }

exception Stop of (int -> int)

let rec iter (f : int -> unit) (xs : int list) : unit =
  match xs with [] -> () | x :: rest -> f x; iter f rest

let rec fold (f : int -> int -> int) (acc : int) (xs : int list) : int =
  match xs with [] -> acc | x :: rest -> fold f (f acc x) rest

let double (x : int) : int = x * 2
let negate (x : int) : int = 0 - x
let square (x : int) : int = x * x
let add (a : int) (b : int) : int = a + b

(* called by no one *)
let cube (x : int) : int = x * x * x

(* called, but only by dead: not reached from a toplevel *)
let helper (x : int) : int = x + 1
let dead (x : int) : int = helper (helper x)

(* given its first argument, never its second *)
let scale (k : int) (x : int) : int = k * x

let handlers : handler list = [ { name = "double"; run = double }; { name = "anon"; run = (fun (x : int) -> x - 1) } ]
let current : (int -> int) ref = ref negate
let last (x : int) : int = raise (Stop square)
