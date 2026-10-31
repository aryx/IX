(* An ML external that names a .NET member (the plan's decision 7): the
 * way ML calls .NET, and C#, without a stub, the call made from the
 * external's ML type:
 *
 *   external sqrt : float -> float = "dotnet:static System.Math::Sqrt"
 *   external upper : string -> string
 *     = "dotnet:instance System.String::ToUpper"
 *   external sub : string -> int -> int -> string
 *     = "dotnet:instance System.String::Substring(int32,int32)"
 *   external length : string -> int
 *     = "dotnet:instance System.String::get_Length() -> int32"
 *
 * static: a static method, its arguments the ML ones; instance: an
 * instance method of the first argument's class, its this. Its
 * parameters' .NET types are the ML types' (an int an int64, a float
 * a float64, a string a String, bytes a uint8[], an abstract type an
 * object, unit none) unless the string gives them (int32, int64,
 * float64, string, bool, char, uint8, object, a class by its full name,
 * System.IO.Stream, an array of one, uint8[]), when the ML values are
 * converted (an int64 to an int32, a char to a UTF-16 unit, an object
 * cast to the class); its result's after ->, converted back (an int32
 * to an int64). System.Console is in its own assembly, the rest of
 * System in System.Runtime:
 *
 *   type stream
 *   external stdout : unit -> stream
 *     = "dotnet:static System.Console::OpenStandardOutput() -> System.IO.Stream"
 *   external write : stream -> bytes -> int -> int -> unit
 *     = "dotnet:instance System.IO.Stream::Write(uint8[],int32,int32)"
 *
 * Which members are there: Microsoft's .NET has them all; mini-dotnet's
 * library has the ones its programs use (runtime/Library.ml), and one
 * an ML program needs is added there under its .NET name, so that the
 * assembly runs the same on both.
 *
 * others:
 * F# calls .NET directly, its types .NET's; OCaml's own externals name
 * C functions (caml_..., "noalloc"), which the runtime's C provides;
 * Java's native methods, JNI, a C function per method named after it;
 * C#'s [DllImport] the other way, .NET calling C. *)

(* a .NET member named by an external: its token, static or not, its
 * this and parameters' .NET types and the ML values' (the ML types',
 * unit's none), its result's .NET type and the ML one's *)
type member = {
  tok : int;
  static : bool;
  into : Signature.t list;
  from : Signature.t list;
  ret : Signature.t;
  ml_ret : Signature.t;
}

(* is the external's string one of these (dotnet:...)? *)
val is_dotnet : string -> bool

(* the member, from the string and the external's ML type *)
val member : Il_code.c -> int -> string -> Scope.ty -> member

(* an ML type's arguments and its result *)
val arrows : Scope.ty -> Scope.ty list * Scope.ty

(* a value converted from a .NET type to another (an int64 to an
 * int32 and back, a char to a UTF-16 unit) *)
val convert : Il_code.c -> Il_code.code -> Signature.t -> Signature.t -> unit

(* a value type's (an int32, an int64, a float64, a bool, a char): an
 * instance method's this then given by its address *)
val is_value : Signature.t -> bool
