(* TinyLib: lib_core/commons/Fpath_, the part the tiny programs call (tiny/TinyLib/README.md) *)

module Operators : sig
  (* Fpath.add_seg = Fpath.(/) *)
  val ( / ) : Fpath.t -> string -> Fpath.t

  (* Fpath.append = Fpath.(//) *)
  val ( // ) : Fpath.t -> Fpath.t -> Fpath.t

  (* Fpath.to_string *)
  val ( !! ) : Fpath.t -> string
end
