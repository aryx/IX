(* TinyLib: lib_core/system/Filename, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Filename]: operations on file names *)

val concat : string -> string -> string
        (* [concat dir file] *)
val is_relative : string -> bool
        (* To the current directory; [false] if absolute. *)
val check_suffix : string -> string -> bool
val chop_suffix : string -> string -> string
        (* [chop_suffix name suff] *)
val chop_extension : string -> string
        (* Raise [Invalid_argument] if the name has no period. *)
val basename : string -> string
val dirname : string -> string

(* ix: OCaml's later functions, those ix's programs use *)

(* the name without its extension, or as it is *)
val remove_extension : string -> string

(* the name as one word of a shell's command *)
val quote : string -> string
