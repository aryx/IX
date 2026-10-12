# Plan: .NET in ix: mini-dotnet, a runtime for the assemblies Microsoft's compiler writes, TinyDotnet.ml, and then mini-csc (`languages/dotnet/`, `tiny/TinyDotnet.ml`)

The author (2026-10-12): "how much would would be a mini-dotnet?
Mostly for its teaching aspect, so people can learn what is the
essence of dotnet"; then: "let's make a plan document for it
(including the TinyDotnet.ml too)".

The short answer: **about 4,250 lines of .ml for the runtime, about
900 for TinyDotnet.ml, about 4,400 more for a C# compiler of its
own**, in that order. The runtime (mini-dotnet) reads the `.dll` that
Microsoft's `csc` writes and runs it, in OCaml, the heap OCaml's: what
it prints is checked against what Microsoft's `dotnet` prints for the
same file. The lines are estimates, from the neighbours' sizes
(mini-smalltalk 5,568 lines of .ml, mini-pascal 1,952, TinyML 1,659);
what the estimates stand on is counted: ten programs written for
this, compiled, and their assemblies read (the survey, below).

What decides the plan's shape is one number of that survey:
**Microsoft's library cannot be run**. `System.Private.CoreLib.dll`
is 2,466 types, 33,768 methods and 1.3 MB of IL, and the ten programs
ask 47 members of it. So the library is ix's own: those members first
as OCaml functions, later as C# compiled by mini-csc.

**Status: plan written, nothing built** but the survey
(`languages/dotnet/survey/`).

## What .NET is, for a reader

The essence, as six lessons; each is a file or two of the runtime,
and what the programs of the survey were written to show.

