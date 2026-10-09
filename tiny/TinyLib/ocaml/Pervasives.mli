(* TinyLib: lib_core/core/Pervasives, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Pervasives]: the initially opened module: the built-in types
   and their basic operations, named without [Pervasives.] *)

type ('a,'b) result = Ok of 'a | Error of 'b

val ( @@ ) : ('a -> 'b) -> 'a -> 'b
val ( |> ) : 'a -> ('a -> 'b) -> 'b
(** [x |> f |> g] is [g (f x)]. *)

val ignore : 'a -> unit

(*** Predefined types: the compiler's own
   int, char, string, float, bool, unit, exn, 'a array, 'a list, and
   ('a, 'b, 'c) format: ['a] the parameters' type, ['c] the result of
   the [printf]-style function, ['b] the first argument of [%a] and
   [%t]'s functions (see [Printf]). *)

type 'a option = None | Some of 'a

(*** Exceptions *)

external raise : exn -> 'a = "%raise"
exception Assert_failure of (string * int * int)

(* The compiler's own:
   Match_failure of (string * int * int): no case applies (the file,
     the first and last characters)
   Invalid_argument of string: the arguments do not make sense
   Failure of string: undefined on these arguments
   Not_found, End_of_file, Division_by_zero
   Out_of_memory, Stack_overflow
   Sys_error of string: an operating system error, from input/output *)

exception Exit
        (* Raised by no library function. *)

val invalid_arg: string -> 'a
val failwith: string -> 'a

(*** Comparisons *)

external (=) : 'a -> 'a -> bool = "%equal"
        (* Structural equality. *)
external (<>) : 'a -> 'a -> bool = "%notequal"
external (<) : 'a -> 'a -> bool = "%lessthan"
external (>) : 'a -> 'a -> bool = "%greaterthan"
external (<=) : 'a -> 'a -> bool = "%lessequal"
external (>=) : 'a -> 'a -> bool = "%greaterequal"
        (* Structural ordering. *)
external compare: 'a -> 'a -> int = "compare" "noalloc"
        (* [0] if [x=y], negative if [x<y], positive if [x>y]. *)
val min: 'a -> 'a -> 'a
val max: 'a -> 'a -> 'a
external (==) : 'a -> 'a -> bool = "%eq"
        (* Physical equality. *)
external (!=) : 'a -> 'a -> bool = "%noteq"

(*** Boolean operations *)

external not : bool -> bool = "%boolnot"
external (&&) : bool -> bool -> bool = "%sequand"
external (||) : bool -> bool -> bool = "%sequor"

external (&) : bool -> bool -> bool = "%sequand"
external (or) : bool -> bool -> bool = "%sequor"

(*** Integer arithmetic *)

(* Integers are 31 bits wide (63 on 64-bit processors); operations are
   modulo 2^31 (2^63) and do not fail on overflow. *)

external (~-) : int -> int = "%negint"
external succ : int -> int = "%succint"
external pred : int -> int = "%predint"
external (+) : int -> int -> int = "%addint"
external (-) : int -> int -> int = "%subint"
external ( * ) : int -> int -> int = "%mulint"
external (/) : int -> int -> int = "%divint"
external (mod) : int -> int -> int = "%modint"
        (* Raise [Division_by_zero] if the second argument is 0. *)
val abs : int -> int
val max_int: int
val min_int: int


(** Bitwise operations *)

external (land) : int -> int -> int = "%andint"
external (lor) : int -> int -> int = "%orint"
external (lxor) : int -> int -> int = "%xorint"
val lnot: int -> int
external (lsl) : int -> int -> int = "%lslint"
external (lsr) : int -> int -> int = "%lsrint"
        (* Zeroes inserted (a logical shift). *)
external (asr) : int -> int -> int = "%asrint"
        (* The sign bit replicated (an arithmetic shift). *)

(*** Floating-point arithmetic *)

(* IEEE 754 double precision (64 bits). Operations do not fail on
   overflow or underflow. *)

external (~-.) : float -> float = "%negfloat"
external (+.) : float -> float -> float = "%addfloat"
external (-.) : float -> float -> float = "%subfloat"
external ( *. ) : float -> float -> float = "%mulfloat"
external (/.) : float -> float -> float = "%divfloat"



external floor : float -> float = "floor_float" "floor" "float"
external float : int -> float = "%floatofint"

(*** Strings, and conversions to and from them *)

val (^) : string -> string -> string

val string_of_bool : bool -> string

val bool_of_string : string -> bool
(** Raise [Invalid_argument "bool_of_string"] if not ["true"] or ["false"]. *)

val string_of_int : int -> string
external int_of_string : string -> int = "int_of_string"
        (* Raise [Failure "int_of_string"] if not an integer. *)
external float_of_string : string -> float = "float_of_string"

(*** Pairs and lists *)

external fst : 'a * 'b -> 'a = "%field0"
external snd : 'a * 'b -> 'b = "%field1"

val (@) : 'a list -> 'a list -> 'a list

(*** Input/output *)

type in_channel
type out_channel

val stdin : in_channel
val stdout : out_channel
val stderr : out_channel

(** Output functions on standard output *)

val print_char : char -> unit
val print_string : string -> unit
val print_int : int -> unit
val print_endline : string -> unit
val print_newline : unit -> unit
        (* And flush standard output. *)

(** Output functions on standard error *)

val prerr_string : string -> unit
val prerr_endline : string -> unit
        (* And flush standard error. *)

(** Input functions on standard input: standard output flushed first *)

val read_line : unit -> string
val read_float : unit -> float

(** General output functions *)

type open_flag =
    Open_rdonly | Open_wronly | Open_append
  | Open_creat | Open_trunc | Open_excl
  | Open_binary | Open_text | Open_nonblock
        (* Opening modes for [open_out_gen] and [open_in_gen]. *)
           
val open_out_gen : open_flag list -> int -> string -> out_channel
        (* [open_out_gen mode rights filename] *)
val flush : out_channel -> unit
val output_char : out_channel -> char -> unit
val output_string : out_channel -> string -> unit
val output : out_channel -> bytes -> int -> int -> unit
        (* [output chan buff ofs len]. Raise [Invalid_argument "output"]
           if [ofs] and [len] are not a valid range of [buff]. *)

val output_substring : out_channel -> string -> int -> int -> unit

(* ix: no output_value, nor input_value below: Marshal's to_channel and
 * from_channel, which are ML (this module is the first: it cannot name them) *)
val close_out : out_channel -> unit
        (* Flushed first. *)

(** General input functions *)

val open_in : string -> in_channel
        (* Raise [Sys_error] if the file could not be opened. *)
val open_in_gen : open_flag list -> int -> string -> in_channel
val input_char : in_channel -> char
        (* Raise [End_of_file] if there is no more. *)
val input_line : in_channel -> string
        (* To a newline, not returned. Raise [End_of_file] if the end
           of the file is at the beginning of the line. *)
val input : in_channel -> bytes -> int -> int -> int
        (* [input chan buff ofs len]: at most [len] characters; how
           many were read. *)
val really_input : in_channel -> bytes -> int -> int -> unit
        (* As [input], all [len] characters. Raise [End_of_file] if the
           file ends before, [Invalid_argument "really_input"] if
           [ofs] and [len] are not a valid range of [buff]. *)
val close_in : in_channel -> unit

(*** References *)

type 'a ref = { mutable contents: 'a }
external ref : 'a -> 'a ref = "%makemutable"
external (!) : 'a ref -> 'a = "%field0"
external (:=) : 'a ref -> 'a -> unit = "%setfield0"
external incr : int ref -> unit = "%incr"
external decr : int ref -> unit = "%decr"


