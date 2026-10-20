(* TinyLibCore: the standard library of tiny-ml's programs (the kernel,
 * tiny-windows, the applications, the tools), in tiny-ml's ML, a
 * module a file as OCaml's: Stdlib, open in every unit, then Char,
 * List, String, Bytes, Array, Option, Filename, Buffer, Hashtbl, and
 * ix's Common and Sha1 (lib_core's and lib_crypto's, which the tools
 * name). Each .mli is a subset of OCaml's (lib_core's, lib_crypto's):
 * the same names, the same types, the same results, so that a file
 * is built by OCaml on its own library for the host and by tiny-ml on
 * this one; TinyLibCore_test.sh has OCaml check each .mli against its
 * module, and compares a program's lines on both. What is left out is
 * what no tiny program names.
 *
 * Each module is compiled once, by tiny-ml -c -nostdlib after the ones
 * before it, to its object and its interface: on tiny-kernel in
 * /sys/lib/ml, where tiny-ml reads the interfaces (-L another
 * directory). They are the first units of every program; what a
 * program does not call, tiny-linker leaves out (its pieces).
 * (old: the compiler carried the files' text, TinyMLPrelude.ml made of
 * them by the build, and compiled them again at each run)
 *
 *     Stdlib  Char  List  String  Bytes  Array  Option
 *        Filename  Buffer  Hashtbl  Common  Sha1
 *     (each after those before it: String.map is List.init's)
 *
 * (old: TinyLibCore.ml, a prelude whose dotted names, List.map, were
 * single names, and TinyLibStd.ml, the rest, given to tiny-ml before a
 * tool's file; a Buffer a string grown by ^, a Hashtbl a list of pairs:
 * plan_tiny_self_hosting.md, step 5)
 *
 * This module: the operators, the machine's and the runtime's
 * (core.c's) as externals; option and the exceptions; the few
 * functions OCaml's Stdlib has that tiny programs name. max_int and
 * min_int are the target's, 31 bits. *)

val raise : exn -> 'a
val ( = ) : 'a -> 'a -> bool
val ( <> ) : 'a -> 'a -> bool
val ( < ) : 'a -> 'a -> bool
val ( > ) : 'a -> 'a -> bool
val ( <= ) : 'a -> 'a -> bool
val ( >= ) : 'a -> 'a -> bool
val ( == ) : 'a -> 'a -> bool
val ( != ) : 'a -> 'a -> bool
val compare : 'a -> 'a -> int
val not : bool -> bool
val ( ~- ) : int -> int
val ( + ) : int -> int -> int
val ( - ) : int -> int -> int
val ( * ) : int -> int -> int
val ( / ) : int -> int -> int
val ( mod ) : int -> int -> int
val ( land ) : int -> int -> int
val ( lor ) : int -> int -> int
val ( lxor ) : int -> int -> int
val ( lsl ) : int -> int -> int
val ( lsr ) : int -> int -> int
val ( asr ) : int -> int -> int
val lnot : int -> int
val ref : 'a -> 'a ref
val ( ! ) : 'a ref -> 'a
val ( := ) : 'a ref -> 'a -> unit
val fst : 'a * 'b -> 'a
val snd : 'a * 'b -> 'b
val ignore : 'a -> unit
val int_of_char : char -> int
val char_of_int : int -> char
val ( ^ ) : string -> string -> string
val string_of_int : int -> string
val int_of_string_opt : string -> int option
val int_of_string : string -> int
val print_string : string -> unit
val print_char : char -> unit
val print_newline : unit -> unit
val print_int : int -> unit
val print_endline : string -> unit
val exit : int -> 'a
val failwith : string -> 'a
val invalid_arg : string -> 'a
val incr : int ref -> unit
val decr : int ref -> unit
val succ : int -> int
val pred : int -> int
val abs : int -> int
val min : 'a -> 'a -> 'a
val max : 'a -> 'a -> 'a
val ( |> ) : 'a -> ('a -> 'b) -> 'b
val ( @ ) : 'a list -> 'a list -> 'a list
val max_int : int
val min_int : int
exception Exit
