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


(* Module [Sys]: system interface *)

val argv: string array
        (* The command line arguments given to the process. *)
external file_exists: string -> bool = "sys_file_exists"
        (* Test if a file with the given name exists. *)
external is_directory : string -> bool = "sys_is_directory"
        (* Returns [true] if the given name refers to a directory, [false]
           if it refers to another kind of file. Raise [Sys_error] if no
           file exists with the given name. *)
external remove: string -> unit = "sys_remove"
        (* Remove the given file name from the file system. *)
external rename : string -> string -> unit = "sys_rename"
        (* Rename a file. *)
external getenv: string -> string = "sys_getenv"
        (* Return the value associated to a variable in the process
           environment. Raise [Not_found] if the variable is unbound. *)

val getenv_opt : string -> string option
(** Return the value associated to a variable in the process environment or
    [None] if the variable is unbound. *)

external command: string -> int = "sys_system_command"
        (* Execute the given shell command and return its exit code. *)
external time: unit -> float = "sys_time"
        (* Return the processor time, in seconds, used by the program since
           the beginning of execution. *)
external chdir: string -> unit = "sys_chdir"
        (* Change the current working directory of the process. *)
external getcwd: unit -> string = "sys_getcwd"
        (* Return the current working directory of the process. *)
val os_type: string
        (* Operating system currently executing the Caml program. *)
val word_size: int
        (* Size of one word on the machine currently executing the Caml
           program, in bits: 32 or 64. *)
val max_string_length: int
        (* Maximum length of a string. *)
val max_array_length: int
        (* Maximum length of an array. *)

(*** Signal handling *)

type signal_behavior =
    Signal_default
  | Signal_ignore
  | Signal_handle of (int -> unit)
        (* What to do when receiving a signal: - [Signal_default]: take the
           default behavior - [Signal_ignore]: ignore the signal -
           [Signal_handle f]: call function [f], giving it the signal number
           as argument. *)

val signal : int -> signal_behavior -> signal_behavior
        (* Set the behavior of the system on receipt of a given signal. *)

(* ported from 3.12 *)
val set_signal : int -> signal_behavior -> unit
(** Same as {!Sys.signal} but return value is ignored. *)

val sigabrt: int   (* Abnormal termination *)
val sigalrm: int   (* Timeout *)
val sigfpe: int    (* Arithmetic exception *)
val sighup: int    (* Hangup on controlling terminal *)
val sigill: int    (* Invalid hardware instruction *)
val sigint: int    (* Interactive interrupt (ctrl-C) *)
val sigkill: int   (* Termination (cannot be ignored) *)
val sigpipe: int   (* Broken pipe *)
val sigquit: int   (* Interactive termination *)
val sigsegv: int   (* Invalid memory reference *)
val sigterm: int   (* Termination *)
val sigusr1: int   (* Application-defined signal 1 *)
val sigusr2: int   (* Application-defined signal 2 *)
val sigchld: int   (* Child process terminated *)
val sigcont: int   (* Continue *)
val sigstop: int   (* Stop *)
val sigtstp: int   (* Interactive stop *)
val sigbus : int

exception Break
        (* Exception raised on interactive interrupt if [catch_break] is on. *)

val catch_break: bool -> unit
        (* [catch_break] governs whether interactive interrupt (ctrl-C)
           terminates the program or raises the [Break] exception. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* an int's bits: 31 or 63 *)
val int_size : int

(* a directory's names, in no order, without . and ..; a directory made
 * with these permissions; an empty one removed *)
external readdir : string -> string array = "sys_read_directory"
external mkdir : string -> int -> unit = "sys_mkdir"
val rmdir : string -> unit

(* the name the program was run by *)
val executable_name : string

(* ix: OCaml's signals and the system's (Linux's) numbers; the second of the first *)
val system_signals : (int * int) list
val system_signal : int -> int

(* ix: no program of ix called these, taken out (to restore from OCaml 4.14's sys.ml):
 * interactive, sigttin, sigttou, sigvtalrm, sigprof, sigpoll, sigsys,
 * sigtrap, sigurg, sigxcpu, sigxfsz. *)
