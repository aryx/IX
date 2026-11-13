(* TinyLibCore is the standard library of tiny-ml's programs (the kernel,
 * tiny-windows, the applications, the tools). It is written in tiny-ml's
 * ML, with one module per file, as OCaml's is. Stdlib is open in every
 * unit, and then come:
 * - Char, Seq, List, String, Bytes, Array, Option, Int32, Int64,
 *   Filename and Buffer;
 * - Printf (what tiny-ml's reading of a format calls: see Printf.mli);
 * - Marshal (OCaml's format, in the runtime);
 * - Hashtbl;
 * - ix's Common, Sha1, Fpath, Fpath_ and Exit (from lib_core and
 *   lib_crypto, which the tools name);
 * - In_channel, Out_channel and Chan, for a file read or written (Chan
 *   comes from lib_core);
 * - Logs, for a program's messages, by level.
 * Each .mli except Printf's, Marshal's and Logs' is a subset of OCaml's
 * (or of lib_core's, or of lib_crypto's): it has the same names, the
 * same types and the same results. So a file is built by OCaml on its
 * own library for the host, and by tiny-ml on this one.
 * TinyLibCore_test.sh has OCaml check each .mli against its module, and
 * checks that a program prints the same lines when built both ways.
 * What is left out is what no tiny program names.
 *
 * Each module is compiled once, by tiny-ml -c -L ., after the modules it
 * names, into its object and its interface. On tiny-kernel they are in
 * /lib/ml, where tiny-ml reads the interfaces (-L gives another
 * directory). The modules are the first units of every program, and
 * tiny-ld leaves out the pieces that a program does not call.
 *
 *     Stdlib  Char  Seq  List  String  Bytes  Array  Option  Int32
 *        Int64  Filename  Buffer  Printf  Marshal  Hashtbl  Common
 *        Sha1  Fpath  Fpath_  Exit  In_channel  Out_channel  Chan  Logs
 *     (each module comes after the ones it uses: Sha1, for example,
 *     uses String and Char)
 *
 * design:
 * TinyLibCore is a directory with one module per file, and not a single
 * TinyLibCore.ml. As a single file, a prelude, its dotted names were
 * not modules, and its text was part of the compiler, compiled again
 * at each run (47 s for a unit of one line on tiny-kernel, and
 * 420 KB of the library's assembly in every program). A module in a
 * file of its own is compiled once, into its object and its interface;
 * its name is OCaml's, so the same source builds both ways;
 * TinyLibCore_test.sh checks each .mli against OCaml's module; and
 * tiny-ld leaves out the pieces that a program does not call.
 * The price is that the list of the modules is kept in several places
 * (CORE in tiny/Buildfile and in TinyLibCore/Buildfile, TinyML.ml's
 * library, tests/link.sh, the list above). The system's side is not
 * here; TinyLibSystem.mli says why.
 *
 * This module has the operators, as externals of the machine and of the
 * runtime (runtime/ml/ml.c); option and the exceptions; and the few
 * functions of OCaml's Stdlib that tiny programs name. max_int and
 * min_int are the target's, on 31 bits. *)

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

(* a file opened to read, or to write (see In_channel and Out_channel;
 * TinyLibSystem.with_open_in and with_open_out open them) *)
type in_channel
type out_channel
