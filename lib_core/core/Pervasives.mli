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

(* ported from ocaml 4.02.2 *)

type ('a,'b) result = Ok of 'a | Error of 'b

(* ported from ocaml 4.0 *)

val ( @@ ) : ('a -> 'b) -> 'a -> 'b
val ( |> ) : 'a -> ('a -> 'b) -> 'b
(** Reverse-application operator: [x |> f |> g] is exactly equivalent to [g
    (f (x))]. *)

(* ported from ocaml 3.12 *)

val ignore : 'a -> unit (*= "%ignore"*)
(** Discard the value of its argument and return [()]. *)

(* pad: for upward compatibility *)
(*
type ('a, 'b, 'c, 'd) format4 = ('a, 'b, 'c, 'c, 'c, 'd) format6
type ('a, 'b, 'c) format = ('a, 'b, 'c, 'c) format4
*)


(* Module [Pervasives]: the initially opened module *)

(* This module provides the built-in types (numbers, booleans,
   strings, exceptions, references, lists, arrays, input-output channels, ...)
   and the basic operations over these types.

   This module is automatically opened at the beginning of each compilation.
   All components of this module can therefore be referred by their short
   name, without prefixing them by [Pervasives]. *)

(*** Predefined types *)

(*- type int *)
        (* The type of integer numbers. *)
(*- type char *)
        (* The type of characters. *)
(*- type string *)
        (* The type of character strings. *)
(*- type float *)
        (* The type of floating-point numbers. *)
(*- type bool *)
        (* The type of booleans (truth values). *)
(*- type unit = () *)
        (* The type of the unit value. *)

(*- type exn *)
        (* The type of exception values. *)
(*- type 'a array *)
        (* The type of arrays whose elements have type ['a]. *)
(*- type 'a list = [] | :: of 'a * 'a list *)
        (* The type of lists whose elements have type ['a]. *)

(*- type ('a, 'b, 'c) format *)
        (* The type of format strings. ['a] is the type of the parameters
           of the format, ['c] is the result type for the [printf]-style
           function, and ['b] is the type of the first argument given to
           [%a] and [%t] printing functions (see module [Printf]). *)

type 'a option = None | Some of 'a
        (* The type of optional values. *)

(*** Exceptions *)

external raise : exn -> 'a = "%raise"
        (* Raise the given exception value *)
(*- exception Match_failure of (string * int * int) *)
        (* Exception raised when none of the cases of a pattern-matching
           apply. The arguments are the location of the pattern-matching
           in the source code (file name, position of first character,
           position of last character). *)
exception Assert_failure of (string * int * int)
        (* Exception raised when an assertion fails. *)

(*- exception Invalid_argument of string *)
        (* Exception raised by library functions to signal that the given
           arguments do not make sense. *)
(*- exception Failure of string *)
        (* Exception raised by library functions to signal that they are
           undefined on the given arguments. *)
(*- exception Not_found *)
        (* Exception raised by search functions when the desired object
           could not be found. *)
(*- exception Out_of_memory *)
        (* Exception raised by the garbage collector
           when there is insufficient memory to complete the computation. *)
(*- exception Stack_overflow *)
        (* Exception raised by the bytecode interpreter when the evaluation
           stack reaches its maximal size. This often indicates infinite
           or excessively deep recursion in the user's program. *)
(*- exception Sys_error of string *)
        (* Exception raised by the input/output functions to report
           an operating system error. *)
(*- exception End_of_file *)
        (* Exception raised by input functions to signal that the
           end of file has been reached. *)
(*- exception Division_by_zero *)
        (* Exception raised by division and remainder operations
           when their second argument is null. *)

exception Exit
        (* This exception is not raised by any library function. *)

val invalid_arg: string -> 'a
        (* Raise exception [Invalid_argument] with the given string. *)
val failwith: string -> 'a
        (* Raise exception [Failure] with the given string. *)

(*** Comparisons *)

external (=) : 'a -> 'a -> bool = "%equal"
        (* [e1 = e2] tests for structural equality of [e1] and [e2]. *)
external (<>) : 'a -> 'a -> bool = "%notequal"
        (* Negation of [(=)]. *)
external (<) : 'a -> 'a -> bool = "%lessthan"
external (>) : 'a -> 'a -> bool = "%greaterthan"
external (<=) : 'a -> 'a -> bool = "%lessequal"
external (>=) : 'a -> 'a -> bool = "%greaterequal"
        (* Structural ordering functions. *)
external compare: 'a -> 'a -> int = "compare" "noalloc"
        (* [compare x y] returns [0] if [x=y], a negative integer if [x<y],
           and a positive integer if [x>y]. *)
val min: 'a -> 'a -> 'a
        (* Return the smaller of the two arguments. *)
val max: 'a -> 'a -> 'a
        (* Return the greater of the two arguments. *)
external (==) : 'a -> 'a -> bool = "%eq"
        (* [e1 == e2] tests for physical equality of [e1] and [e2]. *)
external (!=) : 'a -> 'a -> bool = "%noteq"
        (* Negation of [(==)]. *)

(*** Boolean operations *)

external not : bool -> bool = "%boolnot"
        (* The boolean negation. *)
external (&&) : bool -> bool -> bool = "%sequand"
        (* The boolean ``and''. *)
external (||) : bool -> bool -> bool = "%sequor"
        (* The boolean ``or''. *)

external (&) : bool -> bool -> bool = "%sequand"
external (or) : bool -> bool -> bool = "%sequor"

(*** Integer arithmetic *)

(* Integers are 31 bits wide (or 63 bits on 64-bit processors).
   All operations are taken modulo $2^{31}$ (or $2^{63}$).
   They do not fail on overflow. *)

external (~-) : int -> int = "%negint"
        (* Unary negation. *)
external succ : int -> int = "%succint"
        (* [succ x] is [x+1]. *)
external pred : int -> int = "%predint"
        (* [pred x] is [x-1]. *)
external (+) : int -> int -> int = "%addint"
        (* Integer addition. *)
external (-) : int -> int -> int = "%subint"
        (* Integer subtraction. *)
external ( * ) : int -> int -> int = "%mulint"
        (* Integer multiplication. *)
external (/) : int -> int -> int = "%divint"
external (mod) : int -> int -> int = "%modint"
        (* Integer division and remainder. Raise [Division_by_zero] if the
           second argument is 0. *)
val abs : int -> int
        (* Return the absolute value of the argument. *)
val max_int: int
val min_int: int
        (* The greatest and smallest representable integers. *)


(** Bitwise operations *)

external (land) : int -> int -> int = "%andint"
        (* Bitwise logical and. *)
external (lor) : int -> int -> int = "%orint"
        (* Bitwise logical or. *)
external (lxor) : int -> int -> int = "%xorint"
        (* Bitwise logical exclusive or. *)
val lnot: int -> int
        (* Bitwise logical negation. *)
external (lsl) : int -> int -> int = "%lslint"
        (* [n lsl m] shifts [n] to the left by [m] bits. *)
external (lsr) : int -> int -> int = "%lsrint"
        (* [n lsr m] shifts [n] to the right by [m] bits, zeroes inserted
           (a logical shift). *)
external (asr) : int -> int -> int = "%asrint"
        (* [n asr m] shifts [n] to the right by [m] bits, the sign bit
           replicated (an arithmetic shift). *)

(*** Floating-point arithmetic *)

(* On most platforms, Caml's floating-point numbers follow the
   IEEE 754 standard, using double precision (64 bits) numbers.
   Floating-point operations do not fail on overflow or underflow,
   but return denormal numbers. *)

external (~-.) : float -> float = "%negfloat"
        (* Unary negation. *)
external (+.) : float -> float -> float = "%addfloat"
        (* Floating-point addition *)
external (-.) : float -> float -> float = "%subfloat"
        (* Floating-point subtraction *)
external ( *. ) : float -> float -> float = "%mulfloat"
        (* Floating-point multiplication *)
external (/.) : float -> float -> float = "%divfloat"
        (* Floating-point division. *)
external ( ** ) : float -> float -> float = "power_float" "pow" "float"
        (* Exponentiation *)
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
        (* Usual transcendental functions on floating-point numbers. *)
external ceil : float -> float = "ceil_float" "ceil" "float"
external floor : float -> float = "floor_float" "floor" "float"
          (* Round the given float to an integer value: [ceil] up, [floor]
             down. *)
external abs_float : float -> float = "%absfloat"
        (* Return the absolute value of the argument. *)
external mod_float : float -> float -> float = "fmod_float" "fmod" "float"
          (* [fmod a b] returns the remainder of [a] with respect to [b]. *)
external frexp : float -> float * int = "frexp_float"
          (* [frexp f] returns the pair of the significant and the exponent
             of [f] (when [f] is zero, the significant [x] and the exponent
             [n] of [f] are equal to zero; when [f] is non-zero, they are
             defined by [f = x *. 2 ** n]). *)
external ldexp : float -> int -> float = "ldexp_float"
           (* [ldexp x n] returns [x *. 2 ** n]. *)
external modf : float -> float * float = "modf_float" "modf"
           (* [modf f] returns the pair of the fractional and integral part
              of [f]. *)
external float : int -> float = "%floatofint"
        (* Convert an integer to floating-point. *)
external truncate : float -> int = "%intoffloat"
        (* Truncate the given floating-point number to an integer. *)

(*** String operations *)

(* More string operations are provided in module [String]. *)

val (^) : string -> string -> string
        (* String concatenation. *)

(*** String conversion functions *)

val string_of_bool : bool -> string
(* Return the string representation of a boolean. *)

val bool_of_string : string -> bool
(** Convert the given string to a boolean. Raise [Invalid_argument
    "bool_of_string"] if the string is not ["true"] or ["false"]. *)

val string_of_int : int -> string
        (* Return the string representation of an integer, in decimal. *)
external int_of_string : string -> int = "int_of_string"
        (* Convert the given string to an integer. Raise [Failure
           "int_of_string"] if the given string is not a valid
           representation of an integer. *)
val string_of_float : float -> string
        (* Return the string representation of a floating-point number. *)
external float_of_string : string -> float = "float_of_string"
        (* Convert the given string to a float. *)

(*** Pair operations *)

external fst : 'a * 'b -> 'a = "%field0"
        (* Return the first component of a pair. *)
external snd : 'a * 'b -> 'b = "%field1"
        (* Return the second component of a pair. *)

(*** List operations *)

(* More list operations are provided in module [List]. *)

val (@) : 'a list -> 'a list -> 'a list
        (* List concatenation. *)

(*** Input/output *)

type in_channel
type out_channel
        (* The types of input channels and output channels. *)

val stdin : in_channel
val stdout : out_channel
val stderr : out_channel
        (* The standard input, standard output, and standard error output
           for the process. *)

(** Output functions on standard output *)

val print_char : char -> unit
        (* Print a character on standard output. *)
val print_string : string -> unit
        (* Print a string on standard output. *)
val print_int : int -> unit
        (* Print an integer, in decimal, on standard output. *)
val print_float : float -> unit
        (* Print a floating-point number, in decimal, on standard output. *)
val print_endline : string -> unit
        (* Print a string, followed by a newline character, on standard
           output. *)
val print_newline : unit -> unit
        (* Print a newline character on standard output, and flush standard
           output. *)

(** Output functions on standard error *)

val prerr_char : char -> unit
        (* Print a character on standard error. *)
val prerr_string : string -> unit
        (* Print a string on standard error. *)
val prerr_int : int -> unit
        (* Print an integer, in decimal, on standard error. *)
val prerr_float : float -> unit
        (* Print a floating-point number, in decimal, on standard error. *)
val prerr_endline : string -> unit
        (* Print a string, followed by a newline character on standard error
           and flush standard error. *)
val prerr_newline : unit -> unit
        (* Print a newline character on standard error, and flush standard
           error. *)

(** Input functions on standard input *)

val read_line : unit -> string
        (* Flush standard output, then read characters from standard input
           until a newline character is encountered. *)
val read_int : unit -> int
        (* Flush standard output, then read one line from standard input and
           convert it to an integer. Raise [Failure "int_of_string"] if the
           line read is not a valid representation of an integer. *)
val read_float : unit -> float
        (* Flush standard output, then read one line from standard input and
           convert it to a floating-point number. *)

(** General output functions *)

type open_flag =
    Open_rdonly | Open_wronly | Open_append
  | Open_creat | Open_trunc | Open_excl
  | Open_binary | Open_text | Open_nonblock
        (* Opening modes for [open_out_gen] and [open_in_gen]. *)
           
val open_out : string -> out_channel
        (* Open the named file for writing, and return a new output channel
           on that file, positionned at the beginning of the file. Raise
           [Sys_error] if the file could not be opened. *)
val open_out_gen : open_flag list -> int -> string -> out_channel
        (* [open_out_gen mode rights filename] opens the file named
           [filename] for writing, as above. *)
val flush : out_channel -> unit
        (* Flush the buffer associated with the given output channel,
           performing all pending writes on that channel. *)
val output_char : out_channel -> char -> unit
        (* Write the character on the given output channel. *)
val output_string : out_channel -> string -> unit
        (* Write the string on the given output channel. *)
val output : out_channel -> bytes -> int -> int -> unit
        (* [output chan buff ofs len] writes [len] characters from string
           [buff], starting at offset [ofs], to the output channel [chan].
           Raise [Invalid_argument "output"] if [ofs] and [len] do not
           designate a valid substring of [buff]. *)

val output_substring : out_channel -> string -> int -> int -> unit
(** Same as [output] but take a string as argument instead of a byte
    sequence. *)

val output_byte : out_channel -> int -> unit
        (* Write one 8-bit integer (as the single character with that code)
           on the given output channel. *)
val output_binary_int : out_channel -> int -> unit
        (* Write one integer in binary format on the given output channel. *)
(* ix: no output_value, nor input_value below: Marshal's to_channel and
 * from_channel, which are ML (this module is the first: it cannot name them) *)
val seek_out : out_channel -> int -> unit
        (* [seek_out chan pos] sets the current writing position to [pos]
           for channel [chan]. *)
val pos_out : out_channel -> int
        (* Return the current writing position for the given channel. *)
val out_channel_length : out_channel -> int
        (* Return the total length (number of characters) of the given
           channel. *)
val close_out : out_channel -> unit
        (* Close the given channel, flushing all buffered write operations. *)

(** General input functions *)

val open_in : string -> in_channel
        (* Open the named file for reading, and return a new input channel
           on that file, positionned at the beginning of the file. Raise
           [Sys_error] if the file could not be opened. *)
val open_in_gen : open_flag list -> int -> string -> in_channel
        (* [open_in_gen mode rights filename] opens the file named
           [filename] for reading, as above. *)
val input_char : in_channel -> char
        (* Read one character from the given input channel. Raise
           [End_of_file] if there are no more characters to read. *)
val input_line : in_channel -> string
        (* Read characters from the given input channel, until a newline
           character is encountered. Raise [End_of_file] if the end of the
           file is reached at the beginning of line. *)
val input : in_channel -> bytes -> int -> int -> int
        (* [input chan buff ofs len] attempts to read [len] characters from
           channel [chan], storing them in string [buff], starting at
           character number [ofs]. *)
val really_input : in_channel -> bytes -> int -> int -> unit
        (* [really_input chan buff ofs len] reads [len] characters from
           channel [chan], storing them in string [buff], starting at
           character number [ofs]. Raise [End_of_file] if the end of file is
           reached before [len] characters have been read. Raise
           [Invalid_argument "really_input"] if [ofs] and [len] do not
           designate a valid substring of [buff]. *)
val input_byte : in_channel -> int
        (* Same as [input_char], but return the 8-bit integer representing
           the character. Raise [End_of_file] if an end of file was reached. *)
val input_binary_int : in_channel -> int
        (* Read an integer encoded in binary format from the given input
           channel. Raise [End_of_file] if an end of file was reached while
           reading the integer. *)
val seek_in : in_channel -> int -> unit
        (* [seek_in chan pos] sets the current reading position to [pos] for
           channel [chan]. *)
val pos_in : in_channel -> int
        (* Return the current reading position for the given channel. *)
val in_channel_length : in_channel -> int
        (* Return the total length (number of characters) of the given
           channel. *)
val close_in : in_channel -> unit
        (* Close the given channel. *)

(*** References *)

type 'a ref = { mutable contents: 'a }
        (* The type of references (mutable indirection cells) containing a
           value of type ['a]. *)
external ref : 'a -> 'a ref = "%makemutable"
        (* Return a fresh reference containing the given value. *)
external (!) : 'a ref -> 'a = "%field0"
        (* [!r] returns the current contents of reference [r]. *)
external (:=) : 'a ref -> 'a -> unit = "%setfield0"
        (* [r := a] stores the value of [a] in reference [r]. *)
external incr : int ref -> unit = "%incr"
        (* Increment the integer contained in the given reference. *)
external decr : int ref -> unit = "%decr"
        (* Decrement the integer contained in the given reference. *)


(*** Program termination *)

val exit : int -> 'a
        (* Flush all pending writes on [stdout] and [stderr], and terminate
           the process, returning the given status code to the operating
           system (usually 0 to indicate no errors, and a small positive
           integer to indicate failure.) An implicit [exit 0] is performed
           each time a program terminates normally (but not if it terminates
           because of an uncaught exception). *)

val at_exit: (unit -> unit) -> unit
        (* Register the given function to be called at program termination
           time. *)


(*** For system use only, not for the casual user *)

val unsafe_really_input : in_channel -> bytes -> int -> int -> unit

val do_at_exit: unit -> unit

external float_of_int : int -> float = "%floatofint"
(** Convert an integer to floating-point. *)

external int_of_float : float -> int = "%intoffloat"
(** Truncate the given floating-point number to an integer. *)

(* ix: OCaml's later functions: int_of_string and float_of_string, None
 * for a Failure *)
val int_of_string_opt : string -> int option
val float_of_string_opt : string -> float option

(* open_in and open_out: a file is binary here, Unix's *)
val open_in_bin : string -> in_channel
val open_out_bin : string -> out_channel

(* the floats' limits: the infinities, a float that is not a number,
 * the largest float, the smallest normal one, and 1.0's distance to
 * the next float *)
val infinity : float
val neg_infinity : float
val nan : float
val max_float : float
val min_float : float
val epsilon_float : float

(* nothing: a file is binary here *)
val set_binary_mode_in : in_channel -> bool -> unit
val set_binary_mode_out : out_channel -> bool -> unit

(* n characters of the channel, or End_of_file *)
val really_input_string : in_channel -> int -> string

(* stdout and stderr flushed (OCaml's: every channel open for writing) *)
val flush_all : unit -> unit

(* ix: signals (not OCaml's Stdlib's: Sys.signal's and Unix's own).
 * The handlers by the system's signal number, and those of the signals
 * noted since the last time, run: where a program waits. *)
val signal_handlers : (int * (unit -> unit)) list ref
val run_signals : unit -> unit
