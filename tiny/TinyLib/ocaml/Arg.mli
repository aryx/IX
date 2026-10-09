(* TinyLib: lib_core/system/Arg, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Arg]: parsing of command line arguments *)

(* A keyword is a word starting with a [-]; an option is a keyword
   alone ([Unit], [Set], [Clear]) or followed by its argument, the next
   word. The other words are the anonymous arguments. *)

type spec =
  | Unit of (unit -> unit)     (* Call the function with unit argument *)
  | Bool of (bool -> unit)     (* Call the function with a bool argument *)
  | Set of bool ref            (* Set the reference to true *)
  | Clear of bool ref          (* Set the reference to false *)
  | String of (string -> unit) (* Call the function with a string argument *)
  | Set_string of string ref   (* Set the reference to the string argument *)
  | Int of (int -> unit)       (* Call the function with an int argument *)
  | Set_int of int ref         (* Set the reference to the int argument *)
  | Float of (float -> unit)   (* Call the function with a float argument *)
  | Set_float of float ref     (* Set the reference to the float argument *)

type key = string
type doc = string
type usage_msg = string
type anon_fun = (string -> unit)

val parse : (string * spec * string) list -> (string -> unit) -> string -> unit
(*
    [parse speclist anonfun usage_msg] parses the command line.
    [speclist]: triples [(key, spec, doc)], [doc] a line on the option.
    The functions of [spec] and [anonfun] are called in the order of
    the command line.

    On an error [parse] exits the program, after printing the reason,
    [usage_msg], and the options, each with its [doc].

    For anonymous arguments starting with a [-], have for example
    [("--", String anonfun, doc)] in [speclist].

    [-help] is recognized: [usage_msg] and the options, then exit;
    unless [speclist] has its own.
*)

exception Bad of string
(** A function of [spec] or [anon_fun] raises it, with a message, to
    reject an argument. *)

exception Help of string
(** Raised by [Arg.parse_argv] when the user asks for help. *)


val usage: (string * spec * string) list -> string -> unit
(* [usage speclist usage_msg]: what [parse] prints in case of error. *)

val current: int ref
(* The position in [Sys.argv] of the argument being processed; it can
   be changed, to make [parse] skip arguments. *)


val parse_argv : string array ->
  (key * spec * doc) list -> anon_fun -> usage_msg -> unit
(** As [parse], on the array in place of the command line. *)
