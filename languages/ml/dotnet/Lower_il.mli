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
 *     a unit                      a static class, the unit's name
 *     a function of the unit      a static method, its arguments the
 *                                 function's, called directly
 *     a value of the unit         a static field, set by its toplevel
 *     the unit's toplevel         its class's type initializer
 *                                 (.cctor): run before the class's
 *                                 first use, C#'s too (F#'s way)
 *     a.ml b.ml main.ml           one assembly: <Program>.Main calls
 *                                 each unit's (empty) init in link
 *                                 order, so their toplevels run so
 *     B.f, B.t, B.C, B.E          another unit's method, nested class,
 *                                 constructor's class, exception
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
 *     a function's type a -> b    System.Func<A, B>, curried: int ->
 *                                 int -> int a Func<long, Func<long,
 *                                 long>>; unit in it an object, null
 *     fun x -> e                  a class of the variables it
 *                                 captures, its Invoke e; the value
 *                                 an object of it as a Func (ldftn)
 *     f a, f a function value     its Invoke, an argument at a time
 *     add 1, add as a value       a class of the arguments given, its
 *                                 Invoke the next one's; the last
 *                                 calls the method
 *     let rec f x = ... in        a closure whose own field is f
 *     let id x = x                !!0 id<T0>(!!0 x): a generic method,
 *                                 its type's variables its parameters
 *     id 5, id "a"                call id<long>, call id<string>: a
 *                                 MethodSpec, the call's instance
 *     = on 'a                     box !!0, Object::Equals
 *     < on 'a, compare            box !!0, the assembly's helper
 *                                 Stdlib.Ml::compare (strings, ints,
 *                                 floats, chars, booleans)
 *     type 'a tree = ...          a generic class tree`1, its cases'
 *                                 classes generic too (Node`1 :
 *                                 tree`1<!0>); int tree tree`1<long>,
 *                                 its fields and constructor MemberRefs
 *                                 of that instance, as C#'s
 *     'a ref, 'a option           Pervasives' types: Stdlib.ref`1,
 *                                 Stdlib.option`1 in the assembly
 *     ref x, !r, r := v, incr r   newobj, ldfld, stfld contents
 *     a unit field, argument      an object, null (as in a Func)
 *     a * b, (x, y)               Stdlib.tuple`2<A, B>, Item1, Item2
 *     'a list, [], x :: l         Stdlib.list`1, its Nil and Cons
 *     'a array, [| ... |]         T[]: newarr, stelem; a.(i) ldelem,
 *                                 a.(i) <- v stelem, length ldlen
 *     a closure in a polymorphic  a class generic in its type
 *       function                  variables (closure`1<!!0>); a local
 *                                 polymorphic function at the one type
 *                                 its uses give
 *     map f (partly), map as a    the classes of a partial application
 *       value                     generic too, at what the use gives;
 *                                 string_of_int as a value, a class
 *                                 whose Invoke is its call
 *     a call in tail position     tail. call; ret (a function value's
 *                                 last Invoke too): a loop written as
 *                                 a tail recursion runs in one frame
 *
 *     shapes.ml                   interop.cs (tests/)
 *     type shape =                Shapes.shape s =
 *       Rect of point * point       new Shapes.shape.Rect(p, q);
 *     let area s = ...            Shapes.area(s)
 *     match s with Rect ...       switch (s) { case Shapes.shape.Rect r: }
 *     let map_area (f : int ->    Shapes.map_area(a => a + 1, s)
 *       int) s = f (area s)
 *     type 'a box, let wrap x     Shapes.box<string> b = Shapes.wrap("..")
 *     let coordinates p = ...     Shapes.coordinates(q).Item1
 *
 * Stages 1 and 2, 3a: what is not above (a local function used at
 * several types, < on records, a unit not given, and so the library's
 * List or Array, until lib_core is compiled so) is refused by name,
 * the stage that will have it said. Tuples and lists are ML's own classes, not .NET's
 * ValueTuple and ImmutableStack (decision 2's), which mini-dotnet's
 * library has not got yet. A try inside an operand is refused too: IL's rule is
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

(* an assembly of units (mini-ml -dotnet a.ml b.ml main.ml), its name *)
type assembly
val start : string -> assembly

(* a unit's name (its class), its items, checked by Typing with
 * Typing.keep, compiled into the assembly: each unit after those it
 * names, its toplevel its class's type initializer *)
val unit_ : assembly -> string -> Scope.item list -> unit

(* the entry point (each unit's toplevel, in order): the assembly, as
 * its file's bytes *)
(* an overlay unit's functions in place of a unit's (Printf_dotnet's,
 * from, over Printf's, onto): those compiled after it call them *)
val overlay : assembly -> string -> string -> unit

val finish : assembly -> string

(* (Il_code.Refused: what is not compiled yet, its line, what it is) *)
