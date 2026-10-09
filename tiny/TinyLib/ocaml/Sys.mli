(* TinyLib: lib_core/system/Sys, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Sys]: system interface *)

val argv: string array
external file_exists: string -> bool = "sys_file_exists"
external is_directory : string -> bool = "sys_is_directory"
        (* Raise [Sys_error] if no file has this name. *)
external remove: string -> unit = "sys_remove"
external rename : string -> string -> unit = "sys_rename"
external getenv: string -> string = "sys_getenv"
        (* Raise [Not_found] if the variable is unbound. *)

val getenv_opt : string -> string option

external getcwd: unit -> string = "sys_getcwd"
val os_type: string
val word_size: int
        (* In bits: 32 or 64. *)
val max_string_length: int
val max_array_length: int

(*** Signal handling *)

type signal_behavior =
    Signal_default
  | Signal_ignore
  | Signal_handle of (int -> unit)
        (* [Signal_handle f]: [f] is called with the signal's number. *)

val signal : int -> signal_behavior -> signal_behavior
        (* The behavior set; the one before is returned. *)

val set_signal : int -> signal_behavior -> unit

val sigint: int    (* Interactive interrupt (ctrl-C) *)
val sigpipe: int   (* Broken pipe *)

exception Break
        (* Raised on interactive interrupt if [catch_break] is on. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* an int's bits: 31 or 63 *)
val int_size : int

(* a directory's names, in no order, without . and ..; an empty
 * directory removed *)
external readdir : string -> string array = "sys_read_directory"
val rmdir : string -> unit

(* the name the program was run by *)
val executable_name : string

(* ix: OCaml's signals and the system's (Linux's) numbers; the second of the first *)
val system_signals : (int * int) list
val system_signal : int -> int
