(* tiny-ml's compiler from the typed tree to the stack machine: the
 * code of each function, its closures (static when they capture
 * nothing), the tests of its patterns, and its exception handlers.
 * Read Tree.mli and Machine.mli first. *)

(* Glob is a unit's table and an index in it. *)
type loc =
  | Slot of Machine.slot
  | Env of int
  | Glob of Machine.sym * int
  | Static of Machine.sym
type known = Machine.sym * int        (* a function's code, its arity *)
(* Ext is a primitive, with its name and arity. *)
type binding = Loc of loc * known option | Ext of string * int

(* The values of the toplevel names; their types are in Types. *)
val globals : (string, binding) Hashtbl.t

(* [start_fun nslots ntries] starts a function's code, given the frame
 * slots and the handlers seen so far; [finish_fun f nparams] turns that
 * code into f's assembly. *)
val start_fun : int -> int -> unit
val finish_fun : Machine.sym -> int -> unit
val emit : Machine.ir -> unit
(* The next function to compile, queued when a closure was made. *)
val dequeue : unit -> (unit -> unit) option

(* Where the values of the let's names are. *)
val bind :
  (string * binding) list -> Tree.rec_flag ->
  (Tree.pat * Tree.expr) list -> (string * binding) list
val curry_fun : int -> int -> unit    (* ml_curry<n>_<k> *)
