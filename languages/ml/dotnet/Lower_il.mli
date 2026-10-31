(* mini-ml to .NET (mini-ml -dotnet): a unit's checked tree (Scope's,
 * with the types Typing keeps) as an assembly's bytes (Writer), which
 * mini-dotnet and Microsoft's dotnet both run
 * (plan_dotnet_languages.md, stage 1). Typed, as F# is: an ML value is
 * the .NET value of its type, nothing boxed or tagged, so C# reads it
 * as its own (decision 2):
 *
 *     ML                          .NET
 *     int                         int64 (OCaml's 63 bits, near enough)
 *     bool, char                  bool, int32 (a char a byte)
 *     float                       float64
 *     string                      System.String
 *     unit                        nothing: void, no argument, no local
 *     the unit                    a static class, the unit's name
 *     a function of the unit      a static method, its arguments the
 *                                 function's, called directly
 *     a value of the unit         a static field, set by Main
 *     the toplevel's code         Main, the entry point, in order
 *     + - * / mod, comparisons    add, sub, mul, div, rem, clt...;
 *                                 a string's by String::CompareOrdinal
 *     print_int, print_string     Console::Write, WriteLine
 *     string_of_int, ^            Int64's ToString, String::Concat
 *     a record type               a class nested in the unit's, its
 *                                 fields public, its constructor
 *                                 taking them in order
 *     a variant type              an abstract class; a class a
 *                                 constructor, nested in it, its
 *                                 arguments the fields Item1...
 *     = on them                   Equals, overridden: field by field
 *                                 (GetHashCode too: F#'s structural
 *                                 equality, so C# compares them)
 *     an exception                a class of System.Exception's;
 *                                 Failure, Not_found... Stdlib's,
 *                                 Division_by_zero .NET's own
 *     raise, try ... with         throw; a catch of Exception, the
 *                                 handler's cases on it, rethrow
 *     match                       the cases tried in order: isinst
 *                                 and fields, constants, ranges
 *
 *     shapes.ml                   interop.cs (tests/)
 *     type shape =                Shapes.shape s =
 *       Rect of point * point       new Shapes.shape.Rect(p, q);
 *     let area s = ...            Shapes.area(s)
 *     match s with Rect ...       switch (s) { case Shapes.shape.Rect r: }
 *
 * Stages 1a and 1b: what is not above (closures, polymorphism, tuples
 * and lists, other units) is refused by name, the stage that will
 * have it said. A try inside an operand is refused too: IL's rule is
 * that a protected region starts with an empty stack (Tiger's
 * emitter met it: Microsoft's JIT refuses it), so its value is made a
 * variable's first.
 *
 * design:
 * Where simple/Lower (the native back end) forgets the types and
 * makes every value a word, a tagged integer or a pointer to a block
 * (OCaml's uniform representation, which the collector needs), this
 * lowering asks Typing each expression's type and gives each its
 * .NET type: what F# and SML.NET do, and what makes an ML int a C#
 * long. The cost is that each construct of ML has to be put on the
 * CTS's (a variant a class a case, a closure a delegate), which the
 * stages after this one do.
 *
 * others:
 * F# (Don Syme, 2005) is this, done whole; SML.NET (Benton, Kennedy,
 * Russo, 2004) the same for Standard ML, whole program; OCamIL (Paris
 * 6) took the other way, every value an object, close to OCaml's own
 * representation, and paid for it at every call into .NET's library. *)

(* the unit's name (its class), its items, checked by Typing with
 * Typing.keep: the assembly, as its file's bytes *)
val unit_ : string -> Scope.item list -> string

(* (Il_code.Refused: what is not compiled yet, its line, what it is) *)
