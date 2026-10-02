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


(* System interface *)

external get_config: unit -> string * int = "sys_get_config"
external get_argv: unit -> string array = "sys_get_argv"

let argv = get_argv()
let (os_type, word_size) = get_config()
let max_array_length = (1 lsl (word_size - 10)) - 1;;
let max_string_length = word_size / 8 * max_array_length - 1;;

external file_exists: string -> bool = "sys_file_exists"
external is_directory : string -> bool = "sys_is_directory"
external remove: string -> unit = "sys_remove"
external rename : string -> string -> unit = "sys_rename"
external getenv: string -> string = "sys_getenv"

let getenv_opt s =
  try Some (getenv s)
  with Not_found -> None

external command: string -> int = "sys_system_command"
external time: unit -> float = "sys_time"
external chdir: string -> unit = "sys_chdir"
external getcwd: unit -> string = "sys_getcwd"

let interactive = ref false

type signal_behavior =
    Signal_default
  | Signal_ignore
  | Signal_handle of (int -> unit)

(* ix: OCaml's signals (negative, the same on every system) as Linux's;
 * a signal's behavior kept here, its handler given to Pervasives, which
 * runs it where the program waits; the runtime told to note the
 * signal, to ignore it or to leave it to the system. As OCaml's, the
 * behavior before is the result. *)
let system_signals =
  [ -1, 6; -2, 14; -3, 8; -4, 1; -5, 4; -6, 2; -7, 9; -8, 13; -9, 3; -10, 11; -11, 15; -12, 10; -13, 12; -14, 17; -15, 18;
    -16, 19; -17, 20; -18, 21; -19, 22; -20, 26; -21, 27; -22, 7; -23, 29; -24, 31; -25, 5; -26, 23; -27, 24; -28, 25 ]
let system_signal s = match List.assoc_opt s system_signals with Some n -> n | None -> s

external install : int -> int -> unit = "ml_signal"
let behaviors : (int * signal_behavior) list ref = ref []

let signal s (b : signal_behavior) =
  let n = system_signal s in
  let before = match List.assoc_opt n !behaviors with Some b -> b | None -> Signal_default in
  behaviors := (n, b) :: List.remove_assoc n !behaviors;
  signal_handlers := List.remove_assoc n !signal_handlers;
  (match b with
   | Signal_default -> install n 0
   | Signal_ignore -> install n 1
   | Signal_handle f -> signal_handlers := (n, (fun () -> f s)) :: !signal_handlers; install n 2);
  before

(* ported from 3.12 *)
let set_signal sig_num sig_beh = ignore(signal sig_num sig_beh)


let sigabrt = -1
let sigalrm = -2
let sigfpe = -3
let sighup = -4
let sigill = -5
let sigint = -6
let sigkill = -7
let sigpipe = -8
let sigquit = -9
let sigsegv = -10
let sigterm = -11
let sigusr1 = -12
let sigusr2 = -13
let sigchld = -14
let sigcont = -15
let sigstop = -16
let sigtstp = -17
let sigttin = -18
let sigttou = -19
let sigvtalrm = -20
let sigprof = -21
(* ix: OCaml's later ones *)
let sigbus = -22
let sigpoll = -23
let sigsys = -24
let sigtrap = -25
let sigurg = -26
let sigxcpu = -27
let sigxfsz = -28

exception Break

let catch_break on =
  if on then
    ignore (signal sigint (Signal_handle(fun _ -> raise Break)))
  else
    ignore (signal sigint Signal_default)

(* ix: OCaml's later functions, those ix's programs use *)

let int_size = word_size - 1

external readdir : string -> string array = "sys_read_directory"
external mkdir : string -> int -> unit = "sys_mkdir"
let rmdir = remove

(* the name the program was run by (OCaml's is its file's full name) *)
let executable_name = argv.(0)
