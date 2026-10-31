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
 * Differences with the native runtime: an int is an int64 (63 bits
 * natively), so %x of a negative int has 16 digits and int_of_string
 * wraps at 64 bits. Not yet: the channels, bytes (create_string,
 * blit_string), sys_exit.
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
