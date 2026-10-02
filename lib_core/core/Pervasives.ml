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

(* coupling: if you add functions here, you will probably need to
 * modify also otherlibs/threads/
 *)

(* ported from ocaml 4.00 *)

let ( @@ ) f x = f x
let (|>) o f =
  f o

(* ported from ocaml 3.12 *)

(*external ignore : 'a -> unit = "%ignore"*)
let ignore _ = ()

(* adapted from ocaml 4.02 *)
type bytes = string

(* ported from ocaml 4.02.2 *)

type ('a,'b) result = Ok of 'a | Error of 'b


type 'a option = None | Some of 'a

(* Exceptions *)

external raise : exn -> 'a = "%raise"

let failwith s = raise(Failure s)
let invalid_arg s = raise(Invalid_argument s)

exception Exit
exception Assert_failure of (string * int * int)

(* Comparisons *)

external (=) : 'a -> 'a -> bool = "%equal"
external (<>) : 'a -> 'a -> bool = "%notequal"
external (<) : 'a -> 'a -> bool = "%lessthan"
external (>) : 'a -> 'a -> bool = "%greaterthan"
external (<=) : 'a -> 'a -> bool = "%lessequal"
external (>=) : 'a -> 'a -> bool = "%greaterequal"
external compare: 'a -> 'a -> int = "compare" "noalloc"

let min x y = if x <= y then x else y
let max x y = if x >= y then x else y

external (==) : 'a -> 'a -> bool = "%eq"
external (!=) : 'a -> 'a -> bool = "%noteq"

(* Boolean operations *)

external not : bool -> bool = "%boolnot"
external (&) : bool -> bool -> bool = "%sequand"
external (&&) : bool -> bool -> bool = "%sequand"
external (or) : bool -> bool -> bool = "%sequor"
external (||) : bool -> bool -> bool = "%sequor"

(* Integer operations *)

external (~-) : int -> int = "%negint"
external succ : int -> int = "%succint"
external pred : int -> int = "%predint"
external (+) : int -> int -> int = "%addint"
external (-) : int -> int -> int = "%subint"
external ( * ) : int -> int -> int = "%mulint"
external (/) : int -> int -> int = "%divint"
external (mod) : int -> int -> int = "%modint"

let abs x = if x >= 0 then x else -x

external (land) : int -> int -> int = "%andint"
external (lor) : int -> int -> int = "%orint"
external (lxor) : int -> int -> int = "%xorint"

let lnot x = x lxor (-1)

external (lsl) : int -> int -> int = "%lslint"
external (lsr) : int -> int -> int = "%lsrint"
external (asr) : int -> int -> int = "%asrint"

let min_int = 1 lsl (if 1 lsl 31 = 0 then 30 else 62)
let max_int = min_int - 1

(* Floating-point operations *)

external (~-.) : float -> float = "%negfloat"
external (+.) : float -> float -> float = "%addfloat"
external (-.) : float -> float -> float = "%subfloat"
external ( *. ) : float -> float -> float = "%mulfloat"
external (/.) : float -> float -> float = "%divfloat"
external ( ** ) : float -> float -> float = "power_float" "pow" "float"
external exp : float -> float = "exp_float" "exp" "float"
external acos : float -> float = "acos_float" "acos" "float"
external asin : float -> float = "asin_float" "asin" "float"
external atan : float -> float = "atan_float" "atan" "float"
external atan2 : float -> float -> float = "atan2_float" "atan2" "float"
external cos : float -> float = "cos_float" "cos" "float"
external cosh : float -> float = "cosh_float" "cosh" "float"
external log : float -> float = "log_float" "log" "float"
external log10 : float -> float = "log10_float" "log10" "float"
external sin : float -> float = "sin_float" "sin" "float"
external sinh : float -> float = "sinh_float" "sinh" "float"
external sqrt : float -> float = "sqrt_float" "sqrt" "float"
external tan : float -> float = "tan_float" "tan" "float"
external tanh : float -> float = "tanh_float" "tanh" "float"
external ceil : float -> float = "ceil_float" "ceil" "float"
external floor : float -> float = "floor_float" "floor" "float"
external abs_float : float -> float = "%absfloat"
external mod_float : float -> float -> float = "fmod_float" "fmod" "float"
external frexp : float -> float * int = "frexp_float"
external ldexp : float -> int -> float = "ldexp_float"
external modf : float -> float * float = "modf_float" "modf"
external float : int -> float = "%floatofint"
external truncate : float -> int = "%intoffloat"

(* String operations -- more in module String *)

external string_length : string -> int = "ml_string_length"
external string_create: int -> string = "create_string"
external string_blit : string -> int -> string -> int -> int -> unit
                     = "blit_string"

let (^) s1 s2 =
  let l1 = string_length s1 and l2 = string_length s2 in
  let s = string_create (l1 + l2) in
  string_blit s1 0 s 0 l1;
  string_blit s2 0 s l1 l2;
  s

(* Pair operations *)

external fst : 'a * 'b -> 'a = "%field0"
external snd : 'a * 'b -> 'b = "%field1"

(* String conversion functions *)

external format_int: string -> int -> string = "format_int"
external format_float: string -> float -> string = "format_float"

let string_of_bool b =
  if b then "true" else "false"

let bool_of_string = function
  | "true" -> true
  | "false" -> false
  | _ -> invalid_arg "bool_of_string"

let string_of_int n =
  format_int "%d" n

external int_of_string : string -> int = "int_of_string"

let string_of_float f =
  format_float "%.12g" f

external float_of_string : string -> float = "float_of_string"

(* ix: OCaml's later functions, None for a Failure *)
let int_of_string_opt s = try Some (int_of_string s) with Failure _ -> None
let float_of_string_opt s = try Some (float_of_string s) with Failure _ -> None

(* List operations -- more in module List *)

let rec (@) l1 l2 =
  match l1 with
    [] -> l2
  | hd :: tl -> hd :: (tl @ l2)

(* I/O operations *)

type in_channel
type out_channel

external open_descriptor_out: int -> out_channel = "caml_open_descriptor"
external open_descriptor_in: int -> in_channel = "caml_open_descriptor"

let stdin  = open_descriptor_in 0
let stdout = open_descriptor_out 1
let stderr = open_descriptor_out 2

(* General output functions *)

type open_flag =
    Open_rdonly | Open_wronly | Open_append
  | Open_creat | Open_trunc | Open_excl
  | Open_binary | Open_text | Open_nonblock

external open_desc: string -> open_flag list -> int -> int = "sys_open"

let open_out_gen mode perm name =
  open_descriptor_out(open_desc name mode perm)

let open_out name =
  open_out_gen [Open_wronly; Open_creat; Open_trunc] 0o666 name

external flush : out_channel -> unit = "caml_flush"

external unsafe_output : out_channel -> string -> int -> int -> unit
                       = "caml_output"

external output_char : out_channel -> char -> unit = "caml_output_char"

let output_string oc s =
  unsafe_output oc s 0 (string_length s)

let output oc s ofs len =
  if ofs < 0 or ofs + len > string_length s
  then invalid_arg "output"
  else unsafe_output oc s ofs len

let output_substring = output

external output_byte : out_channel -> int -> unit = "caml_output_char"
external output_binary_int : out_channel -> int -> unit = "caml_output_int"

external marshal_to_channel : out_channel -> 'a -> unit list -> unit
     = "output_value"
let output_value chan v = marshal_to_channel chan v []

external seek_out : out_channel -> int -> unit = "caml_seek_out"
external pos_out : out_channel -> int = "caml_pos_out"
external out_channel_length : out_channel -> int = "caml_channel_size"
external close_out_channel : out_channel -> unit = "caml_close_channel"
let close_out oc = flush oc; close_out_channel oc

(* General input functions *)

let open_in_gen mode perm name =
  open_descriptor_in(open_desc name mode perm)

let open_in name =
  open_in_gen [Open_rdonly] 0 name

(* ix: OCaml's names; a file is binary here, Unix's *)
let open_in_bin = open_in
let open_out_bin = open_out
let set_binary_mode_in (_ : in_channel) (_ : bool) = ()
let set_binary_mode_out (_ : out_channel) (_ : bool) = ()

(* References (ix: before their place in OCaml's, for the signals below) *)

type 'a ref = { mutable contents: 'a }
external ref: 'a -> 'a ref = "%makemutable"
external (!): 'a ref -> 'a = "%field0"
external (:=): 'a ref -> 'a -> unit = "%setfield0"
external incr: int ref -> unit = "%incr"
external decr: int ref -> unit = "%decr"

(* ix: signals. The runtime only notes a signal; its handler is a
 * function of OCaml's, kept here by Sys.signal under the system's
 * number, and run here, where a program waits: when a read or a system
 * call (Unix's) comes back interrupted. The reading functions below
 * then ask again, unless the handler raised (Sys.Break). *)
external signal_pending : unit -> int = "ml_signal_pending"
let signal_handlers : (int * (unit -> unit)) list ref = ref []
let rec run_signals () =
  match signal_pending () with
  | 0 -> ()
  | s ->
      let rec run = function (s', f) :: rest -> if s' = s then f () else run rest | [] -> () in
      run !signal_handlers;
      run_signals ()

external input_char_or : in_channel -> int = "ml_input_char"
external unsafe_char : int -> char = "%identity"
let rec input_char ic =
  let c = input_char_or ic in
  if c >= 0 then unsafe_char c else if c = -1 then raise End_of_file else (run_signals (); input_char ic)

external input_or : in_channel -> string -> int -> int -> int = "caml_input"
let rec unsafe_input ic s ofs len =
  let n = input_or ic s ofs len in
  if n >= 0 then n else (run_signals (); unsafe_input ic s ofs len)

let input ic s ofs len =
  if ofs < 0 or ofs + len > string_length s
  then invalid_arg "input"
  else unsafe_input ic s ofs len

let rec unsafe_really_input ic s ofs len =
  if len <= 0 then () else begin
    let r = unsafe_input ic s ofs len in
    if r = 0
    then raise End_of_file
    else unsafe_really_input ic s (ofs+r) (len-r)
  end

let really_input ic s ofs len =
  if ofs < 0 or ofs + len > string_length s
  then invalid_arg "really_input"
  else unsafe_really_input ic s ofs len

(* ix: OCaml's later function *)
let really_input_string ic n = let s = string_create n in really_input ic s 0 n; s

external scan_line_or : in_channel -> int = "caml_input_scan_line"
let rec input_scan_line ic =
  let n = scan_line_or ic in
  if n = -100000 then (run_signals (); input_scan_line ic) else n

let rec input_line chan =
  let n = input_scan_line chan in
  if n = 0 then                         (* n = 0: we are at EOF *)
    raise End_of_file
  else if n > 0 then begin              (* n > 0: newline found in buffer *)
    let res = string_create (n-1) in
    ignore (unsafe_input chan res 0 (n-1));
    ignore (input_char chan);                    (* skip the newline *)
    res
  end else begin                        (* n < 0: newline not found *)
    let beg = string_create (-n) in
    ignore (unsafe_input chan beg 0 (-n));
    try
      beg ^ input_line chan
    with End_of_file ->
      beg
  end

external code_of_char : char -> int = "%identity"
let input_byte ic = code_of_char (input_char ic)
external input_binary_int : in_channel -> int = "caml_input_int"
external input_value : in_channel -> 'a = "input_value"
external seek_in : in_channel -> int -> unit = "caml_seek_in"
external pos_in : in_channel -> int = "caml_pos_in"
external in_channel_length : in_channel -> int = "caml_channel_size"
external close_in : in_channel -> unit = "caml_close_channel"

(* Output functions on standard output *)

let print_char c = output_char stdout c
let print_string s = output_string stdout s
let print_int i = output_string stdout (string_of_int i)
let print_float f = output_string stdout (string_of_float f)
(* ix: flushed, as OCaml's (ocaml-light's is not) *)
let print_endline s = output_string stdout s; output_char stdout '\n'; flush stdout
let print_newline () = output_char stdout '\n'; flush stdout

(* ix: OCaml's flushes every channel open for writing; here the two
 * the runtime knows of, a program's own being flushed when closed *)
let flush_all () = flush stdout; flush stderr

(* Output functions on standard error *)

let prerr_char c = output_char stderr c
let prerr_string s = output_string stderr s
let prerr_int i = output_string stderr (string_of_int i)
let prerr_float f = output_string stderr (string_of_float f)
let prerr_endline s =
  output_string stderr s; output_char stderr '\n'; flush stderr
let prerr_newline () = output_char stderr '\n'; flush stderr

(* Input functions on standard input *)

let read_line () = flush stdout; input_line stdin
let read_int () = int_of_string(read_line())
let read_float () = float_of_string(read_line())


(* pad: for upward compatibility *)
(*
type ('a, 'b, 'c, 'd) format4 = ('a, 'b, 'c, 'c, 'c, 'd) format6
type ('a, 'b, 'c) format = ('a, 'b, 'c, 'c) format4
*)
(* Miscellaneous *)

external sys_exit : int -> 'a = "sys_exit"

let exit_function = ref (fun () -> flush stdout; flush stderr)

let at_exit f =
  let g = !exit_function in
  exit_function := (fun () -> f(); g())

let do_at_exit () = (!exit_function) ()

let exit retcode =
  do_at_exit ();
  sys_exit retcode

external float_of_int : int -> float = "%floatofint"

(* ix: OCaml's later constants, of their bits (nan is 4.14's) *)
external float_of_bits : int64 -> float = "int64_float_of_bits"
let infinity = float_of_bits 0x7FF0000000000000L
let neg_infinity = float_of_bits 0xFFF0000000000000L
let nan = float_of_bits 0x7FF0000000000001L
let max_float = float_of_bits 0x7FEFFFFFFFFFFFFFL
let min_float = float_of_bits 0x0010000000000000L
let epsilon_float = float_of_bits 0x3CB0000000000000L
external int_of_float : float -> int = "%intoffloat"
