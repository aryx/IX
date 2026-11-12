(* tiny-ml's compiler from the typed tree to the stack machine: a
 * function's code, its closures (static when they capture nothing),
 * its patterns' tests, its handlers. Read Tree.mli and
 * Machine.mli first. *)

(* where a name's value is: a slot of the frame, a field of the
 * closure, a global of a unit (its table, its index), a static block *)
type loc =
  | Slot of Machine.slot
  | Env of int
  | Glob of Machine.sym * int
  | Static of Machine.sym
(* a function whose code is known: that code, and its arity *)
type known = Machine.sym * int
(* a name's value, or a primitive (its name, its arity) *)
type binding = Loc of loc * known option | Ext of string * int

(* the values of the program's toplevel names (Types's tglobals
 * has their types) *)
val globals : (string, binding) Hashtbl.t

(* [start_fun nslots ntries]: a function's code begun, its frame of
 * that many slots and handlers so far; [finish_fun f nparams]: made *)
val start_fun : int -> int -> unit
val finish_fun : Machine.sym -> int -> unit
(* an instruction of the current function *)
val emit : Machine.ir -> unit
(* the next function to compile, queued by a closure *)
val dequeue : unit -> (unit -> unit) option

(* [bind env r bindings]: a let's bindings compiled, their names'
 * places *)
val bind :
  (string * binding) list -> Tree.rec_flag ->
  (Tree.pat * Tree.expr) list -> (string * binding) list
(* [curry_fun n k]: ml_curry<n>_<k> *)
val curry_fun : int -> int -> unit
