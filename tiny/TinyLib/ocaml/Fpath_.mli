(* TinyLib: lib_core/commons/Fpath_, the part the tiny programs call (tiny/TinyLib/README.md)
 *
 * Fpath's functions under shorter names (xix's Fpath_; the underscore:
 * beside the library's module, not in its place). A path is a type of
 * its own, not a string, so that a file's name and its contents, or a
 * path and a pattern, are not passed one for the other; the cost is a
 * conversion at each door, which the operators make three characters:
 *
 *     open Fpath_.Operators
 *     let obj = dir / "main.o" in ... Sys.file_exists !!obj ... *)

module Operators : sig
  (* Fpath.add_seg = Fpath.(/) *)
  val ( / ) : Fpath.t -> string -> Fpath.t

  (* Fpath.append = Fpath.(//) *)
  val ( // ) : Fpath.t -> Fpath.t -> Fpath.t

  (* Fpath.to_string *)
  val ( !! ) : Fpath.t -> string
end
