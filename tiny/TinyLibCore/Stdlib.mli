(* TinyLibCore: the standard library of tiny-ml's programs (the kernel,
 * tiny-windows, the applications, the tools), in tiny-ml's ML, a
 * module a file as OCaml's: Stdlib, open in every unit, then Char,
 * Seq, List, String, Bytes, Array, Option, Int64, Filename, Buffer, Printf
 * (what tiny-ml's reading of a format calls: Printf.mli), Marshal
 * (OCaml's format, in the runtime), Hashtbl, and
 * ix's Common, Sha1, Fpath, Fpath_ and Exit (lib_core's and lib_crypto's,
 * which the tools name), then In_channel, Out_channel and Chan (a file
 * read or written, Chan lib_core's), and Logs (a program's messages,
 * by level). Each .mli but Printf's, Marshal's and Logs' is a subset
 * of OCaml's (lib_core's, lib_crypto's):
 * the same names, the same types, the same results, so that a file
 * is built by OCaml on its own library for the host and by tiny-ml on
 * this one; TinyLibCore_test.sh has OCaml check each .mli against its
 * module, and compares a program's lines on both. What is left out is
 * what no tiny program names.
 *
 * Each module is compiled once, by tiny-ml -c -nostdlib after the ones
 * before it, to its object and its interface: on tiny-kernel in
 * /lib/ml, where tiny-ml reads the interfaces (-L another
 * directory). They are the first units of every program; what a
 * program does not call, tiny-linker leaves out (its pieces).
 * (old: the compiler carried the files' text, TinyMLPrelude.ml made of
 * them by the build, and compiled them again at each run)
 *
 *     Stdlib  Char  Seq  List  String  Bytes  Array  Option  Int64
 *        Filename  Buffer  Printf  Marshal  Hashtbl  Common  Sha1
 *        Fpath  Fpath_  Exit  In_channel  Out_channel  Chan  Logs
 *     (each after those before it: String.map is List.init's)
 *
 * (old: TinyLibCore.ml, a prelude whose dotted names, List.map, were
 * single names, and TinyLibStd.ml, the rest, given to tiny-ml before a
 * tool's file; a Buffer a string grown by ^, a Hashtbl a list of pairs:
 * plan_tiny_self_hosting.md, step 5)
 *
 * design:
 * A directory, a module a file, and not one TinyLibCore.ml: the
 * prelude's dotted names were not modules, and its text was the
 * compiler's, compiled again at each run (47 s for a unit of one line
 * on tiny-kernel, 420 KB of the library's assembly in every program).
 * A module a file is compiled once, to its object and its interface;
 * its name is OCaml's, so the same source builds both ways;
 * TinyLibCore_test.sh checks each .mli against OCaml's module; and
 * tiny-linker leaves out what a program does not call (its pieces).
 * The price is the list of the modules, kept in several places
 * (TinyKernel/Makefile's CORE, TinyML.ml's library, tests/link.sh, the
 * list above). The system's side is not here: TinyLibSystem.mli says
 * why.
 *
 * This module: the operators, the machine's and the runtime's
 * (runtime/ml.c's) as externals; option and the exceptions; the few
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

(* a file opened to read, or to write (In_channel and Out_channel;
 * TinyLibSystem.with_open_in and with_open_out open them) *)
type in_channel
type out_channel
