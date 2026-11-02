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

**Status (2026-11-02):**
- **Step 0 done**: mini-analyze, native (below).
- **Stage 1 done**: mini-ml -dotnet, typed as F#: records, variants,
  exceptions, match, closures, generic functions and types, tuples,
  lists, arrays, several units in one assembly; C# using an ML unit.
- **Stage 2 done**: tail calls, mini-ml's tail. and mini-dotnet's.
- **Stage 3 done but corners**: lib_core compiled with the program
  (43 of its 50 units), its C primitives in ML over .NET
  (lib_core/dotnet/Runtime.ml), bytes a byte[], channels .NET's
  streams, formats typed closures; lib_core/dotnet/'s units in
  lib_core's place (Unix, Marshal) or over them (Printf, Format). Not:
  Marshal, Unix, Thread as .NET forms; %a on a channel.
- **Stage 4 paused** at the author's target (2x Microsoft's):
  speed.sh; mini-dotnet's JIT with int64s native on arm64 and a lazy
  start (fib within 1.5x of Microsoft's; the rest 7x to 33x). Not:
  doubles in the JIT, arm's int64s, F#'s IL compared, longer runs.
- **Stage 5 done**: mini-cc -dotnet, a managed C (languages/c/dotnet/):
  TinyC_tests' 11 programs verified and run by mini-dotnet (and its
  JIT) and Microsoft's dotnet as the host's cc prints them; 289 random
  programs (vlong too) as mini-cc's native build prints them; 8 kinds
  of programs refused, each with its reason. A pointer a pair (an
  array, an index), a struct a class (decision 4, as built). Refused
  by design: a union read as another field, a scalar member's
  address, variable arguments but print's (no va_list in .NET). Left,
  for when a program needs them: print's %f %g %e (a float formatter
  in libc.c), a global structure's initializer.
- **Stage 7 done** (before 6, which stands on it): mini-dotnet loads
  the assemblies a program references from beside it, a class found by
  its name in any; C# (Microsoft's csc) using an ML unit runs by it as
  by Microsoft's. Writer's AssemblyRef to an assembly of ours: version
  0, no key (Microsoft's dotnet refused the key's token).
