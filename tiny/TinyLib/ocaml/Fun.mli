(* TinyLib: lib_core/base/Fun, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* The OCaml programmers
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

(** Function values. *)

external id : 'a -> 'a = "%identity"




val protect : finally:(unit -> unit) -> (unit -> 'a) -> 'a
(** [protect ~finally work] invokes [work ()] and then [finally ()]
    before [work ()] returns with its value or an exception. (No
    [Finally_raised] here, for a [finally] that raises.) *)
