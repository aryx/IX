type loc = Slot of int | Env of int | Glob of string * int | Static of string
type binding = Loc of loc * (string * int) option | Ext of string * int
val globals : (string, binding) Hashtbl.t
type fn = {
  mutable code : TinyMLMachine.ir list;
  mutable nslots : int;
  mutable ntries : int;
}
val cur : fn ref
val emit : TinyMLMachine.ir -> unit
val dequeue : unit -> (unit -> unit) option
type closure =
    Closure_static of string * string * int
  | Closure_pushed of string * int
val bind :
  (string * binding) list ->
  bool -> (TinyMLTree.pat * TinyMLTree.expr) list -> (string * binding) list
val curry_fun : int -> int -> unit