- **Stage 6 done**: mini-datalog -dotnet, the rules compiled to IL
  (the interpreter's plans as nested loops, the strata's semi-naive
  rounds), over a runtime of mini-datalog's own relations compiled by
  mini-ml -dotnet (datalog_rt.dll, beside: stage 7). 15 programs (a
  graph, pointer.dl and liveness on mini-cc's facts, the 11 points_to
  analyses on mini-analyze's) answer as the interpreter, by both
  runtimes; with -ms, call1 on mini-ml's facts (0.55 s by Microsoft's
  dotnet, 23 s by mini-dotnet, after the reading's fix: an exception
  for each miss in lib_core's searches, notes_profiling_techniques.md).
  Not: -btree's sorted relations, typed CTS columns (decision 5's, for
  ML's values).
- **Stage 8 half**: mini-cc and mini-datalog (their ML) compiled to
  .NET, the facts pipeline's answers the native's by both runtimes;
  mini-analyze's two roads (the author's: native and .NET, for teaching
  and comparison) both run on C, one process each, the same answers
  (contexts.c, Plan 9's rc: 17,330). The .NET road near the native
  one (rc: 22.8 s of CPU against 18.9), after lifting local functions
  to methods in mini-ml -dotnet, a linear Lexing in lib_core, and
  array-keyed relations; ML programs on both roads too (contexts.ml,
  523 the same), mini-cc's units renamed beside mini-ml's; the reports
  (C's and ML's) the native's. Not: -dead and -caps' reports
  (mini-analyze's, another session's); a C module; mini-9pi's card.
- **Stage 9 not built**: ML analysed.

For the author: what step 0 showed, decision 6 to be decided again
by it, the open questions at the end.

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

   As built (stage 5, 2026-11-02), two changes. A pointer is a pair,
   Ptr<T> (an array, an index; null for 0), not an int32&: a managed
   reference can be neither kept in a field nor moved, and C keeps
   pointers in structures (a Node's next) and moves them (p++); .NET
   checks the bounds when the pointer is used, so arithmetic past an
   array is caught there (Cyclone's and CCured's fat pointers, 2002).
   A variable whose address is taken lives in an array of one element.
   And a struct is a class, not a .NET struct: its arrays and
   structures made by its constructor, C's assignment its Clone (a
   value type's arrays would be null until made, at each copy). The
   front end gives the back end its places typed (Check.managed: a
   member a Dot, an array's address its own type, no cast dropped),
   where 5c's typing leaves bytes and offsets; libc.c, in the managed
   C itself, is compiled with each program, print's formats compiled
   where they are (as mini-ml's Printf). Cil_types.mli has the table.

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
   Asked of the compiler first (2026-10-31, the author: "ok let's
   commit and move forward"): lib_core's Option compiles whole;
   List needs Pervasives; Pervasives stops at its externals, of which
   the %-primitives need no code (their uses are IL) and about forty
   are the native runtime's C (channels, format_int and
   format_float, the math functions, sys_exit). In steps:
   - 3a. **What lib_core's ML needs of the compiler**: a closure
     inside a polymorphic function, a polymorphic function partly
     applied or as a value. Done: a closure's class generic in the
     enclosing method's or class's type variables (its own !0...,
     made at the method's !!0...; Il_types.helper_class); a local
     polymorphic function (let's polymorphism: its type generalized
     apart from the enclosing function's) compiled at the one type
     its uses in the let's body give, used at several refused; a
     partial application's classes generic in the function's
     variables, made at what the use gives; a one-argument library
     function as a value (List.map string_of_int) a class whose
     Invoke is its call. Checked: generic_closures (map and filter
     with local recursions and closures, a lambda capturing an 'a,
     a closure made in a closure, map and twice partly applied at
     ints and strings) by both runtimes.
   - 3b. **Pervasives' externals over .NET**: the C externals
     written as ML of a runtime unit for .NET, which reaches .NET's
     members by decision 7's externals; an external of Pervasives
     then a call of that unit's function of its name. The author
     chose it: "We do want to run what is produced by mini-ml
     -dotnet with the microsoft's dotnet and runtime" (hand-written
     IL, or mini-dotnet's Library alone, were the others). In steps:
     - done: externals naming .NET members,
       `external sub : string -> int -> int -> string =
       "dotnet:instance System.String::Substring(int32,int32)"`,
       static or instance, the parameters' and the result's .NET
       types when they are not the ML ones' (an int32 converted
       to and from ML's int64, a char); the MemberRef made from the
       ML type (Il_externals). Checked: externals.ml (String's and
       Console's members) by both runtimes, by both mini-ml builds.
     - done: the runtime unit, lib_core/dotnet/Runtime.ml (the
       author: "good choice for lib_core/dotnet/"), compiled first by
       -dotnet -L lib_core; a call of an external of C a call of its
       function of the primitive's name. The math by System.Math;
       frexp, ldexp, modf by ILogB and ScaleB, fmod by
       IEEERemainder; int_of_string,
       format_int and strtod's syntax in ML; a decimal read by
       Double.Parse, a float's digits by its E and F formats, C's %e
       %f %g made from them. The compiler: a value type's this by
       its address (Double's ToString(format)), %identity converting
       a char and an int, a unit of a name already
       given refused; the assemblies' runtimeconfig.json the
       invariant culture. mini-dotnet's Library: System.Math, Double's
       Parse and ToString(format). An int is .NET's int64, so %x of
       -1 is 16 digits (the native's 63 bits: 15). Checked:
       c_externals.ml (the math, frexp, modf, the numbers read and
       written, 107 lines, C's printf and strtod by Python's) by
       both runtimes, by both mini-ml builds. make loc sets apart
       any dotnet/ directory (the author's).
     - done: bytes, the channels, sys_open, sys_exit (the author,
       asked: "byte[] + Streams"). bytes a byte[] (the %string_*
       primitives on it ldelem and stelem, a %identity to and from a
       string a copy by the runtime's Latin-1); the native's channels
       (a buffer of 4096 bytes) over a .NET Stream, the console's
       (OpenStandardOutput...: its bytes as they are) or a file's
       (File's OpenRead, OpenWrite, Create: no enum to name), the
       descriptors a table of them; an abstract type an object, the
       runtime casting it to its channel. The compiler: externals
       naming classes (System.IO.Stream) and arrays (uint8[]), an
       object cast to them; a runtime function's arguments converted
       to its parameters (output_byte's int where output_char's char);
       sys_exit's 'a a default value. mini-dotnet's Library: Stream,
       FileStream, File, Console's standard streams, Encoding's
       GetString and GetBytes, IOException; its CLI the streams by
       capabilities (Cap.open_out now), over the console's channels so
       that Console.Write's and theirs keep their order. Found: the
       native's flush of an input channel writes what is left to read
       (a write that fails silently on a file opened to read); here
       only a channel written to is flushed. Checked: channels.ml (the
       console, a file written, read, sought, appended, sys_open's
       errors, a line of 5000 bytes from the standard input) by both
       runtimes and both mini-ml builds; the programs run in the
       scratch directory.
   - 3c. lib_core's units given with the program's (-L lib_core, in
     units.txt's order), List, Option, String, Hashtbl, Printf first.
     Begun (2026-10-31, the author: "excellent! let's commit and move
     forward"): mini-ml -dotnet -L compiles the units the program
     names, and those they name (by their tokens, CLI.named_units), in
     units.txt's order, after the runtime unit; Pervasives always,
     its do_at_exit in <Program>.Main's finally (the channels flushed,
     an exception's end too). 33 of lib_core's 50 compile, each with
     what it names: Pervasives, Int32, Int64, Seq, List, Char,
     Uchar, String, Bytes, Array, Sys, Hashtbl, Filename, Obj,
     Stack, Queue, Buffer, Printf, Format, Arg, Option, Result,
     Either, Int, Bool, Fun, In_channel, Out_channel, Fpath, Cap,
     CapSys, CapStdlib, Atomic. What it took of the compiler:
     - compare and < on records, variants, tuples and lists, OCaml's
       order: each class a CompareTo (IComparable, F#'s way), the
       constructors by OCaml's representation (constants first,
       ml_order), the fields by Ml::compare; Hashtbl.hash Ml::hash, the
       same on both runtimes (Microsoft's String.GetHashCode varies by
       process), records' GetHashCode by it.
     - Printf's functions with a literal format compiled (Il_printf):
       lib_core's Printf builds its closures with Obj.magic, which .NET's
       delegates, typed, refuse; %a and %t refused.
     - a let rec of several local functions (closures holding each
       other); assert; a primitive as a value (η-expanded, a method);
       another unit's external its .mli says val of; a function's alias
       (let sort = stable_sort) the same method, polymorphic as it; a
       polymorphic function at unit (object, F#'s); a toplevel let of
       a pattern; an abstract type of a .mli its .ml's definition when
       compiled in the assembly (Uchar.utf_decode an int); a re-exported
       type's constructors the first's classes (Option's t); int32 and
       int64 .NET's, their constants; a parametrized abbreviation.
     - the runtime unit: Int32's and Int64's primitives (on int, the
       call converting), make_vect (newarr), is_printable, fill_string,
       Sys's (argv, getenv, files and directories, time), the
       byte-access primitives, hash_univ_param; mini-dotnet's Library:
       Environment, Directory, File's Delete and Move, BitConverter,
       IComparable; its CLI's system by capabilities (Cap.env,
       Cap.readdir, Cap.chdir).
     Then (the author: "let's commit and move forward"): 41 of 50,
     with Gc (no counters, collections nothing), Digest (.NET's
     MD5.HashData, in System.Security.Cryptography's assembly, which
     the externals now know), Random, Callback (register_named_value
     nothing: no C runtime asks), Printexc (the predefined exceptions
     with their arguments, the others their class's name; no
     backtrace), Lexing and Parsing (fst and snd on tuples), Float's
     float arrays (float64[]), Unix's Float. assert throws
     Pervasives' Assert_failure, which a handler names.
     Then formats as values (the author, asked: "Compiled closure";
     and of Logs: "we don't have to support all of Logs", ix's being a
     poor man's, the real one's functors beyond mini-ml): 43 of 50. A
     format is F#'s way, a function of k : string -> 'd, the curried
     function of its arguments giving k their text, a literal's
     compiled (Il_exprs.format_value, synthetic expressions: fun k ->
     fun x1 ... -> k (sprintf "..." x1 ...)); Format's @ directives
     text (@. a newline, the boxes nothing: no line breaking). Printf's
     and Format's printf functions over it in overlays,
     lib_core/dotnet/Printf_dotnet.ml and Format_dotnet.ml, compiled
     right after their unit, their functions in its place
     (Lower_il.overlay): lib_core's, which read a string and make
     closures by Obj.magic, stay, cast (castclass, verifiable), unused.
     Function types through abbreviations ('a msgf). Checked:
     tests/formats.ml (a format given to a function, ksprintf, printf
     as a value, Format's directives, ix's Logs).
     Not yet: Marshal (OCaml's blocks), Unix (system calls by number)
     and Thread (the C runtime's green threads), which .NET has other
     forms of; %a and %t; an external over-applied. lib_core's
     Char.escaped wrote a string (the only place): made as bytes now,
     as String's. Checked: tests/library.ml (List, String, Bytes,
     Buffer, Printf's formats, Hashtbl, Array, Char, Option, compare's
     order, a local let rec ... and) as OCaml prints, by both runtimes
     and both mini-ml builds; the suite's other programs now with
     Pervasives compiled.
4. **Speed**: mini-ml's benchmarks native, on .NET (Microsoft's), on
   mini-dotnet (its JIT), and the same programs in F# (fsc): their IL
   compared, -S beside ildasm's, and their time.
   Begun (2026-11-01, the author: "let's commit and move forward"):
   languages/ml/dotnet/tests/speed.sh, the 11 of languages/ml/tests/
   bench/ (all compile with -dotnet, all print their .out on both
   runtimes), the best of three, seconds, on the arm64 host:

       program  native  dotnet  mini-dotnet -jit
       hello     0.004   0.065   0.034
       pixels    0.011   0.092   6.688
       limbs     0.006   0.077   3.603
       samples   0.007   0.089   1.589
       floats    0.007   0.077   1.848
       sha       0.007   0.096   3.825
       fib       0.006   0.101   0.733
       tak       0.005   0.089   0.583
       maps      0.014   0.089   3.212
       sched     0.009   0.131   3.930
       interp    0.009   0.163   8.295
       matrix    0.009   0.082   5.435

   The benchmarks are sized for mini-5i's counts: natively and on
   Microsoft's dotnet their time is mostly the start (hello's), so
   that comparison needs bigger runs. mini-dotnet's is its
   interpreter's: its JIT takes only methods all of int32 (its C#
   programs'), and an ML int is an int64 (fib's 4 methods compiled of
   its assembly's, not fib; "a parameter not an int32" 160 times,
   "this is a reference" 113). Found and fixed on the way (in
   docs/plans/bugs/ix.md): mini-ld's arm64 encoder refused a small
   unaligned offset (the JIT died on sha), mini-dotnet's 10,000 frames
   (maps' List.map; now 30,000).
   Then (the author, asked: "JIT int64, arm64 first"; and: "long term
   the arm64 part of mini-dotnet is more important than the arm [...]
   Still we also want to make it work on the Pi1 and Pi2"): an int64
   the JIT's own on arm64 (Jit's kind L: a word in a register, X
   instructions; crossing to ML as two tagged halves, or its block),
   so that ML's code is compiled: fib's interpreted instructions
   676,669 before, 1,529 after; the suite's 20 programs by the JIT
   (run.sh's third pass), C#'s and Tiger's too. The times:

       program  native  dotnet  mini-dotnet -jit (before)
       fib       0.006   0.115   0.502  (0.733)
       pixels    0.013   0.086   2.267  (6.688)
       matrix    0.012   0.086   2.350  (5.435)
       interp    0.009   0.156   7.073  (8.295)

   What is left of mini-dotnet's: about 450 ms of the JIT's own start,
   at a first call (fib with nothing compiled, -tier 1000000: 639 ms;
   interpreted 194 ms), the assembly's stubs and entries, all its
   methods', assembled and encoded by mini-asm's and mini-ld's passes
   (their text alone 130 ms, verifying 32); and doubles, and int64s
   on arm, still call-outs. Next: those stubs made at a first call,
   and bigger runs for the times beyond the start.
   Then the JIT's start (the author: "let's do 1 and maybe stop there
   for the optimization. Remember that 2x slower than microsoft dotnet
   is fine"): measured, 331 ms of its 437 were Types.meth_of_def of
   every method taken, for its entry's function; that function made
   now when the method is hot (Machine's tiers, Jit_run.jit), and a
   method's IL decoded when it is compiled. fib by the JIT 493 ms to
   153 (Microsoft's dotnet 116), with nothing compiled 312 (verifying
   the methods, 32 ms, and encoding their stubs and entries, about 60,
   are what is left of the start). The times:

       program  native  dotnet  mini-dotnet -jit
       hello     0.005   0.062   0.032
       pixels    0.010   0.096   1.299
       limbs     0.009   0.082   0.981
       samples   0.007   0.086   0.562
       floats    0.006   0.081   0.742
       sha       0.007   0.093   1.427
       fib       0.005   0.116   0.156
       tak       0.006   0.091   0.167
       maps      0.011   0.095   1.651
       sched     0.012   0.109   2.783
       interp    0.010   0.154   5.162
       matrix    0.011   0.076   1.538

   fib and tak within 1.5 of Microsoft's, its start included; the
   others 7 to 33: the code the JIT leaves to the interpreter
   (doubles, closures' Invoke, allocation) and each method's compiling
   (mini-asm's and mini-ld's passes). Stopped there for now, the
   author's target being 2x.
5. **mini-cc to IL, a managed C** (decision 4). Check: mini-cc's
   tests that stay in it, by both runtimes, what the native build
   prints; those refused, counted with their reason.

   Done (2026-11-02): `mini-cc -dotnet -L languages/c/dotnet x.c`,
   x.dll. languages/c/dotnet/tests/run.sh: tiny/tests/TinyC_tests'
   11 programs (integers of each width, calls, control, enums,
   function pointers, globals, pointers into arrays, a sort, structs,
   unsigned division), every method verified by mini-dotnet, run by
   dune's and ix's mini-dotnet, ix's JIT and Microsoft's dotnet, as
   their .out (make test: dune's, and ix's mini-cc after ix); 8
   programs refused, each with its message (a union, a pointer cast,
   an int made a pointer and back, a member's address, a format of a
   variable, variable arguments, malloc's memory given no type).
   -fuzz 300 (make test-vs-goken): TinyC_fuzz.py's programs against
   mini-cc's native arm64 build with goken's libc, 289 the same, 11
   not built natively (goken's 7c, bugs/goken.md 5e); the host's cc
   is no reference there, its ANSI promotions not Plan 9's. It found
   mini-dotnet's int64 div.un and rem.un signed (bugs/ix.md, fixed).
   ix's mini-cc writes the same bytes as dune's. Sizes: the back end
   1,598 lines (Cil_types, Cil_strings, Cil_exprs, Lower_cil), libc.c
   154, the front end's flag 12.
6. **mini-datalog compiled** (decision 5). Check: its analyses
   (lib_code/datalog/) on mini-cc's and mini-ml's facts, the same answers as
   the interpreter's.

   Done (2026-11-02), after stage 7, Souffle's split: `mini-datalog
   -dotnet -o p.dll -q 'call_edge(I, F)' pointer.dl`, then `dotnet
   p.dll facts...`. The compiler (languages/datalog/dotnet/Compile_il)
   decides what the interpreter decides as it runs, once: the strata,
   each rule's plans (Datalog_eval.plan, the same code), and writes
   their joins as loops in IL (a range of a relation's tuples, or the
   numbers an index gives; each test a branch; the head added
   innermost). The relations are not compiled: mini-datalog's own
   (Datalog, Relset, Index), compiled by mini-ml -dotnet into
   datalog_rt.dll with Datalog_rt (the calls the loops make, the
   program's entry under Cap.main, the queries answered as the
   interpreter does). The author chose IL over C (mini-cc -dotnet,
   Souffle's own road through C++); the runtime is ML, not C# as first
   proposed: mini-csc's C# 1 has no bit operations nor generics of its
   own. Check: languages/datalog/dotnet/tests/run.sh (make test, 8 s,
   the cases run at once): 15 programs, every method verified, their
   answers the interpreter's by mini-dotnet; Microsoft's dotnet too with
   -ms, and call1 on contexts.ml's facts (mini-ml's and lib_core's,
   6,093: 473 answers; 38 s by mini-dotnet, 5.5 s by Microsoft's, of
   which 4.8 s the facts read). ix's mini-datalog writes the same bytes
   as dune's. Sizes: Compile_il 375 lines, Datalog_rt 112.
7. **Several assemblies in mini-dotnet** (decision 1): AssemblyRef
   resolved to an assembly beside the program's.

   Done (2026-11-02): CLI.run loads each AssemblyRef not System's,
   name.dll beside the program, its own references first; Types'
   find_class already looked in every image loaded. Check: ML's
   tests/run.sh -ms, interop.cs (Microsoft's csc) over shapes.ml's
   assembly, run by mini-dotnet as by Microsoft's dotnet.
8. **The program in several languages** (decision 7), by two roads
   kept working both (the author: "ideally the mini-analyzer can have 2
   paths: one compiled natively, with extra comm/conversion because the
   different parts are in different languages, but maybe it's run
   faster. and the other path is all compiled with -dotnet so
   potentially less total code but maybe less inefficient in the end.
   It's good to have the 2 code paths working for a teaching and
   comparison purpose"): native, each part its own program and the
   facts as text between them (today's pipeline), and .NET, one
   process whose parts share the CTS's values; their answers compared,
   their times and sizes said side by side.
   Both run (2026-11-02, C only): analyzers/dotnet/tests/run.sh. The
   .NET road: Analyze_rt, the entry of a program whose rules
   mini-datalog -dotnet compiled (-runtime analyze_rt -entry
   Analyze_rt), mini-cc's front end, Facts, C_front, mini-datalog's
   relations and Datalog_rt compiled by mini-ml -dotnet into
   analyze_rt.dll (1 MB), the facts given as values (Facts.added). On
   contexts.c, call1_heap1's 110 answers the same (native 33 ms; .NET
   0.5 s by Microsoft's dotnet, 12 s by mini-dotnet); on Plan 9's rc
   (30 files, 15,026 facts), 17,330 the same: native 16 s (the front
   end 0.3, the evaluator 16), .NET 31 s by Microsoft's (the front end
   3). The compiled rules lose to the native interpreter for now: what
   mini-dotnet's -profile shows under them is mini-ml -dotnet's code
   for the relations (Tuples's hash and its closures, one an object
   and a virtual call at each lookup; Array.make filled in ML) and,
   for the front end, lib_core's Lexing.from_function, which copies a
   token's bytes again at each one-character refill. Then (the
   author: "ok let's do it"): mini-ml -dotnet lifts a local function
   it never needs as a value to a static method (F#'s way), its
   captured variables its first parameters: rc 30.7 s of CPU to 25.5;
   lib_core's Lexing grows its buffer instead of copying at each
   refill, and knows once per lexer which states have a way out
   (engine asked 257 entries at each buffer's end: mini-cc's every
   character): ix's own mini-cc writes rc's facts in 0.50 s, was 1.03,
   the same facts; on .NET the front end 2.7 s (0.08 s a file, its
   headers; startup 0.3). Then (the author: "I've paused the other
   session so let's go"): Tuples, Hash_index, Index and Relset given
   array-keyed hash, find, mem, first, add (no closure called for each
   value, Tuples.mem2's way for any arity), Datalog.add indexing by
   them: rc's .NET road 22.8 s of CPU (was 30.7 this morning), the
   native evaluator 18.6 (was 19.3: faster too). The compiled rules
   now near the native interpreter, 1.2x with the front end. ML too
   (the author: "let's move forward on stage 8"): analyze_rt.dll holds
   both front ends, mini-ml's (Ast to Typing, mlpp's Pp, Closure_facts,
   Ml_front) and mini-cc's, the latter's units copied with Parser and
   Lexer renamed C_parser and C_lexer (dune's wrapped copy in
   analyzers/c, by hand: mini-ml has one namespace of units). What it
   took of mini-ml -dotnet: a tuple pattern and fst/snd through a type
   abbreviation (Ast's span), a try inside an operand made a method of
   its own (IL's try starts with an empty stack: F#'s way, as lift's).
   contexts.ml with the lib_core units it names, call1's pts and
   reach: 523 answers the same (native 0.1 s, Microsoft's dotnet 1 s).
   And the report (the author: "let's do it"): mini-analyze's C and ML
   reports out of Analyze into units both roads use (analyzers/c's
   C_report, with the facts' given; analyzers' Ml_report, in a library
   with Ml_front), Analyze_rt printing them when it is given no query:
   bugs.c, callbacks.c and handlers (ML) reported as the native
   mini-analyze reports them. What it took: = of arrays in mini-ml
   -dotnet by their elements, not their places (bugs/ix.md). Not
   yet: ML programs (mini-ml's and mini-cc's Lexer and Parser in
   mini-ml's one namespace), the report (Analyze's, in the native
   mini-analyze, which another session is changing).
   Then: Andersen's
   points-to on whole C programs, mini-cc's front end (ML) parsing and
   writing facts into a Datalog module (lib_code/datalog/'s rules, compiled),
   the answers read back by ML and printed; a C module where C is the
   better tool (a fast hash of the facts, say). Check: the same
   answers as today's pipeline (`mini-cc -facts`, `mini-datalog`), by
   both runtimes, and on mini-9pi's card. First on a C program as
   the analysis's tests have it, then on one of ix's own (mini-rc's).
   Begun (2026-11-01, the author: "let's commit and move forward with
   the analysis direction"): mini-cc whole compiled to .NET by mini-ml
   -dotnet (its mkfile's units, the assembler's two, lib_code's, the
   parser and lexer mini-yacc's and mini-lex's: 1.4 MB, 8,492
   methods, all verified, compiled in 2.5 s), its -facts and -flow of
   languages/c/facts/tests/' programs what the native mini-cc writes,
   by Microsoft's dotnet (474 ms, native 14), mini-dotnet's interpreter
   (18 s) and its JIT (33 s: compiling hot methods through mini-asm and
   mini-ld costs more than it saves on an assembly of this size).
   tests/run.sh checks it (front_end). What it took:
   - lib_core's units of .NET's own in lib_core/dotnet/, in place of
     lib_core's (Unix: its system calls fail by name, those of Sys's
     done; Marshal: its functions fail by name), so that commons/ (FS,
     Console, Logging...) compile as they are; commons/'s units after
     the stdlib's, in the order of what they name.
   - %a and %t (Format's: the printer's text on a buffer's formatter;
     sprintf's, bprintf's), %h, %S, %C; a literal format given fewer
     arguments a value; Format's output flushed at a newline (@.).
   - a local function used at several types specialized: a closure for
     each, captured by the closures that use it (Check's one); compare
     as a value in a polymorphic function (a generic method); a
     primitive given fewer arguments (String.get s); |> and @@; int64
     and float constants as patterns; a polymorphic toplevel value
     (Set_'s empty) a generic method, a fresh value at each use's type
     (one field was one instance, Set_.add then failed its match); a
     unit matched (the parser's match with exception clauses); the
     classes keyed by the unit's qualified path (Ir's mem = Asm.mem in
     Opti; two units' t no more one class), records through their
     abbreviations; a function that always raises given as a value.
   - mini-dotnet: a program's arguments after its .dll its own
     (mini-cc.dll -m 7 -facts), Math.Abs.
   Then (the author: "let's commmit and move forward") the pipeline
   whole on .NET: mini-datalog compiled too (its mkfile's units: 3,043
   methods, all verified), and languages/c/facts/tests/run.sh given
   both assemblies (CC, DATALOG): mini-cc's facts, mini-datalog's
   pointer analysis and liveness on them, every answer the native
   pipeline's, by Microsoft's dotnet (18 s) and mini-dotnet's
   interpreter (81 s); mini-datalog's own suite (graph, liveness,
   dominators, refused, pointer) by Microsoft's too. tests/run.sh's
   pipeline checks it with -ms. What it took: a variant's case
   through its type's abbreviation (Relset's hint, a Btree.hint
   option: Some`1<> made), a record's labels and a tuple's too.
   mini-analyze itself is not compiled: dune's wrapped libraries put
   mini-cc's and mini-ml's units (each a Lexer, a Parser) in one
   program, and mini-ml has one namespace of units (natively too).
   Next: the pipeline on one of ix's own programs (mini-rc's), then
   mini-ml's front end and its facts (stage 9).
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
| mini-cc's managed back end (built: 1,598, and libc.c 154) | 1,000 |
| mini-datalog's compiler (built: 375, and its runtime's calls 112) | 600 |
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
