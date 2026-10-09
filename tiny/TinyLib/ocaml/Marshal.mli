(* TinyLib: lib_core/core/Marshal, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1997 INRIA. Distributed only by permission. *)

(* Module [Marshal]: a data structure encoded as a sequence of bytes,
   to write and to read back, maybe in another process.

   Not type-safe: the type is not in the bytes, and the ['a] of
   [from_*] is whatever the context expects; give it,
   [(Marshal.from_string s 0 : type)]. Anything can happen if the
   value read is not of that type. *)

type extern_flags =
    No_sharing                          (* Don't preserve sharing *)
  | Closures                            (* Send function closures *)


val to_string: 'a -> extern_flags list -> string



val from_string: string -> int -> 'a
        (* [from_string buff ofs]: the value encoded in [buff] from
           position [ofs]. *)

val header_size : int

(* ix: OCaml's later name: from_string, for bytes *)
val from_bytes : bytes -> int -> 'a
