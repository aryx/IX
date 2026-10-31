(* Printf's functions given a literal format, compiled: the format's
 * pieces at compile time, as the type checker read it, each conversion
 * a call of the runtime unit's formatter, the pieces joined, the
 * string then where the function puts it:
 *
 *   Printf.printf "%s is %5d\n" name n
 *     ->  Ldloc name                               (%s: itself)
 *         Ldstr " is "; Concat
 *         Ldstr "%5d"; Ldloc n; call Runtime::format_int; Concat
 *         Ldstr "\n"; Concat
 *         call Pervasives::print_string
 *
 * lib_core's Printf interprets the format at run time, a string, and
 * builds its result's closures with Obj.magic: untyped, what .NET's
 * delegates, typed, cannot be without casts the verifier refuses
 * (decision 6's "untyped corners" of lib_core). printf, eprintf,
 * sprintf, fprintf, bprintf, ksprintf with all their arguments; %d %i
 * %u %x %X %o (an int, an int32's, an int64's), %f %e %E %g %G, %s, %c,
 * %b, %!, flags, width and precision. Refused: %a and %t (a printer of
 * the program's), a format that is not a literal, a printf given fewer
 * arguments (Printf's own then, which does not run here).
 *
 * others:
 * F#'s printf is typed as this one (the format's type from its
 * literal) and run by FSharp.Core, a cache of each format's parsed
 * pieces; C#'s interpolated strings ($"{name} is {n,5}") are compiled
 * as here, a DefaultInterpolatedStringHandler's appends; OCaml's own
 * is CamlinternalFormat's GADT, typed, interpreted at run time. *)

(* is it a call of one of Printf's functions with a literal format? *)
val applies : string -> Scope.expr list -> bool

(* the call compiled, given the function's symbol, its arguments, and
 * the compiler of an expression (Il_exprs.expr's) *)
val compile :
  Il_code.c -> Il_functions.env -> Il_code.code -> (Scope.expr -> unit) -> Scope.expr -> string -> Scope.expr list -> unit
