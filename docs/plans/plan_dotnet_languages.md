# Plan: mini-ml, mini-cc and mini-datalog compiled to .NET's IL, and one program of modules in the three languages, calling each other through .NET's one type system (`languages/ml/dotnet/`, `languages/c/dotnet/`, `languages/datalog/dotnet/`)

The author (2026-10-30), offered what plan_dotnet.md left: "ok let's
do mini-ml compiled to IL (note that F# is a similar idea)"; then: "I
wonder if we could have one backend for mini-c too, and
mini-datalog, so we could write a program where each module is
written in a differnet language (C, ML, Datalog) and could call each
other thx to the common runtime"; and: "ideally we could then write
program analysis programs that leverage the best of ML to parse,
frontend, and generate facts and then pass that to datalog, all in
the same program"; "(Like the Flix language, that can do fancy static
analysis using few lines thx to leverage the best of each
"language")".

The short answer: **yes, and it is what .NET was made for.** The C
of CLI is Common: one machine, one type system (the CTS), one
runtime, under every language Microsoft shipped in 2002 (C#, VB, J#,
managed C++) and many it did not (F#, IronPython, Eiffel, COBOL). A
module of one calls a module of another as it calls its own, the
types at the boundary the CTS's. ix has the parts: mini-dotnet runs
the IL and loads the library, its Writer writes assemblies (mini-tiger
and mini-csc use it), and mini-ml's and mini-cc's compilers both lower
to a stack machine (their simple/Ir) close to IL's. What is missing is
three back ends whose values are .NET's own types (no conversion at
a boundary: decision 1), and mini-dotnet loading a program of several
assemblies.

**The program it is for: an analysis of programs, each part in the
language best at it.** ML parses and types (mini-cc's or mini-ml's
own front end) and writes the program as facts; Datalog computes the
analysis (lib_code/datalog/: Andersen's pointer analysis, liveness, the
dominators); ML reads the answers back and reports. Today these are
three processes and files of facts between them (`mini-cc -facts`,
`mini-datalog`); here one program, the facts passed as calls, the
Datalog module's relations filled from ML and queried from it.

The end goal, the author's: "powerful whole-program analysis for C
and OCaml, that hopefully we can leverage to find bugs, or to
optimize things in the long term". For C, points-to first (Andersen's),
then what stands on it: null and freed pointers dereferenced, memory
not freed. For ML, which closures a call reaches (0-CFA), then
exceptions never caught (Leroy and Pessaux's analysis, 2000) and code
never reached; and for mini-ml's optimizer, calls of a known closure
made direct and inlined.

**Status: step 0 done (mini-analyze, native: below); stage 1 done
(mini-ml -dotnet: the monomorphic core, records, variants,
exceptions, match, closures, generic functions and types, tuples,
lists, arrays, several units in one assembly; C# using an ML unit;
2026-10-31: the stages); the rest not built.** For the author: what step 0 showed, decision 6 to be
decided again by it, the open questions at the end.

## Step 0: the program first, native (2026-10-30)

The author: "maybe one thing we could do is first write the final
program we want to write, that is a C and ML static analyzer using
powerful datalog pointer/control-flow analysis and reusing the parsers
we already have in IX"; "maybe we can start with a reduced version of
this final program, to get a better idea, to make things more
concrete". `analyzers/` (mini-analyze, commits d8bb82f7, afb11a4b):
mini-cc's and mini-ml's front ends, their facts handed as values to
mini-datalog's evaluator, pointer.dl, calls.dl and a new bugs.dl, one
program, built by dune. What it showed:

- **The parts fit as values.** Facts and Closure_facts give each fact
  to a hook (`added`), the analyzer adds it as a tuple of symbols:
  the text between the three commands is gone, the boundary is one
  function. Compiled to .NET this is a call of a Datalog module's
  relation's add.
- **OCaml's one namespace of units is in the way.** mini-cc and
  mini-ml both have a Lexer, a Parser, an Emit, unwrapped: one program
  cannot link both. analyzers/c/ compiles mini-cc's front end a second
  time, wrapped (dune's copy_files). .NET's assemblies and namespaces
  keep such units apart (decision 1).
- **Reusing the ML code as is means lib_core comes along.** An ML
  program's facts need its library's units (a closure given to
  List.iter is called there): for mini-datalog's sources, 34 of
  lib_core's units, among them Obj, Format, Printf, Unix, Logs, Cap
  (Ml_front, -v lists them). So decision 6's "from scratch" holds for
  the .NET classes underneath, not for the ML code above: lib_core
  compiled by mini-ml -dotnet, its externals over the subset.
- **The evaluator is the cost.** goken's rc (30 files, 215
  functions): the front end 0.3 s for 7,850 facts, the rules 7 s, 29
  rounds and 20 million lookups for 44,000 tuples. A Datalog compiled
  (decision 5) or better indexes before whole programs of ix. Then
  (2026-10-31, plan_datalog.md's stages 1 and 2): the join's order
  chosen, the rules 0.2 s; mini-ml's own analysis 225 s to 95 s;
  then (plan_ml_multicore.md) 88 s on one core, 14.8 s on 32 of OCaml
  5's domains, the relations hashed or sorted (Souffle's B-trees), a
  relation's choice. The engine's optimization stopped there (the
  author: "let's stop the optimization of mini-datalog and go back on
  the big picture project").
- **The answers are useful and coarse.** rc: `runq->code->f` reaches
  the 46 X instructions of its machine, `bp->fnc` the 11 builtins;
  efree may be given 18 strings, a false alarm of the field-based
  analysis (every ->word one place). Contexts (Doop's) and fields per
  object are where precision comes from (calls.dl's header).

## Precedents

- **Project 7** (Microsoft, 1998-2000, James Plamondon): before .NET
  shipped, some fifteen language groups, academic and commercial,
  given the pre-release runtime to port their languages to: Eiffel,
  Mercury, Haskell, Standard ML, Scheme, Oberon and Component Pascal,
  Python, Perl, COBOL, APL. The common type system was meant to be
  shared by them all, a class from one language subclassed in another,
  and their reports changed it: the `tail.` prefix is there for the
  functional languages, and the generics of .NET 2.0 (Andrew Kennedy
  and Don Syme, PLDI 2001) came from the same research group, with
  ML and Haskell in mind. Syme's ILX of the same years, closures and
  unions lowered to classes, became F#'s back end. This plan is
  Project 7's idea taken at its word: several languages, one type
  system, nothing converted.
- **F#** (Don Syme, Microsoft Research, 2005): an ML for .NET, from
  OCaml's core. Typed all the way: an `int` is an int32, a record a
  class of properties, a variant a class per case under an abstract
  one with a `Tag`, a closure a subclass of `FSharpFunc<'T,'U>` with
  an `Invoke`, polymorphism .NET's generics, a module a static class.
  So F#'s code is .NET's ordinary code, fast, and C# calls it. The SDK
  has its compiler (`fsc.dll`, checked here): the same programs in F#
  can be compared, their IL and their time.
- **SML.NET** (Nick Benton, Andrew Kennedy, Claudio Russo, 2004):
  Standard ML to IL, whole program, its types monomorphised; F#'s
  ancestor in spirit. **OCamIL** (Université Paris 6, the mid-2000s): OCaml's
  compiler to IL, its values uniform (every value an object), the
  other way.
- **lcc.NET** (David Hanson, 2004): C to IL by lcc's back end,
  pointers .NET's unmanaged ones (unverifiable); **C++/CLI** the
  same (`/clr`). **Emscripten** and **WebAssembly** (2017) the other
  way: C's memory one array of bytes, a pointer an index into it.
- **Flix** (Magnus Madsen and others, from 2016; "Fixpoints for the
  Masses: Programming with First-class Datalog Constraints", OOPSLA
  2020): a functional language on the JVM with Datalog inside it,
  its constraints first-class values that a function builds, composes
  and solves, over lattices as well as sets; so an analysis is a few
  rules beside the functions that make its facts and read its
  answers. The aim here, by another road: the languages apart, each
  its own compiler, one type system between them.
- **Soufflé** (Herbert Jordan, Bernhard Scholz, Pavle Subotić, 2016):
  Datalog compiled to C++, a rule's body nested loops over indexed
  relations, the fixpoint semi-naive.

## Where ix is (2026-10-30)

- mini-dotnet (plan_dotnet.md, done): the interpreter, the JIT, its
  library over lib_core (`runtime/Library.ml`); `assembly/Writer.ml`
  writes an assembly from OCaml (types, fields, methods, IL); mini-tiger
  (957 lines) and mini-csc compile to IL through it.
- mini-ml: Ast, typed (Typing), lowered by `simple/Lower` to a stack
  machine (`simple/Ir`: Get/Set slots, Field, Alloc, Call by a symbol
  or a closure's code, TryEnter/Catch, Raise, CallC of the runtime's
  functions), emitted by Gen (or through ssa/ by Emit). 32 runtime
  functions named by Lower; lib_core's units call 130 externals.
- mini-cc: Tree, lowered by `languages/c/simple/Lower` to its own
  stack machine (Ir: loads and stores of sizes, pointers as integers).
- mini-datalog: an interpreter (569 lines): Datalog to tables, a
  fixpoint, queries.
- mini-dotnet resolves another assembly's member only in its own
  library: a program of several assemblies is not loaded yet.

## Decisions (proposed, for the author)

The author (2026-10-30), on a first version that converted values at
the boundaries (an `IxRuntime`): "I'm not so sure about this
IxRuntime; ideally we would not want conversions between languages
but really use the same types!". So the decisions below are those of
.NET itself: one type system, the CTS, which every language's values
*are*, as a C# string and a VB String are the same object.

1. **One program of several assemblies, its values of one type
   system, .NET's (the CTS).** An ML int is an int64, a string a
   System.String, a C# class's object and an ML record's the same kind
   of thing; a module's functions static methods of those types; a
   call into another language a call of them (an AssemblyRef and a
   MemberRef, as C# calls another library), nothing converted.
   mini-dotnet then loads the assemblies a program names.

2. **mini-ml compiled typed, F#'s way.** ML's types are .NET's, and
   where .NET has the construct, its own (the author: "list option and
   tuple should reuse what .NET provides for those types; again, so
   each language map to existing .NET construct or libs so it's easy
   for interop between languages"):

   | ML | .NET |
   |---|---|
   | int, char, bool | int64, int32 (a char a byte), bool |
   | float | double |
   | string | System.String (OCaml's strings immutable, since 4.06) |
   | bytes | byte[] |
   | 'a array | 'a[] |
   | a record | a class of fields (mutable or not) |
   | a variant | an abstract class, a class for each case |
   | a tuple | System.ValueTuple<..> (C#'s tuples, `(long, string)`) |
   | 'a list | System.Collections.Immutable.ImmutableStack<T> |
   | 'a option | Option<T>, None as null (F#'s) |
   | a function | System.Func<T,R> |
   | 'a (polymorphism) | .NET's generics, instantiated at run time |
   | an exception | a class of System.Exception's |
   | a module | a static class |

   ImmutableStack is .NET's cons list: Push a cons, Peek the head, Pop
   the tail, IsEmpty the [] case, shared tails; C# walks it by
   foreach. ValueTuple has the structural Equals and GetHashCode
   already. A function is a Func delegate, so C# passes a lambda where
   ML takes a function; ML's curried functions are Funcs returning
   Funcs, and a call of all the arguments of a known function a
   direct call of its static method (F#'s own optimization). .NET has
   no option for every type (Nullable<T> only of value types, so not
   of a type variable): the one class of ML's own, as in FSharp.Core,
   None the null reference, which C# tests as it tests any null.

   And equality and hashing .NET's: each record and variant class its
   structural Equals and GetHashCode (as F#'s), so Datalog's sets of
   tuples hold ML values as they are, and C# compares them. What it
   costs: mini-ml's Typing keeps its types (today "inferred, then
   forgotten": each expression's type then kept, by its span), and a
   second lowering, the typed tree to IL (pattern matching, closures
   and modules done again for .NET; mini-ml has no functors, so none
   of SML.NET's defunctorization), beside simple/Lower:
   the larger compiler, F#'s. The uniform way (every value an object,
   OCamIL's) is dropped: its values would need converting.

3. **Tail calls** (ML loops are tail recursions): IL's `tail.` prefix,
   which Microsoft's runtime honours and mini-dotnet now ignores (a
   Prefix, a Nop); mini-dotnet then makes a tail call reuse the
   frame, the interpreter's and the JIT's.

4. **C shares the types where they can be shared: a managed C** (the
   author: "Managed C is enough for now"). A
   C int an int32 (a long an int64, a double a double), a struct a
   .NET struct, an array a .NET array, a string a System.String
   (char* given to C as an opaque value, its functions the library's);
   a pointer into an array a managed reference (IL's int32&, which
   mini-dotnet has). What C does that .NET's types do not allow, an
   int made a pointer, a pointer cast to another type, a union read as
   another field, arithmetic past an array: refused by the compiler,
   as C++/CLI's safe mode (/clr:safe) refused it. So it is a C, not
   all of C: lib_core/libc's kind of code (casts, raw memory) stays
   native. (The other way, C's memory one array of bytes as
   WebAssembly's, runs all of C but its values are bytes: converted
   at every call, which this plan's rule refuses.)

5. **mini-datalog compiled** (Soufflé's way), its relations of CTS
   values: a relation a class with a set of tuples of its columns'
   types (an ML variant's class, a string, an int64), an index by the
   columns a body binds first, a rule's body nested loops and
   lookups, the strata's fixpoints semi-naive. A module's input
   relations filled by another language's calls (its facts, ML's
   values), its output relations read (a query: the tuples, the same
   values). Not the interpreter compiled by mini-ml (which would also
   run): the compiler shows the lesson.

6. **The library: a small subset of .NET's, written for it, not
   lib_core** (the author: "it might be easier to have a common .NET
   library written from scratch independently of lib_core; doing
   those adapters and so on might complicate things; hopefully we can
   have a small subset of the .NET core lib that is enough for the
   program we want to write, not all of .NET"). Two layers, both
   grown only as stage 8's program needs them:
   - **.NET's classes, a subset**: System.String, StringBuilder,
     Console, Math, File; List<T>, Dictionary<K,V>, HashSet<T>,
     ImmutableStack<T>, ValueTuple, Func. Their names and behaviour
     .NET's, so a program runs the same by Microsoft's `dotnet`
     (which has the real ones) and by mini-dotnet; for mini-dotnet
     written in C# and compiled by mini-csc to an assembly of IL, a
     few natives under it (a console write, a file read), rather than
     more of runtime/Library.ml's adapters.
   - **each language's own, over that subset**: ML's List, Option,
     String, Hashtbl, a Printf of a few formats, written in ML for
     .NET (not lib_core's units, which stand on 130 externals and
     Obj.magic); C's few libc functions (printf, strlen) over Console
     and String; Datalog's relation class.

   No runtime of conversions: the types are .NET's, shared.

   Revised by step 0: mini-analyze reuses mini-cc's and mini-ml's
   front ends as they are, and they stand on lib_core (34 of its
   units for a small program). So the ML layer is lib_core itself,
   compiled by mini-ml -dotnet, its untyped corners (Obj, Printf's
   formats, Marshal) given .NET forms, its externals over the .NET
   subset; the subset stays from scratch, as the author wanted.

7. **The calls across languages, declared:** in ML an `external` with
   the other side's name (`external area : int -> int = "dotnet:Shapes::area"`);
   in C a prototype with an attribute or a naming convention; in
   Datalog the relations a module declares input and output. Each
   compiler writes the AssemblyRef and MemberRef; types at the
   boundary checked by each compiler against the CTS's.

8. **Checked as plan_dotnet.md checked:** what each program prints by
   Microsoft's `dotnet` and by mini-dotnet, against what the native
   build prints (mini-ml's and mini-cc's own tests, mini-datalog's
   analyses).

## The stages (each checked before the next)

1. **mini-ml typed, its core** (`mini-ml -dotnet`): Typing's types
   kept; ints, floats, strings, records, variants, tuples, closures,
   generics, exceptions, pattern matching, modules; programs without
   the stdlib, printing by Console. Check: a dozen of mini-ml's tests,
   by both runtimes, and C# calling an ML function on an ML record.
   In steps (2026-10-31, the author choosing it over the analyzer's
   precision: what the tree has decides the order: Writer writes no
   GenericParam or MethodSpec rows yet, and mini-dotnet's library has
   neither ValueTuple nor ImmutableStack):
   - 1a. **The monomorphic core**: Typing keeps each expression's
     type (by its span) and each variable's (by its number);
     `languages/ml/dotnet/`'s lowering: int, bool, char, float,
     string, unit; a unit's functions its class's static methods,
     called directly, recursion; its values static fields; let, if,
     sequences, while, for; arithmetic and comparisons; print_*,
     string_of_int, ^ over Console and String. The rest refused by
     name. Check: small programs by mini-dotnet and Microsoft's
     `dotnet`, against the native build's output.
     Done (2026-10-31, the author: "Stage 1: mini-ml -dotnet"):
     `languages/ml/dotnet/Lower_il` (its library copies mini-dotnet's
     Metadata, Signature, Il and Writer: mini-ml does not link the
     runtime); Typing.keep, expr_type, var_type; `mini-ml -dotnet`.
     tests/run.sh: fib, arith, strings, loops, each verified by
     mini-dotnet (-verify), run by it and by Microsoft's dotnet (-ms),
     the same as `ocaml file.ml` prints; by dune's mini-ml and by
     mini-ml's own; nine refusals with their stage. Found: an ML int
     is 63 bits and an int64 64, so `(-1) lsr 60` is 7 by OCaml and
     15 on .NET (the plan's "near enough", now a case); `print_float`
     waits for the library (OCaml's `1.5` and `1.`, not .NET's).
   - 1b. **Records, variants, exceptions, pattern matching**: classes
     (a variant an abstract class and a class a case), exceptions
     System.Exception's, a match by isinst and fields.
     Done (2026-10-31, the author: "let's commit and move forward"):
     the unit's types nested in its class (F#'s: C# names them
     Shapes.point; a namespace of the unit's name beside its class
     tripped C#'s lookup); a record's constructor takes its fields in
     order, a case's its arguments (Item1...); Equals and GetHashCode
     overridden, field by field, so `=` is Equals and C# compares ML
     values as OCaml does; exceptions nested, OCaml's own in Stdlib,
     Division_by_zero .NET's DivideByZeroException (what a division
     throws); try a catch of Exception, the handler's cases on it,
     rethrow; a function of several cases a match on its argument.
     Refused: a try inside an operand (IL's protected region starts
     with an empty stack), an inline record. Checked: variants,
     records, exceptions, equality, by mini-dotnet (verified) and
     Microsoft's dotnet, as `ocaml` prints; stage 1's own check,
     C# using an ML unit (tests/interop.cs on shapes.ml: new
     Shapes.shape.Rect(p, q), Shapes.area(s), Equals, C#'s switch on
     the cases), by Microsoft's csc and dotnet (mini-dotnet: one
     assembly, stage 7).
   - 1c. **Closures**: Func<T,R> (a TypeSpec, which Writer has), local
     functions, partial application, functions passed.
     Done (2026-10-31, the author: "let's commit and move forward"):
     a function type Func<A, B>, curried, unit in it an object (null,
     F#'s unit); a lambda a class of the variables it captures (those
     it names that its method has), its Invoke the body, the value
     its object as a Func (ldftn, newobj); a function of the unit
     given fewer arguments than it takes, or as a value, a class a
     number of arguments given, its Invoke the next one's, the last
     calling the method; more, its result invoked; a call of a
     function value its Invoke, an argument at a time; a local let
     rec a closure whose own field is the Func. Typing kept the type
     of a lambda checked against its place's (Typing.under), which
     it had not. Found by C#: `let f k = fun n -> ...` is ML's
     `f k n`, a method of two arguments, as F#'s. Checked: closures
     (lambdas, captures, partial application, a toplevel function as
     a value, a local let rec, curried, unit arguments, a lambda of
     cases) by both runtimes; C# giving ML a lambda
     (Shapes.map_area(a => a + 1, s)) and calling the Func ML returns.
     Refused: a local let rec of several functions.
   - 1d. **Polymorphism**: Writer's GenericParam and MethodSpec;
     tuples and lists (ValueTuple and ImmutableStack, or ML's own
     classes first if mini-dotnet's library has not got them).
     In three parts (2026-10-31, the author: "let's commit and move
     forward on 1d"). 1d-1 done: Writer.generic_param (GenericParam,
     sorted by owner) and method_spec (MethodSpec, its method's
     provisional token renumbered, called as the method); Typing
     names a type variable by its cell, the same name each time in
     the unit (to_scope_stable), so a polymorphic function's 'a is
     one in its type and in its body; such a function a generic
     method, its type's variables its parameters (!!0...), a call its
     instantiation as the call's own type gives it; = on a type
     variable the boxed value's Equals. Checked: generics (id at ints
     and strings, twice and compose given lambdas, a recursive
     generic, = at ints, strings, records) by both runtimes. Refused
     for now: a polymorphic function as a value or partly applied, a
     closure inside one (their classes would be generic too), one
     at unit. 1d-2 done: a type of parameters a generic class
     (tree`1, T0...), its constructors' classes generic too, their
     parent the variant's at their parameters (Node`1 : tree`1<!0>);
     a use of it at types its instance (tree`1<long>), its fields and
     constructor MemberRefs of that, its own methods (constructor,
     Equals, GetHashCode) through its own instance, a type
     parameter's field boxed for Equals; Pervasives' ref and option
     Stdlib.ref`1 and Stdlib.option`1 in each assembly (until stage
     1e), ref, !, :=, incr, decr; a unit field an object, null; let
     ... and; < and compare at a type variable by the assembly's
     helper Stdlib.Ml::compare (strings ordinal, ints, floats,
     chars, booleans; a record or a variant there, OCaml's structural
     order, thrown as not yet; < on records refused at compile time).
     Found: a function of cases took its argument's type from its
     first pattern, the declared 'a tree, not int tree. Checked:
     generic_types (a tree at ints and strings, functions over it at
     any type, a record of two parameters, option, references in
     loops, = and < on instances) by both runtimes; C# using an ML
     generic record and function (Shapes.box<string>,
     Shapes.wrap(7L)). 1d-3 done: tuples ML's own Stdlib.tuple`n
     (Item1..., ValueTuple's names), lists the language's variant
     Stdlib.list`1 (its cases Nil and Cons, names C# can say; its
     constructors written out, Resolve's tables having not the
     predefined ones), tuple patterns; arrays .NET's own T[] (newarr
     and stelem.any, ldelem.any, ldlen; an index an int32). Found:
     a list literal's sugar gives each cons its element's span, so a
     type kept by span alone was the cons's: Typing keeps them by
     span and the expression's kind. Checked: tuples_lists (tuples
     in and out, patterns, lists built and matched, a generic map
     given a lambda, rev, a lookup in a list of pairs, = on both),
     arrays (literals of ints, strings, records, a sort in place, a
     generic function at two types), by both runtimes; C# reading an
     ML tuple. Not yet, of 1d: a closure inside a polymorphic
     function, or one as a value (generic closure classes); <
     on records (OCaml's structural order); decision 2's ValueTuple,
     ImmutableStack and None as null, which wait for mini-dotnet's
     library to have them.
   - 1e. **Modules**: a unit a static class, several units in one
     assembly.
     Done (2026-10-31, the author: "let's commit and move forward"):
     `mini-ml -dotnet a.ml b.ml main.ml`, each unit checked then
     lowered in turn into one Writer (Lower_il.start, unit_,
     finish), what they share kept (the functions and values by
     symbol, the classes made); another unit's types and exceptions
     nested in that unit's class. A unit's toplevel its class's type
     initializer (.cctor, the class not beforefieldinit), F#'s way:
     run before the class's first use, by C# too (a C# program
     reading an ML unit's value finds it made); <Program>.Main calls
     each unit's empty init in link order, so the toplevels run in
     OCaml's order. Found: Typing gave another unit's value with no
     .mli a fresh variable, not checked, and a function of it was
     compiled a polymorphic one; with -dotnet the units checked
     before are known by their inferred types (Typing.others).
     Checked: tests/units (geometry, counter, main: one unit's
     values, functions, types, constructors, exception from another,
     the toplevels in link order, as OCaml's own compiler's program
     prints) by both runtimes; C# reading Shapes.unit_area, made by
     the unit's toplevel. Left of stage 1: a closure inside a
     polymorphic function and one as a value (generic closure
     classes), < on records (OCaml's structural order); and lib_core
     compiled so (decision 6, revised), the library's units then
     given with the program's.
2. **Tail calls in mini-dotnet** (decision 3). Check: a loop of
   10,000,000 turns written as a tail recursion, by both runtimes.
   Done (2026-10-31, the author: "let's commit and move forward"):
   mini-ml -dotnet compiles a function's body and a closure's Invoke
   in tail position (Lower_il.tail_expr: if's and match's branches, a
   let's body, a sequence's last, never a try), a call there after
   tail. and followed by ret (a function value's last Invoke too; not
   one returning nothing from an Invoke, whose unit is an object).
   mini-dotnet's interpreter honours it: the call is its frame's last
   outcome (Frame.Tail), run_method's loop makes the callee's frame
   in its place, no deeper in OCaml's stack nor in its depth; a
   delegate's Invoke to a method it runs too. The loop of 10,000,000
   turns: mini-dotnet 5.4 s and 8 MB (dune's), 9.9 s and 11 MB
   (mini-ml's build); Microsoft's dotnet 0.08 s. The JIT: a native
   callee is called as any, and a method only tail-called is not
   counted hot, so such a loop stays interpreted (right, not
   compiled). Checked: tests/tails.ml (direct, mutual, over a list,
   through a Func, a local let rec's: a hundred thousand turns,
   where mini-dotnet stops at ten thousand frames) by both runtimes;
   the suite again, every body now in tail position.
3. **The library** (decision 6): the .NET subset in C# by mini-csc,
   then ML's List, Option, String, Hashtbl, Printf over it, each
   grown as a test needs it. Check: the same tests of each class by
   Microsoft's `dotnet` (its real classes) and by mini-dotnet (ours);
   stage 1's tests again, now with ML's library.
4. **Speed**: mini-ml's benchmarks native, on .NET (Microsoft's), on
   mini-dotnet (its JIT), and the same programs in F# (fsc): their IL
   compared, -S beside ildasm's, and their time.
5. **mini-cc to IL, a managed C** (decision 4). Check: mini-cc's
   tests that stay in it, by both runtimes, what the native build
   prints; those refused, counted with their reason.
6. **mini-datalog compiled** (decision 5). Check: its analyses
   (lib_code/datalog/) on mini-cc's and mini-ml's facts, the same answers as
   the interpreter's.
7. **Several assemblies in mini-dotnet** (decision 1): AssemblyRef
   resolved to an assembly beside the program's.
8. **The program in several languages** (decision 7): Andersen's
   points-to on whole C programs, mini-cc's front end (ML) parsing and
   writing facts into a Datalog module (lib_code/datalog/'s rules, compiled),
   the answers read back by ML and printed; a C module where C is the
   better tool (a fast hash of the facts, say). Check: the same
   answers as today's pipeline (`mini-cc -facts`, `mini-datalog`), by
   both runtimes, and on mini-9pi's card. First on a C program as
   the analysis's tests have it, then on one of ix's own (mini-rc's).
9. **ML analysed** (the end goal's other half): mini-ml's front end
   writing an ML program's facts (its closures, calls, raises, handlers),
   0-CFA in Datalog, then the exceptions never caught. Check: on
   mini-ml's tests with a known answer, then on an ix program.

## Sizes (estimates, from the neighbours)

| part | lines |
|---|---:|
| Typing's types kept | 150 |
| mini-ml's typed lowering to IL (simple/Lower 2,500 lines for the machine; Tiger_emit 957) | 2,500 |
| the .NET subset in C# (stage 8's needs) | 600 |
| ML's library for .NET (List, Option, String, Hashtbl, Printf) | 500 |
| tail calls in mini-dotnet | 150 |
| mini-cc's managed back end | 1,000 |
| mini-datalog's compiler | 600 |
| several assemblies in mini-dotnet | 200 |

## Open questions

- The library (decision 6), the author not sure yet: the .NET subset
  in C# compiled by mini-csc (proposed), or kept as
  runtime/Library.ml's adapters over OCaml, which mini-dotnet has
  for String, Console, Dictionary already?
- Step 0's next: Datalog's speed first (the author's choice, done:
  plan_datalog.md), then precision (contexts, Doop's way), or stage 1
  (mini-ml -dotnet)? lib_core compiled to IL: agreed (2026-10-31).
- An ML int: int64 on .NET everywhere (OCaml's 63 bits, near enough),
  where mini-ml's native int is 31 bits on arm: a program printing a
  large int differs between the native build on arm and .NET.
- The directories: each back end in its compiler's directory
  (`languages/ml/dotnet/`, `languages/c/dotnet/`,
  `languages/datalog/dotnet/`), each language's library beside it?
- Flix's way after: Datalog inside ML (rules as an ML value, a
  `[%datalog ...]` mlpp extension compiled by decision 5's compiler),
  and lattices (Flix's) for analyses that are not sets (constant
  propagation, intervals)?
- The analyses' scale: whole-program on ix's own programs means
  tens of thousands of facts; Datalog's compiled relations (decision
  5) indexed well enough, or BDDs (bddbddb's way) later?
- Its relation to plan_cmm.md (one IR under mini-cc and mini-ml, for
  the machines): two roads to a shared runtime, .NET's (this plan)
  and C--'s; this one first?
