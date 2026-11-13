(* Fpath_: a subset of lib_core/commons/'s module (see Stdlib.mli). It
 * gives Fpath's functions shorter names, so that each conversion
 * between a string and a path takes three characters:
 *
 *     open Fpath_.Operators
 *     let obj = dir / "main.o" in ... print_string !!obj ...
 *
 * Operators is a module inside this one, as in lib_core. tiny-ml allows
 * only one level of such modules: their values are named
 * Fpath_.Operators.x, and open A.M opens them. *)

val of_strings : string list -> Fpath.t list
val to_strings : Fpath.t list -> string list

module Operators : sig
  (* Fpath.add_seg *)
  val ( / ) : Fpath.t -> string -> Fpath.t

  (* Fpath.append *)
  val ( // ) : Fpath.t -> Fpath.t -> Fpath.t

  (* Fpath.to_string *)
  val ( !! ) : Fpath.t -> string
end
