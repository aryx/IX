(* Fpath_, lib_core/commons/'s subset (see Stdlib.mli): Fpath's functions
 * under shorter names, a conversion at each door three characters:
 *
 *     open Fpath_.Operators
 *     let obj = dir / "main.o" in ... print_string !!obj ...
 *
 * Operators is a module in this one, as lib_core's: tiny-ml has modules
 * of one level, their names Fpath_.Operators.x, open A.M opening them *)

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
