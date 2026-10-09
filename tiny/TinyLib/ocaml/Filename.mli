(* TinyLib: lib_core/system/Filename, the part the tiny programs call (tiny/TinyLib/README.md) *)
(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)


(* Module [Filename]: operations on file names *)

val concat : string -> string -> string
        (* [concat dir file] returns a file name that designates file [file]
           in directory [dir]. *)
val is_relative : string -> bool
        (* Return [true] if the file name is relative to the current
           directory, [false] if it is absolute (i.e. *)
val check_suffix : string -> string -> bool
        (* [check_suffix name suff] returns [true] if the filename [name]
           ends with the suffix [suff]. *)
val chop_suffix : string -> string -> string
        (* [chop_suffix name suff] removes the suffix [suff] from the
           filename [name]. *)
val chop_extension : string -> string
        (* Return the given file name without its extension. Raise
           [Invalid_argument] if the given name does not contain a period. *)
val basename : string -> string
val dirname : string -> string
        (* Split a file name into directory name / base file name. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* the name without its extension, or as it is *)
val remove_extension : string -> string

(* the name as one word of a shell's command *)
val quote : string -> string