1. **A program's file describes itself.** An assembly is a PE file
   (Windows's executable format, kept on every system) whose content
   is a small relational database: 45 tables (types, fields, methods,
   parameters, references to other assemblies' members), rows that
   name each other by number, four heaps (names, strings, blobs,
   GUIDs). No header files, no link step: a reference is a row
   `System.Console::WriteLine` with its signature, resolved by name
   when the method is first run. `hello.dll` is 4,096 bytes for 18
   bytes of code.
2. **One machine for several languages**, where the JVM was Java's:
   the Common Type System has what C#, Visual Basic, F# and C++ ask
   together (unsigned integers, structs, pointers, tail calls), and
   the rules (the CLS) of what one language may show another.
3. **The instructions are typed by what is on the stack**: `add`, not
   the JVM's `iadd` and `dadd`. So the runtime must know each stack
   slot's type before it runs a method: by a pass of its own (the
   verifier, the JIT) or, in an interpreter, by a tag on each value.
4. **Value types.** A struct is not a pointer: it is copied by
   assignment, lies inline in an array or in another object, and
   becomes an object only when boxed. With them come the managed
   pointers (`ref`, the instructions `ldloca`, `ldflda`, `ldelema`):
   a pointer into a local, a field or an array's element, that the
   collector must know.
5. **Generics are kept at run time**, where Java erases them:
   `Stack<int>` and `Stack<string>` are two types, `typeof(T)` has an
   answer, `o is Stack<string>` is false for a `Stack<int>`, and an
   array of `T` for `int` holds ints, not boxes.
6. **It was always compiled, never interpreted**: a method's IL is
   compiled to the machine's code the first time it is called. This
   plan's runtime is an interpreter; the JIT is "After it".

Not the essence, and not in this plan: threads, `async`, reflection
beyond a type's name, application domains, P/Invoke, unsafe code,
LINQ, cultures, the formats of numbers beyond the invariant ones.

## The survey (`languages/dotnet/survey/`, run 2026-10-12)

`survey.sh` compiles `programs/*.cs` by the C# compiler of the .NET
SDK here (8.0.131, arm64, nothing downloaded), checks what each
prints by Microsoft's runtime against `programs/*.expected`, and
reads the assemblies by `Survey.cs` (a C# program:
System.Reflection.Metadata). Its output is `survey.txt`.

| program | what it is for | C# | bytes | IL | tables | rows | opcodes | the library's |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `hello` | one call into the library | 5 | 4,096 | 18 | 8 | 25 | 4 | 6 |
| `fib` | static methods, int32 (and its wrap) | 21 | 4,096 | 92 | 10 | 30 | 18 | 6 |
| `queens` | arrays, statics, a recursion: 92 solutions | 30 | 4,608 | 288 | 11 | 41 | 32 | 9 |
| `shapes` | classes, a virtual method, an interface | 39 | 4,608 | 268 | 15 | 68 | 39 | 8 |
| `exceptions` | throw, catch by type, finally, the machine's own | 45 | 4,608 | 229 | 11 | 50 | 33 | 11 |
| `strings` | the string class, an interpolation, a switch | 29 | 4,608 | 309 | 11 | 53 | 28 | 21 |
| `vec` | a struct copied, by `ref`, boxed, in an array | 33 | 4,608 | 349 | 11 | 48 | 42 | 8 |
| `generic` | a generic class and method, `typeof(T)` | 43 | 5,120 | 496 | 17 | 101 | 47 | 10 |
| `collections` | `List`, `Dictionary`, `foreach` | 27 | 4,608 | 317 | 10 | 49 | 37 | 20 |
| `closures` | delegates, a lambda and its captured local | 23 | 5,120 | 309 | 13 | 94 | 26 | 13 |

"The library's" counts the members a program names, the four
attributes every assembly carries among them. Together:

- **19 of the 45 tables** have a row. The reader still needs the
  shape of all 45: a table's place in the file is known only from the
  sizes of those before it.
- **86 of the 226 opcodes**, 53 families when `ldarg.0`, `ldarg.1`
  and `ldarg.s` are one (1,068 instructions; `call`, `ldc`, `ldloc`
  and `ldarg` are 45% of them).
- **47 members of 32 types** of the library: `Console` (2), `String`
  (7), `Object` (2), `Int32` (2), `Exception` (2), `StringBuilder`
  (2), `List` (5) and its `Enumerator` (2), `Dictionary` (5), the
  delegates `Func` and `Action` (6), `IDisposable` (1), `Type` and
  `MemberInfo` (2), the interpolation's handler (4), five attributes.
- **Microsoft's**: `System.Private.CoreLib.dll` 13 MB, 2,466 types,
  33,768 methods, 1,332,098 bytes of IL; `System.Console.dll` 463
  methods more; `System.Runtime.dll`, the one a program names, has no
  method at all: it forwards each type to the other.

What the compiler made that the source does not say, each a thing the
runtime must have though no program asked for it by name:

- `foreach` over a `List<int>` is a struct (`List<T>.Enumerator`, a
  generic value type nested in a generic class), a `constrained.`
  call and a `finally` that disposes it: `collections` has one
  exception clause and no `try` in its text.
- A lambda is a class the compiler writes (`closures`: 6 types for
  the source's 2), the captured local a field of it. The runtime has
  only delegates to give: `ldftn` and a constructor **with no IL**,
  as `Invoke` has none (the rows say "runtime").
- `$"n is {n}"` is four calls on a struct of the library
  (`DefaultInterpolatedStringHandler`), one of them generic.
- `typeof(T).Name` is `ldtoken`, `Type::GetTypeFromHandle` and
  `MemberInfo::get_Name`: the slice of reflection lesson 5 needs.
- 44 rows of attributes, none of which changes what a program does.

## What to write

The runtime, `languages/dotnet/` (estimates, .ml):

| part | lines | what it is |
|---|---:|---|
| the reader | 700 | the PE's sections, the metadata's heaps, the 45 tables from their shapes as data, the signatures (blobs), a method's body (its two headers, the exception clauses) |
| the instructions | 250 | the 226 opcodes as a table (name, operand), a body decoded; the listing (`-S`), as `ildasm`'s |
| the types | 900 | a class loaded when first used: its fields' places, its table of virtual methods, its interfaces; references resolved by name; a generic type or method instantiated (lesson 5); static constructors |
| the machine | 1,100 | frames, the evaluation stack of tagged values, the instructions; structs and managed pointers (lesson 4); delegates; the exceptions' two passes (the handler found, then the `finally` on the way) |
| the library | 600 | the survey's 47 members, in OCaml, by the name a `MemberRef` gives |
| the verifier | 600 | optional, a stage of its own: each method's stack types, by lesson 3's pass |
| `CLI`, `Main` | 100 | `mini-dotnet file.dll`; `-tables`, `-S`, `-trace` |
| all | 4,250 | 3,650 without the verifier |

`tiny/TinyDotnet.ml`, about 900 lines, one file: lessons 1 and 3 and
a class. The reader (all 45 tables' shapes: there is no less), a
listing of the tables and of the IL, and a machine for four of the
programs: `hello`, `fib`, `queens`, `shapes`. They ask **53 opcodes
(32 families), 15 tables and 5 members of the library**
(`Console::Write` and `WriteLine`, `Int32::ToString`,
`String::Concat`, `Object::.ctor`). No struct, no generic, no
exception, no delegate: each is a line that says what it does not do
and which program of the survey shows it.

mini-csc, C# to an assembly (estimates): the lexer 200 (ocamllex),
the grammar 700 (ocamlyacc), the tree 200, the names and the types
1,500 (overloads, the conversions, boxing where a value becomes an
object, a generic method's arguments inferred: `Swap(ref x, ref y)`),
the lowering 500 (a lambda's class, `foreach`, the interpolation),
the IL 600, the tables and the PE written 700: **4,400**.

For the scale, from memory and not measured: Microsoft's Shared
Source CLI ("Rotor", 2002, the book *Shared Source CLI Essentials*)
was millions of lines; Chris Bacon's DotNetAnywhere, an interpreter
in C with a library of its own (the first Blazor ran on it), some
tens of thousands. The standard is ECMA-335; its Partition II is the
reader, Partition III the machine.

## Decisions (proposed, for the author)

1. **The runtime first, the compiler after.** Reading Microsoft's
   assemblies gives a reference for every stage: the same file, two
   runtimes, what is printed compared. A compiler first would be
   checked by nothing until its runtime exists.
2. **The assemblies are in the tree, as test data**: the ten `.dll`
   (46 KB) beside their `.cs` and `.expected`, written again by
   `survey.sh` where there is an SDK. Microsoft's compiler is not in
   m-ix, and the tests must run there. When mini-csc exists it makes
   them, and the committed ones are the comparison.
3. **The library is ix's, in OCaml first.** A member of `System.*`
   is looked for by its name in a table of OCaml functions; a
   reference's assembly (`System.Runtime`, `System.Console`) is not
   read. `List` and `Dictionary` are OCaml's until mini-csc compiles
   a `corelib.cs`, which is how the real one is made: C# on a few
   functions of the runtime. (Not taken: a `corelib.dll` made by
   Microsoft's compiler and committed, the library's code a binary of
   the tree.)
4. **An interpreter, the heap OCaml's**: an object is an OCaml record
   (its class, its fields), collected by OCaml's collector; a managed
   pointer is a container and an index (a frame's local, an object's
   field, an array's element), not an address. What a real CLR does
   there (the collector told of pointers inside objects) is said in
   the header, not written.
5. **A value carries its type**, the simple path of lesson 3: `I4`,
   `I8`, `R8`, a reference, a struct, a pointer. The verifier's pass
   would let the machine drop the tags: an optimization, after, and
   switchable.
6. **int32 exactly.** `fib` prints -1323752223 for the 47th number. A
   Pi 1's OCaml int is 31 bits: an `I4` is an `Int32.t` there
   (lib_core has it; mini-ml's code for it to check). Simple first,
   measured, then an int masked where ints are 63 bits.
7. **Strings**: .NET's are UTF-16 and immutable. Proposed: OCaml's
   strings and Latin-1 at first (`Length` and `[i]` exact for the
   tests' text), said in the header; UTF-16 a later change of one
   module.
8. **mini-csc's contract is the program's output, not the bytes.**
   Roslyn's assembly, row for row, is not a target one can hold (its
   order of rows, its attributes, its names for a lambda's class).
   Checked both ways instead: mini-dotnet runs what `csc` wrote,
   Microsoft's `dotnet` runs what mini-csc wrote.
9. **The names**: `mini-dotnet` (Microsoft's command: `dotnet
   file.dll`), `mini-csc`; on mini-9pi's card `dotnet` and `csc`. The
   directory `languages/dotnet/`, mini-csc in `languages/dotnet/csc/`
   (a program of this machine alone); `languages/README.md`'s second
   table, the languages that are run.

## The stages (each checked before the next)

1. **TinyDotnet.ml.** Check: `hello`, `fib`, `queens` and `shapes`
   print their `.expected`; its count of rows by table is
   `survey.txt`'s for each of the ten (it reads all of them, runs
   four); by dune and by mini-ml.
2. **The reader and the listing** (`-tables`, `-S`). Check: the ten;
   and **Microsoft's own library read whole**: 2,466 types, 33,768
   methods, 1,332,098 bytes of IL decoded to the last byte of each
   body, `Survey.cs`'s numbers.
3. **Objects**: classes, virtual calls, interfaces, strings, arrays,
   statics, exceptions. Check: `hello`, `fib`, `queens`, `shapes`,
   `exceptions`, `strings`.
4. **Value types and generics**: structs, boxing, managed pointers,
   instantiation, delegates. Check: `vec`, `generic`, `collections`,
   `closures`; the ten the same by mini-ml's build, on arm64 and on
   arm under mini-5i (decision 6).
5. **On mini-9pi's console**: `dotnet` on the card, the assemblies in
   `/lib/dotnet/`. Check: a recorded session, as `check-pascal`; the
   queens' time, here.
6. **The verifier** (optional). Check: the ten pass; assemblies
   broken by hand (an `add` of an int and a reference, a stack left
   deeper on one branch) refused, each with its method and offset.
7. **mini-csc**, a plan of its own when stage 4 is done: the ten
   programs, then `corelib.cs` (decision 3).

## After it

- **The JIT** (lesson 6): a method's IL to mini-asm's objects (arm,
  arm64) the first time it is called, the verifier's types its input.
  ix is where that is cheap, as for Pascal's P-code. A plan of its
  own.
- **Another language on the same machine** (lesson 2): the cheapest
  proof that the machine is not C#'s. mini-ml's or mini-pascal's
  front end, to IL.

## Open questions

- The order of stage 1: TinyDotnet first (proposed: it is the
  cheapest way to find what the reader's estimate misses), or after
  the runtime, as its summary?
- The assemblies in the tree (decision 2): accepted as test data, or
  only where an SDK is installed, the tests skipped elsewhere?
- The library in OCaml (decision 3) until mini-csc: or mini-csc
  before stage 4, so that `List` is C# from the start?
- mini-csc's place: `languages/dotnet/csc/` (decision 9), or a
  `languages/csharp/` beside `languages/c/`?
- The verifier: a stage (6), or left to the JIT's plan, which needs
  the same pass?

## Status

2026-10-12: plan written, after the survey. `languages/dotnet/survey/`:
`programs/` (ten `.cs`, 295 lines of C#, and their `.expected`, by
Microsoft's runtime 8.0.31), `Survey.cs`, `survey.sh`, `survey.txt`.
Checked: the ten compile and print what is recorded; the survey run
twice, the same. Not checked: that `csc -deterministic` writes the
same bytes on another machine (decision 2 leans on it); mini-ml's
code for `Int32` and `Int64` (decision 6); every estimate of lines.