(*** Program termination *)

val exit : int -> 'a
        (* [stdout] and [stderr] flushed, then the process ends with
           this status. An [exit 0] is done when a program ends
           normally, not when it ends by an uncaught exception. *)

val at_exit: (unit -> unit) -> unit
        (* A function to call when the program ends. *)


(*** For system use only, not for the casual user *)

val unsafe_really_input : in_channel -> bytes -> int -> int -> unit

val do_at_exit: unit -> unit

external float_of_int : int -> float = "%floatofint"

external int_of_float : float -> int = "%intoffloat"
(** Truncated. *)

(* ix: OCaml's later functions: int_of_string, None for a Failure *)
val int_of_string_opt : string -> int option

(* open_in and open_out: a file is binary here, Unix's *)

(* the floats' limits: the infinities, a float that is not a number,
 * the largest float, the smallest normal one, and 1.0's distance to
 * the next float *)
val infinity : float
val neg_infinity : float
val nan : float
val max_float : float
val min_float : float
val epsilon_float : float

(* stdout and stderr flushed (OCaml's: every channel open for writing) *)
val flush_all : unit -> unit

(* ix: signals (not OCaml's Stdlib's: Sys.signal's and Unix's own).
 * The handlers by the system's signal number, and those of the signals
 * noted since the last time, run: where a program waits. *)
val signal_handlers : (int * (unit -> unit)) list ref
val run_signals : unit -> unit
