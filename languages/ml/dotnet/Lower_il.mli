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
 *     string_of_int, ^            Convert::ToString, String::Concat
 *
 * This is stage 1a, the monomorphic core: what is not above (records,
 * variants, a match, exceptions, closures, polymorphism, other units)
 * is refused by name, the stage that will have it said.
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

(* what is not compiled yet: its line, what it is *)
exception Refused of int * string
