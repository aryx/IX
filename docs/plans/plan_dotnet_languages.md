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
analysis (analyses/: Andersen's pointer analysis, liveness, the
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

**Status: step 0 done (mini-analyze, native: below), the rest not
built.** For the author: what step 0 showed, decision 6 to be
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
  (decision 5) or better indexes before whole programs of ix.
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
2. **Tail calls in mini-dotnet** (decision 3). Check: a loop of
   10,000,000 turns written as a tail recursion, by both runtimes.
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
   (analyses/) on mini-cc's and mini-ml's facts, the same answers as
   the interpreter's.
7. **Several assemblies in mini-dotnet** (decision 1): AssemblyRef
   resolved to an assembly beside the program's.
8. **The program in several languages** (decision 7): Andersen's
   points-to on whole C programs, mini-cc's front end (ML) parsing and
   writing facts into a Datalog module (analyses/'s rules, compiled),
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
  for String, Console, Dictionary already? And, after step 0: lib_core
  compiled to IL (the front ends as they are), agreed?
- Step 0's next: Datalog's speed first (rc's 7 s; better indexes in
  mini-datalog, or decision 5's compiler sooner), or precision first
  (contexts, Doop's way), or straight to stage 1 (mini-ml -dotnet)?
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
