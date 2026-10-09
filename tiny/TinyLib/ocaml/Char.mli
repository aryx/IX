(* TinyLib: lib_core/base/Char, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Char]: character operations *)

external code: char -> int = "%identity"
val chr: int -> char
        (* Raise [Invalid_argument "Char.chr"] if outside 0--255. *)
val escaped : char -> string
        (* Special characters escaped, OCaml's lexical conventions. *)
val lowercase: char -> char
val uppercase: char -> char
(*--*)

external unsafe_chr: int -> char = "%identity"

type t = char
