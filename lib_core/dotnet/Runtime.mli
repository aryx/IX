(* The runtime of mini-ml -dotnet: Pervasives' externals of C, the
 * native runtime's (languages/ml/runtime/*.c), written in ML over .NET's
 * members (the plan_dotnet_languages.md's stage 3b, its decision 7's
 * externals). mini-ml -dotnet -L lib_core compiles it first, into the
 * program's assembly, and a call of an external of C is a call of the
 * function here of its name:
 *
 *   Pervasives.mli   external sqrt : float -> float = "sqrt_float" ...
 *   program.ml       sqrt 2.0
 *   assembly         call float64 Runtime::sqrt_float(float64)
 *   Runtime.ml       let sqrt_float x = m_sqrt x
 *                    external m_sqrt : float -> float
 *                      = "dotnet:static System.Math::Sqrt"
 *
 * So the assembly is .NET's alone, and Microsoft's dotnet runs it as
 * mini-dotnet does (the author: "We do want to run what is produced by
 * mini-ml -dotnet with the microsoft's dotnet and runtime"); a member
 * mini-dotnet lacks is added to its library under its .NET name
 * (languages/dotnet/runtime/Library.ml: System.Math, Double's Parse and
 * ToString(format)). What ML can do itself is ML here: int_of_string,
 * format_int, strtod's syntax; .NET does what needs exact rounding, a
 * decimal number read (Double.Parse) and a float's digits (its E and F
 * formats), from which C's %e, %f and %g are made.
 *
 * bytes are .NET's byte[] (the author's choice: "byte[] + Streams"),
 * a string a System.String of a byte a char: a %identity between them
 * a copy, by string_of_bytes and bytes_of_string here (Latin-1). The
 * channels are the native's, a buffer of 4096 bytes, over a .NET
 * Stream instead of a descriptor: the console's (Console's
 * OpenStandardOutput..., its bytes as they are, whatever its encoding)
 * or a file's (File's OpenRead, OpenWrite, Create, no enum to name);
 * the descriptors numbers in a table of them, as sys_open returns one.
 *
 *   Pervasives      stdout = open_descriptor_out 1
 *                     |  external ... = "caml_open_descriptor"
 *   Runtime         { stream = Console.OpenStandardOutput(); buf; ... }
 *                     |  output_string: caml_output, a byte at a time
 *                     |  into buf; flush: Stream.Write(buf, 0, len)
 *   .NET            System.IO.Stream (mini-dotnet's: the console's
 *                   channel, a file's descriptor)
 *
 * Differences with the native runtime: an int is an int64 (63 bits
 * natively), so %x of a negative int has 16 digits and int_of_string
 * wraps at 64 bits; no signals (ml_signal_pending 0); a file's
 * permissions not given (.NET's own); an error of .NET's (a file it
 * cannot open though it is there) its exception, not Sys_error.
 *
 * others:
 * OCaml's own runtime: C (floats.c, ints.c, io.c...), its primitives
 * named in the externals; js_of_ocaml's: JavaScript functions of the
 * primitives' names (runtime/*.js), the same idea as this unit;
 * F#'s FSharp.Core: F# over .NET, its printf in F#. *)

(* Floats: C's math, by System.Math *)
val power_float : float -> float -> float
val exp_float : float -> float
val acos_float : float -> float
val asin_float : float -> float
val atan_float : float -> float
val atan2_float : float -> float -> float
val cos_float : float -> float
val cosh_float : float -> float
val log_float : float -> float
val log10_float : float -> float
val sin_float : float -> float
val sinh_float : float -> float
val sqrt_float : float -> float
val tan_float : float -> float
val tanh_float : float -> float
val ceil_float : float -> float
val floor_float : float -> float
val fmod_float : float -> float -> float
val frexp_float : float -> float * int
val ldexp_float : float -> int -> float
val modf_float : float -> float * float

(* Numbers read: OCaml's syntax (0x, 0o, 0b, _), strtod's *)
val int_of_string : string -> int
val float_of_string : string -> float

(* Numbers written: printf's %[-0+ #]width[.precision] and d i u x X o,
 * or e E f F g G *)
val format_int : string -> int -> string
val format_float : string -> float -> string

(* Bytes: a byte[] made, a string's bytes copied into one; the %identity
 * between bytes and string, which the compiler calls *)
val create_string : int -> bytes
val blit_string : string -> int -> bytes -> int -> int -> unit
val string_of_bytes : bytes -> string
val bytes_of_string : string -> bytes

(* Channels: an in_channel's too (an object both, out_channel says it);
 * ml_input_char -1 at the end, caml_input_scan_line the native's *)
val caml_open_descriptor : int -> out_channel
val caml_flush : out_channel -> unit
val caml_output_char : out_channel -> char -> unit
val caml_output : out_channel -> string -> int -> int -> unit
val caml_output_int : out_channel -> int -> unit
val ml_input_char : out_channel -> int
val caml_input : out_channel -> bytes -> int -> int -> int
val caml_input_scan_line : out_channel -> int
val caml_close_channel : out_channel -> unit
val caml_pos_out : out_channel -> int
val caml_pos_in : out_channel -> int
val caml_channel_size : out_channel -> int
val caml_seek_in : out_channel -> int -> unit
val caml_seek_out : out_channel -> int -> unit
val caml_input_int : out_channel -> int
val ml_signal_pending : unit -> int

(* The system: a file opened, its descriptor; Environment.Exit *)
val sys_open : string -> open_flag list -> int -> int
val sys_exit : int -> unit
