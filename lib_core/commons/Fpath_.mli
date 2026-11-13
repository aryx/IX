(* ix: Fpath's functions under shorter names (it is xix's Fpath_; the
 * underscore says that the module sits beside the library's module
 * and does not replace it). A path has a type of its own, not string,
 * so that you cannot pass a file's name for its contents, or a path
 * for a pattern, by mistake. The cost is a conversion each time a
 * path goes in or out, and the operators make that conversion three
 * characters long:
 *
 *     open Fpath_.Operators
 *     let obj = dir / "main.o" in ... Sys.file_exists !!obj ... *)

val of_strings : string list -> Fpath.t list
val to_strings : Fpath.t list -> string list

module Operators : sig
  (* Fpath.add_seg, which is Fpath.(/) *)
  val ( / ) : Fpath.t -> string -> Fpath.t

  (* Fpath.append, which is Fpath.(//) *)
  val ( // ) : Fpath.t -> Fpath.t -> Fpath.t

  (* Fpath.to_string *)
  val ( !! ) : Fpath.t -> string
end
