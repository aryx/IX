# Plan: .NET in ix: mini-dotnet, a runtime for the assemblies Microsoft's compiler writes, its library over lib_core, two compilers to it (mini-tiger, a reduced mini-csc), and its JIT (`languages/dotnet/`, `languages/tiger/`)

The author (2026-10-12): "how much would would be a mini-dotnet?
Mostly for its teaching aspect, so people can learn what is the
essence of dotnet"; then: "let's make a plan document for it
(including the TinyDotnet.ml too)".

Revised (2026-10-29), the author: "I'm not a big fan of C# but one
thing we could do is have a mini-C# really reduced, and also to have
a mini-tiger (see ~/github/fork-tiger) that targets dotnet instead of
currently c--. Also another thing of great value will be the JIT as
we don't have one yet. [...] we can't emulate the whole dotnet
libraries, but ideally we can reuse a lot lib_core/ and just have an
adapter for dotnet for many of its libs [...] ideally the Jitted code
can call those adapted native compiled ocaml libs"; "I don't think we
need a TinyDotnet"; "we can copy fork-tiger or just reimplement it
from scratch using fork-tiger (and other sources) for inspiration.
let's keep the JIT in the same plan document"; "that way we would
have in languages/ a good coverage of compiler techniques".

The short answer: **about 4,250 lines of .ml for the runtime (its
verifier in it), 700 for the assembly's writer, 1,600 for mini-tiger,
2,200 for a reduced mini-csc, 1,700 for the JIT**, in about that
order. The runtime (mini-dotnet) reads the `.dll` that Microsoft's
`csc` writes and runs it, in OCaml, the heap OCaml's: what it prints
is checked against what Microsoft's `dotnet` prints for the same
file. The lines are estimates, from the neighbours' sizes
(mini-smalltalk 5,568 lines of .ml, mini-pascal 1,952, TinyML 1,659,
fork-tiger's front end 2,725); what the estimates stand on is
counted: ten programs written for this, compiled, and their
assemblies read (the survey, below).

What decides the plan's shape is one number of that survey:
**Microsoft's library cannot be run**. `System.Private.CoreLib.dll`
is 2,466 types, 33,768 methods and 1.3 MB of IL, and the ten programs
ask 47 members of it. So the library is ix's own: adapters over
lib_core, OCaml compiled to the machine, that the interpreter and the
JIT's code both call.

**Status: stages 1 to 8 done** (the reader and the listing; the
machine: objects, value types, generics, delegates; `dotnet` and
`tiger` on mini-9pi's card; the writer and mini-tiger,
`languages/tiger/`, and the reduced mini-csc, `languages/dotnet/csc/`,
whose assemblies Microsoft's dotnet and mini-dotnet both run; the
verifier, `-verify`; the JIT's code as text, `-S -jit`, its first
methods those of int32s, their code run from C under mini-5i); stage 9
begun on arm64 (Linux): `mini-dotnet -jit` runs the JIT's code for
those methods, in 97.9% less time than the interpreter on bench.cs,
and for methods of references too (objects, arrays, strings), the
interpreter called for the rest. See the end.

## Its place in `languages/`

Each language there is also a technique of implementing one, and
.NET with Tiger brings the one missing: **the JIT**.

| folder | the technique |
|---|---|
| `c/` | a classic compiler, to the machine's code (Plan 9's 5c, 7c) |
| `pascal/` | one pass to a portable code, P-code, and its machine |
| `smalltalk/` | a bytecode VM with its image (the Blue Book) |
| `scheme/` | abstract machines: CESK, Landin's SECD |
| `prolog/` | Warren's machine (the WAM) |
| `forth/` | threaded code |
| `datalog/` | rules run bottom up to their fixpoint |
| `ml/` | a functional language, native: closures, a GC, SSA |
| `dotnet/`, `tiger/` | **a typed, self-describing VM; a language put on a machine that was not made for it; a verifier; a JIT** |

The third line is P-code's, the last is its sequel: a portable code
again, but typed and kept with its metadata, so that a pass can know
each stack slot's type and compile the method when it is first
called.

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
   the rules (the CLS) of what one language may show another. Here,
   Tiger shows it: its nested functions are not the machine's, and
   become classes.
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
   compiled to the machine's code the first time it is called. Here,
   the interpreter comes first (it is the reference), the JIT after,
   and they run together: what the JIT does not compile, the
   interpreter runs.

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
| the metadata | 150 | the 45 tables' shapes as data, the heaps' indexes: shared by the reader and the writer |
| the reader | 550 | the PE's sections, the metadata's heaps, the tables from their shapes, the signatures (blobs), a method's body (its two headers, the exception clauses) |
| the instructions | 250 | the 226 opcodes as a table (name, operand), a body decoded; the listing (`-S`), as `ildasm`'s |
| the types | 900 | a class loaded when first used: its layout (decision 4), its table of virtual methods, its interfaces; references resolved by name; a generic type or method instantiated (lesson 5); static constructors |
| the machine | 1,100 | frames, the evaluation stack of tagged values, the instructions; structs and managed pointers (lesson 4); delegates; the exceptions' two passes (the handler found, then the `finally` on the way) |
| the library | 600 | the adapters over lib_core (decision 3): the survey's 47 members, and Tiger's |
| the verifier | 600 | each method's stack types at each instruction, by lesson 3's pass; the JIT's input |
| `CLI`, `Main` | 100 | `mini-dotnet file.dll`; `-tables`, `-S`, `-trace`, `-verify`, `-jit` |
| all | 4,250 | |

The writer, `languages/dotnet/` too, about **700**: the reader's
inverse, the tables and heaps and a method's body written, and the
PE around them. Built with mini-tiger, used by mini-csc after.

mini-tiger, `languages/tiger/` (decision 10), about **1,600**: the
lexer 150 (ocamllex), the grammar 300 (ocamlyacc), the tree 100, the
names and the types 450, the escapes and the frames as classes 250,
the IL 350. Tiger as Appel's book defines it, with fork-tiger's
exceptions (`exception`, `raise`, `try ... handle`), which are the
machine's own.

What the machine makes of Tiger, its lesson 2:

- `int` is `int32`, `string` is `System.String`, `nil` is `ldnull`,
  a record type is a class of fields, an array type `T[]` of its
  element's type. A string's `=` is its content's
  (`String::op_Equality`), a record's its reference's: Tiger's own
  rules, both found in the machine.
- **Nested functions, which IL has not.** Appel's escape analysis
  (his chapter 6) decides it: a function whose locals a nested one
  uses gets a class, its frame, those locals its fields; the others
  stay IL's locals. A nested function is a static method whose first
  argument is its static link, the frame of the function around it.
  Where a C compiler puts the static link in a register and the frame
  on the stack, here they are an object on the heap, collected.
- Tiger's library (`print`, `getchar`, `ord`, `chr`, `size`,
  `substring`, `concat`, `not`, `exit`, `flush`) is a class `Tiger`
  that mini-tiger writes into each assembly, its methods a few
  instructions on `System.Console` and `System.String`. So what
  mini-tiger writes runs on Microsoft's `dotnet` too, and on ours by
  the adapters behind those members.

mini-csc, `languages/dotnet/csc/`, **reduced** (decision 11), about
**2,200**: the lexer 200, the grammar 500, the tree 150, the names
and the types 700 (overloads by the arguments' types, as
`Console.WriteLine` needs; the conversions; boxing), the lowering 200
(`foreach` over a `List`, the string's `+`), the IL 450; the writer
is mini-tiger's.

The JIT, `languages/dotnet/jit/` (decision 12), about **1,700**: the
code of each instruction for arm 700 and arm64 400 more, the frame
and its slots 200, the stubs (the first call, the calls into the
runtime and the library) 200, the loader (executable memory, the
caches) 100, `-jit -S` 100.

For the scale, from memory and not measured: Microsoft's Shared
Source CLI ("Rotor", 2002, the book *Shared Source CLI Essentials*)
was millions of lines; Chris Bacon's DotNetAnywhere, an interpreter
in C with a library of its own (the first Blazor ran on it), some
tens of thousands. The standard is ECMA-335; its Partition II is the
reader, Partition III the machine.

## Decisions (proposed, for the author)

1. **The runtime first, the compilers after.** Reading Microsoft's
   assemblies gives a reference for every stage: the same file, two
   runtimes, what is printed compared. A compiler first would be
   checked by nothing until its runtime exists.
2. **The assemblies are in the tree, as test data**: the ten `.dll`
   (46 KB) beside their `.cs` and `.expected`, written again by
   `survey.sh` where there is an SDK. Microsoft's compiler is not in
   m-ix, and the tests must run there. When mini-csc exists it makes
   those it can, and the committed ones are the comparison.
3. **The library is adapters over lib_core**, not C# and not
   Microsoft's. A member of `System.*` is looked for by its type, its
   name and its signature in a table of OCaml functions; a
   reference's assembly (`System.Runtime`, `System.Console`) is not
   read. `Dictionary` is lib_core's `Hashtbl`, `Stack` and `Queue`
   theirs, `StringBuilder` is `Buffer`, `String`'s methods `String`'s,
   `Console` the standard output by its capability. One adapter serves
   every instantiation (OCaml's values are uniform); the instantiation
   is kept in the object's header, for `typeof` and `is`. What the
   adapters must do that lib_core does not:
   - a `Dictionary`'s keys hashed and compared by their
     `GetHashCode` and `Equals`, virtual, maybe a user's class: a
     `Hashtbl.Make` whose functions call back into the machine;
   - iterated in the order of insertion, which .NET does in practice
     and programs come to rely on, where `Hashtbl` does not;
   - OCaml's exceptions turned into .NET's at the border (`Not_found`
     is `KeyNotFoundException`, `Invalid_argument` an
     `ArgumentOutOfRangeException`);
   - a struct copied when it goes into a collection.
   An adapter takes and gives the machine's values (decision 5), so
   the interpreter and the JIT's code call the same function.
   (Not taken: a `corelib.cs` compiled by mini-csc, as Microsoft's
   library is made, nor a `corelib.dll` made by Microsoft's compiler
   and committed.)
4. **The heap is OCaml's, and an object has a layout**, so that the
   JIT's code can reach a field by its offset, not by its name. An
   object is an OCaml block: its type first, then a string of bytes
   holding its scalar fields (`int32`, `int64`, `float64`, raw, at the
   offsets its class's layout gives), then its references. An array
   of scalars is that string of bytes; an array of references a
   block. A struct inside an object is flattened into it, its scalars
   into the bytes, its references among the references. So OCaml's
   collector needs no map of where the pointers are: they are apart
   from the scalars by construction, where a real CLR tells its
   collector. A managed pointer, in the interpreter, is a container
   and an index (a frame's local, an object's field, an array's
   element), not an address. (To check: that mini-ml's runtime keeps
   a string's bytes unscanned, as OCaml's does.)
5. **A value carries its type in the interpreter**, the simple path
   of lesson 3: `I4`, `I8`, `R8`, a reference, a struct, a pointer.
   The JIT's code has no tags: the verifier gave it the types.
6. **int32 exactly.** `fib` prints -1323752223 for the 47th number. A
   Pi 1's OCaml int is 31 bits: an `I4` is an `Int32.t` there
   (lib_core has it; mini-ml's code for it to check), and in the
   object's bytes it is 32 bits wherever it runs. In the JIT's code
   an `int32` is a register.
7. **Strings**: .NET's are UTF-16 and immutable. Proposed: OCaml's
   strings and Latin-1 at first (`Length` and `[i]` exact for the
   tests' text), said in the header; UTF-16 a later change of one
   module. A .NET string is an OCaml string, so `String`'s adapters
   are lib_core's `String` with nothing between.
8. **The compilers' contract is the program's output, not the
   bytes.** Roslyn's assembly, row for row, is not a target one can
   hold (its order of rows, its attributes, its names for a lambda's
   class). Checked both ways instead: mini-dotnet runs what `csc`
   wrote, Microsoft's `dotnet` runs what mini-csc and mini-tiger
   wrote.
9. **The names**: `mini-dotnet` (Microsoft's command: `dotnet
   file.dll`), `mini-csc`, `mini-tiger`; on mini-9pi's card `dotnet`,
   `csc` and `tiger`. The directories `languages/dotnet/` (the
   runtime, the writer, `jit/`, `csc/`) and `languages/tiger/`; in
   `languages/README.md`, mini-dotnet in the table of the languages
   that are run, mini-tiger and mini-csc as compilers to it.
10. **mini-tiger is written here, fork-tiger its inspiration, not
    copied.** fork-tiger (`~/github/fork-tiger`) is a front end to
    C-- (`qc--`): its lexer, grammar and types are what Tiger is,
    and they are read for that, with Appel's book (*Modern Compiler
    Implementation in ML*) and his manual of the language. What is
    not taken: its translation to Appel's trees, which has erased the
    types and laid the frames out as offsets in memory, the wrong
    level for IL, which wants typed locals and fields; and its code,
    which must build by mini-ml (ocaml-light's language) to run on
    mini-9pi, and read like ix's other languages (`CLI.ml`,
    `Main.ml`). Its tests are taken: `tests/*.tig` and their outputs,
    with Appel's. A second back end, to native code by cmm, is
    plan_cmm.md's (the author: "we can target both cmm and dotnet for
    tiger"): the front end stays typed and shared.
11. **mini-csc is a C# reduced to what the survey's simpler programs
    need**: classes, interfaces, virtual methods, statics, arrays,
    strings, exceptions, `foreach` over the library's collections,
    the library's generic types used (`List<int>`, so instantiations
    checked) but none defined. Not: structs, generic classes and
    methods of the program's own, lambdas and delegates,
    interpolation, properties beyond the library's, `switch` on
    strings. Of the ten: `hello`, `fib`, `queens`, `shapes`,
    `exceptions`, `collections`, and `strings` with its interpolation
    and switch written otherwise; not `vec`, `generic`, `closures`,
    which the runtime still runs, from Microsoft's compiler.
12. **The JIT**:
    - **When**: a method is compiled the first time it is called
      (lesson 6). A method's entry is a cell, at first a stub that
      calls the JIT and writes the code's address in the cell;
      callers jump through it.
    - **Its input is the verifier's**: at each instruction the depth
      of the stack and each slot's type. So each slot of the stack is
      a known place in the frame, and the stack has no pointer of its
      own at run time.
    - **A template JIT**: each instruction a fixed sequence of the
      machine's, no allocation of registers between instructions.
      The lesson is what the types make possible, not optimization;
      a cache of the stack's top in registers after, measured.
    - **The collector's roots**: a frame's slots that are references
      (locals, arguments, the stack's) live on mini-ml's value stack
      (R10, R26 on arm64; `ml_vsp`), where its collector already
      looks; the scalars on the machine's stack, raw. So no map of
      the frame is needed, as decision 4 needed none for the objects.
    - **Its calls follow mini-ml's conventions**, those numbered in
      mini-ml's `Emit` (d4263bba): the runtime (allocation, a type
      loaded, a throw) and the library's adapters are ML closures,
      called as mini-ml calls them, R10 stored to `ml_vsp` before and
      loaded after. That is how the JIT's code calls lib_core,
      compiled by mini-ml, directly.
    - **With the interpreter, not instead of it**: what the JIT does
      not compile at first (a method with exception clauses, with
      managed pointers or structs on its stack, with a generic's
      shared code) the interpreter runs, and the two call each other
      through the cells and one stub each way. `-jit=0` runs all by
      the interpreter, the reference.
    - **Where it runs**: only where mini-dotnet is built by mini-ml
      (on mini-9pi, arm under mini-5i and QEMU; arm64 where mini-ml
      targets it), since its code follows mini-ml's conventions; a
      build by ocamlopt has the interpreter alone.
    - **The machine's code is made with mini-asm's objects and the
      linker's encoders** (`linker/Arm.ml`, `Arm64.ml`), as a library,
      not again; `-jit -S` prints it as mini-asm's text, which
      mini-asm assembles, the encoding checked by the assembler.
    - **The executable memory**: written, its data cache cleaned and
      its instruction cache invalidated, then run. On mini-9pi a
      segment both writable and executable, by a call of the kernel
      (to design: a `segattach`'s kind, or one of its own); under
      mini-5i and mini-qemu, their own caches of decoded or
      translated code told, which they may not be today.
    - (Not taken: compiling ahead of time, IL to an executable by
      mini-ld. The same code generator, without the executable
      memory, but the program's code linked with all of mini-dotnet
      for each program; and it does not show lesson 6.)

## The stages (each checked before the next)

1. **The reader and the listing** (`-tables`, `-S`). Check: the ten,
   their counts of rows by table `survey.txt`'s; and **Microsoft's
   own library read whole**: 2,466 types, 33,768 methods, 1,332,098
   bytes of IL decoded to the last byte of each body, `Survey.cs`'s
   numbers.
2. **Objects**: classes, virtual calls, interfaces, strings, arrays,
   statics, exceptions; the objects laid out (decision 4), the
   library's adapters for these. Check: `hello`, `fib`, `queens`,
   `shapes`, `exceptions`, `strings`.
3. **Value types and generics**: structs, boxing, managed pointers,
   instantiation, delegates; `List` and `Dictionary` over lib_core.
   Check: `vec`, `generic`, `collections`, `closures`; the ten the
   same by mini-ml's build, on arm64 and on arm under mini-5i
   (decision 6).
4. **On mini-9pi's console**: `dotnet` on the card, the assemblies in
   `/lib/dotnet/`. Check: a recorded session, as `check-pascal`; the
   queens' time, here.
5. **The writer and mini-tiger.** Check: fork-tiger's tests and
   Appel's, each printing its recorded output by Microsoft's `dotnet`
   and by mini-dotnet; the nested functions' frames listed by `-S`;
   the writer's assemblies read back by the reader, the same tables.
6. **mini-csc, reduced** (decision 11). Check: its seven of the ten
   print their `.expected` by both runtimes.
7. **The verifier.** Check: the ten, mini-tiger's and mini-csc's
   assemblies pass; assemblies broken by hand (an `add` of an int and
   a reference, a stack left deeper on one branch) refused, each with
   its method and offset; Microsoft's library: how many of its
   methods pass, recorded.
8. **The JIT's code as text** (`-jit -S`): each method the JIT
   accepts printed as mini-asm's text. Check: mini-asm assembles it;
   the methods refused counted, with their reason, for the ten and
   mini-tiger's tests.
9. **The JIT**, on mini-9pi (arm). Check: everything of stages 2 to 6
   prints the same with `-jit` and `-jit=0`; the queens' and a
   Tiger program's instructions under mini-5i, both ways, recorded.
10. **The JIT on arm64**, and what it refused at first (exceptions,
    structs), one at a time, each by the same check.

## After it

- The stack's top cached in registers; a method's locals given
  registers; inlining of the library's small adapters (`String`'s
  `Length`). Each measured against stage 9's numbers.
- Tiers, as .NET has: interpreted first, compiled when called often.
- mini-ml to IL, a third language on the machine.

## Open questions

- The assemblies in the tree (decision 2): accepted as test data, or
  only where an SDK is installed, the tests skipped elsewhere?
- The object's layout (decision 4): its scalars in a string of bytes
  beside its references costs a load more for each scalar field;
  measured against the other way, everything tagged OCaml values
  (simple on arm64's 63 bits, not on arm's 31)?
- The adapters (decision 3): each on the machine's tagged values, as
  proposed, or typed OCaml functions (`string -> unit`) with the
  marshalling generated from the signature, which the JIT's code
  could call with no value made?
- mini-tiger's place: `languages/tiger/` (decision 9), or
  `languages/dotnet/tiger/` beside `csc/`?
- The JIT's executable memory on mini-9pi (decision 12): which call
  of the kernel? The author (2026-10-30): segflush, Plan 9's, made
  real, and segattach as a general mechanism, as Linux's mmap and
  mprotect.

## Status

2026-10-12: plan written, after the survey. `languages/dotnet/survey/`:
`programs/` (ten `.cs`, 295 lines of C#, and their `.expected`, by
Microsoft's runtime 8.0.31), `Survey.cs`, `survey.sh`, `survey.txt`.
Checked: the ten compile and print what is recorded; the survey run
twice, the same. Not checked: that `csc -deterministic` writes the
same bytes on another machine (decision 2 leans on it); mini-ml's
code for `Int32` and `Int64` (decision 6); every estimate of lines.

2026-10-29: revised. TinyDotnet.ml dropped; mini-tiger, written here
from fork-tiger's and Appel's inspiration, and a reduced mini-csc;
the library as adapters over lib_core; the objects laid out for the
JIT; the JIT in this plan (decision 12, stages 7 to 10). Nothing
built.

2026-10-29 (night), stage 1, the author: "let's do the dotnet plan"
(the plan's order; a commit a stage; mini-tiger in `languages/tiger/`;
the assemblies in the tree). Metadata (the 45 tables as data), Image
(the PE, the heaps, the tables, a method's body and its clauses),
Signature (the blobs), Il (the opcodes as a table, a body decoded, an
instruction encoded: the writer's), Listing (`-tables`, `-S` as
ildasm, `-size`). The ten `.dll` in `survey/programs/` (`survey.sh
-dll` writes them again; the same bytes twice: `-deterministic`).
Checked: the rows by table of the ten, summed, are survey.txt's 19
lines; `tests/run.sh` (in make test) the ten's `-S` against
`tests/expected/`, by dune's build, by mini-ml's on arm64 and on arm
under mini-5i (`-5`, an int of 31 bits); `tests/run.sh -sdk`
Microsoft's five assemblies read whole, System.Private.CoreLib's 2,466
types, 33,773 methods and 1,332,333 bytes of IL (runtime 8.0.32), each
body decoded, the same numbers as Survey.cs's; in 0.23 s by dune's
build, 0.45 s by mini-ml's.

2026-10-29 (night), stages 2 and 3, together (one machine): Value (the
types and values; an object's numbers in bytes, its references in an
array, as decision 4; a struct flattened in an object or an array; a
managed pointer a slot, a place in bytes, or a struct inside a store),
Library (61 classes of System, 655 lines: Object, the primitives,
String, Console, 18 exceptions, StringBuilder, the interpolation's
handler, Type, List and its Enumerator, Dictionary in its order of
insertion, the delegates, RuntimeHelpers.InitializeArray), Types (the
loader: classes from their rows or the library's descriptions, laid
out, vtables with newslot and MethodImpl, interfaces by key, generic
classes and methods instantiated, each once), Machine (the IL on
tagged values, statics and .cctor, virtual calls and `constrained.`,
boxing, the exceptions' two passes with filters, `leave` and the
finally blocks, an unhandled exception said as .NET does, exit 134).
Not as planned: native int is 32 bits; a string's character above 255
is "?"; `AppendFormatted<bool>` would print 1 (a native has not its
type arguments); no Remove for Dictionary; multi-dimensional arrays,
calli, localloc, typedref refused with their method and offset.
Checked (`tests/run.sh`, in make test): the ten print their
`.expected`, and two programs of ours, `tests/programs/corners.cs`
(explicit interfaces, `new virtual`, a struct in an object, a static
constructor's moment, switch on strings by their hash, int64, uint,
checked overflow, doubles as .NET writes them, a filter, rethrow, a
Dictionary of ints, boxes' ToString, int.Parse, an array initializer)
and `unhandled.cs` (the finally blocks not run, exit 134), against
Microsoft's runtime (`tests/programs/build.sh`); by dune's build, by
mini-ml's on arm64, and on arm under mini-5i (31-bit ints, decision
6). The queens: 360,572 instructions, 0.02 s by dune's build, 0.03 s
by mini-ml's.

2026-10-29 (night), stage 5, before stage 4: the card is made by
building all of ix for Plan 9, languages/ml with it, and another
session's work in progress stopped that build for an hour; stage 4
comes next. The writer (`Writer`, 477 lines: an assembly named and
defined in any order, a field's and a method's token provisional
until their rows are laid out at the end, a method's .maxstack
computed from `Il.stack_effect`, the PE with one section and no stub of
machine code, a GUID that is a digest of the name, so the same bytes
each time) and mini-tiger (`languages/tiger/`, 1,198 lines: the lexer
by ocamllex, the grammar by ocamlyacc, conflict-free, Tiger_semant for
the names, types and escapes in one pass, Tiger_emit for the frames as
classes and the IL). Decisions taken on the way, fork-tiger's
behaviour over Appel's where fork-tiger's recorded outputs need it:
an array's initial value evaluated for each element (fork-tiger's
new_array; Appel's initArray once); `ord` of a string not one
character long stops the program with status 1 (fork-tiger's;
Appel's gives -1 for ""); `var x := nil` accepted, x then the type of
the first record it is given (Appel's test45 says an error); `and` and
`or` as words. The console set to Latin-1 at Main's start, so that a
byte above 127 is one character in and out (rc4); mini-dotnet's
library has `Encoding.Latin1`, `Console.set_OutputEncoding`,
`Environment.Exit`, `Char.ToString(char)`, `String.CompareOrdinal`;
a recursion of more than 10,000 frames stops mini-dotnet as .NET's
stack overflow does (exit 134). Not done: a `try` inside an
expression whose stack is not empty (.NET refuses it; Tiger's are
statements in the programs here); the frames' links of a function
that has none of its own variables escaping still made.
Checked (`languages/tiger/tests/run.sh`, in make test): fork-tiger's
14 programs (all of its tests but spawn: arrays, colmajor, exceptions,
forloop, funcall, hello, merge, qsort, queens, rb, rc4, sieve, wf,
wff), their inputs and their outputs as fork-tiger's compiler printed
them, by mini-dotnet, and by Microsoft's dotnet 8.0.32 (`-ms`); Appel's
49 test programs, each one's error or its exit, recorded
(`appel.expected`), all of Appel's errors refused but test45's; by
dune's builds, by mini-ml's on arm64 and on arm (mini-dotnet under
mini-5i). `languages/dotnet/tests/writer/Hello.ml`: an assembly by
hand (a static field, a loop, a try with a catch and a finally), read
back (-S) and run, by mini-dotnet and by Microsoft's dotnet.

2026-10-29 (night), stage 4: `dotnet` and `tiger` on mini-9pi's card
(kernels/9pi's Makefile: IXDIRS, CARD_devtools, the survey's ten
assemblies and unhandled.dll in `/lib/dotnet`, four of fork-tiger's
programs in `/lib/tiger`), their pages in the manual
(docs/man/1/dotnet.md, tiger.md). `make check-dotnet`: a session
(tests/session-card-dotnet.cmds: hello, fib, the queens with -s,
shapes, generic, closures, hello's -S, an unhandled exception and its
status, Tiger's queens and exceptions compiled on the card and run,
a type error), recorded under QEMU (21 s), the same under mini-qemu
(2 min 57 s). The queens' time on the card, under QEMU: 1.55 s by
mini-dotnet (360,572 instructions), 1.63 s for mini-pascal's
QUEENS.PAS, 1.19 s for Tiger's queens compiled by mini-tiger there
(a measure of the emulator, not of a Pi).

2026-10-29 (night), stage 6: mini-csc (`languages/dotnet/csc/`, 1,870
lines with its lexer): Csc_lexer (ocamllex), Csc_parser (by hand,
recursive descent: C# is not LALR(1), its casts and its generic
arguments need a type looked past, and Roslyn's parser is written by
hand too; ocamlyacc refused for that, as parser-technology asks to
justify), Csc_types (the types, the program's classes, the library's
from mini-dotnet's own Library.specs, so a member mini-csc accepts is
one mini-dotnet has; overloads by the cost of the arguments'
conversions), Csc_emit (the IL in one pass, a choice that needs types
first made by compiling and throwing away), Csc_compile (the classes
declared, a TypeDef's row known before it is made, an interface's
methods made virtual final, then the bodies). The writer got
InterfaceImpl rows. Beyond decision 11's list: a property's getter
(shapes' Count), out and ref parameters and arguments
(TryGetValue), `do`, `continue`, the conditional, `is`, casts of
numbers and of references, boxes and unboxes, a try with catches and a
finally, a return inside a try (a leave). Not: foreach's finally that
disposes its enumerator. Checked (`csc/tests/run.sh`, in make test):
hello, fib, queens, shapes, exceptions, collections and
`csc/tests/strings.cs` (the survey's strings without its interpolation
and its switch) print the survey's `.expected`, and
`csc/tests/features.cs` what Microsoft's csc's assembly of it prints,
by mini-dotnet and by Microsoft's dotnet (`-ms`); vec, generic,
closures and the survey's strings.cs refused, each with its line; by
dune's builds, by mini-ml's on arm64 and on arm under mini-5i.

2026-10-29 (night), stage 7: the verifier (`Verifier`, 477 lines;
`mini-dotnet -verify`): each method's paths followed from its first
instruction and its handlers' (a worklist of the instructions whose
stack changed), the stack's depth and each slot's kind at each
instruction (Partition III's int32, int64, native int, F, a
reference, a managed pointer, a value type, and a type parameter's
value), two paths joining with the same depth and kinds, each
instruction's operands of the kinds it takes (table 2 for the
arithmetic), a call's arguments, a ret's value, .maxstack. It reads
the metadata only, not Types' classes, so it goes over Microsoft's
library; a reference's class is not checked against what is asked,
the rules of access neither. An unmanaged pointer (native int) is
taken where a managed one is: C#'s unsafe code, correct and not
verifiable. Its result, the stacks, is the JIT's input. The writer
now writes a stack popped empty as it is (the verifier's to refuse;
its depth 0) instead of failing. Checked (`tests/run.sh`): every
method of the survey's ten, of ours, of the writer's hello, of
mini-tiger's 14 and mini-csc's 8 assemblies passes; writer/Broken.ml
writes eight methods each broken one way (an add of an int and a
string, a stack deeper on one path than the other where they join, a
value left at ret, a string for an int, a branch on a float, an empty
stack popped, the code falling off the end, a ret with no value),
each refused with its offset and why (`writer/broken.verify`);
Microsoft's System.Private.CoreLib (`-sdk`): 31,816 of its 31,819
methods with a body pass in 4.3 s, the 3 others use refanytype.

2026-10-30 (night), stage 8: the JIT's code as text (`Jit`, 253 lines;
`mini-dotnet -S -jit file.dll`): arm's instructions as mini-asm reads
them, a template each IL instruction, each slot of the stack a place in
the frame from the verifier's depths. Its first methods are those of
int32s only (static; parameters, locals, result and every stack slot
an int32; calls to such methods of the same assembly; no exception
clause), and such a method is a C function for 5c (its first argument
in R0, the others at 4(i+1) on the caller's stack, its result in R0,
its frame mini-ld's): so a C program can call it. The templates: the
arguments and locals, ldc, dup, pop, add sub mul and or xor, the
shifts (their count's 5 bits), div rem and their .un (a zero divisor
to jit_divide_by_zero, the runtime's), neg, not, ceq cgt clt and
their .un, the conversions to the small integers, br, brtrue,
brfalse, the conditional branches signed and unsigned, switch, call,
ret. The others are refused with their reason: over the survey's
ten, mini-tiger's 14 and mini-csc's 8 assemblies, 6 of 325 methods
compiled (Fib's two among them), the others for a reference on the
stack or in a signature, a call into the library, an instance
method, exception clauses, ldsfld. Checked (`tests/run.sh`, in make
test): every assembly's text assembles by mini-asm; Fib's Rec and
Loop, and `tests/jit/ints.cs`'s eleven methods (every template:
Euclid's gcd, powers, bits counted with an unsigned shift, a mix of
the operators, a switch, unsigned comparison and division, the
narrowing conversions, a clamp writing its arguments, Collatz,
Ackermann), their text assembled and linked with a C program
(`tests/jit/*.c`) by mini-ld against Plan 9's libc for arm, run under
mini-5i, print what the interpreter and Microsoft's runtime print; the
same text by dune's build and mini-ml's.

What stage 9 needs, beyond this: the references (decision 12: on
mini-ml's value stack, R10, where its collector finds them; an
object's field at its offset in its bytes, as decision 4 laid them
out), the library's adapters and the interpreter called as mini-ml
calls a closure, a method's entry a cell and its first call a stub,
and the code written into memory and run, which on mini-9pi wants a
kernel's call, the open question below, and mini-5i's and mini-qemu's
caches of decoded code told. Left for the author's answer.

2026-10-30, stage 9 begun, on arm64 first. The author, asked which
call of mini-9pi gives the JIT its memory: "let's do segflush then,
but seems also useful to implement segattach as a general mechnaism a
la mmap and mprotect. But first does the JIT work on linux before
mini-9pi? So I can test on the host first?"; then "hopefully we can
measure the speed increase of the JIT approach vs the pure
interpreter approach". So the order of stages 9 and 10 changed for
the code generator: arm64's templates first, run where mini-ml builds
mini-dotnet for Linux on arm64 (the author's machine), then arm under
mini-5i and on mini-9pi with segflush.

What is done. Jit's templates for both machines (`-S -jit -m 7`:
arm64's, 7c's convention, W instructions on the low 32 bits, a slot
of 8 bytes, a branch over a move where arm has a conditional move:
mini-ld encodes no CSET); arm's text unchanged. `Jit_run`: at the
first call of a method the JIT takes, its assembly's methods are all
compiled at once (Jit.program: the methods, and an entry for each),
the text read by mini-asm's parser and encoded by mini-ld's passes
used as a library (Link.load_objects, new: objects in memory; then
Arm64's prepare, rewrite, layout, encode), at address 0: the code has
none of its own, branches and the literal pool being relative to the
pc. `Code_memory`: the bytes made executable by three system calls of
Linux and no C (memfd_create, write, mmap PROT_READ|PROT_EXEC: W^X,
the kernel making the instruction cache see the bytes as it maps
them); its file for dune's build has no JIT (ocamlopt's conventions
are not mini-ml's), mini-ml/'s is the mkfile's. A method's entry is
called as mini-ml calls a closure of one argument (Gen: R0 the
closure, R1 the argument, field 0 the code): a block of two fields,
the code's address in both, made through an int64's block, whose
field is a word the collector does not look in. The entry takes an
array of ints, untags them into 7c's places, calls the method, tags
its result. A division by zero calls an ML function by its static
closure's address (Code_memory.divide_by_zero, a top-level function:
its closure does not move), which raises; the entry's caller turns
that into DivideByZeroException. Machine asks the JIT at a method's
first call (Machine.jit, its body still Il_body), and the method's
body is then Native. The value stack (R26) is not touched: the
methods' slots are all int32s, on the machine's stack.

Checked (`tests/run.sh`, 177 checks): the arm64 text recorded for
Fib and Ints (`jit/fib7.s`, `jit/ints7.s`), assembled by mini-asm
for every assembly; linked with the same C programs against Linux's
libc for arm64 and run on this machine, they print what the
interpreter prints; every program run with `-jit` by dune's build
(the interpreter) and mini-ml's (the JIT's code: Fib's, Ints', a
lambda of closures.dll, `jit/zero.cs`'s division by zero in compiled
code caught by the interpreter's catch, `jit/bench.cs`), what
Microsoft's runtime prints. All of languages/dotnet compiles by
mini-ml (26 files).

The speed (Linux on arm64, the author's machine; `jit/bench.cs`'s
methods each in a program of its own, the time of the whole process,
the JIT's compilation in it):

| | interpreter, mini-ml's build | interpreter, ocamlopt's (dune) | JIT | Microsoft's dotnet 8 |
|---|---|---|---|---|
| Fib(27), calls (5.7 M IL instructions) | 0.53 s | 0.35 s | 0.02 s | 0.08 s |
| Collatz's steps to 100,000 (174 M) | 7.17 s | 3.84 s | 0.16 s | 0.10 s |
| bits counted to 1,000,000 (239 M) | 9.64 s | 5.39 s | 0.20 s | 0.07 s |
| bench.cs, the three | 17.29 s | 9.45 s | 0.37 s | 0.13 s |

So the JIT's code takes 97.9% less time than the interpreter of the
same build (2.1% of it), and the interpreter itself goes about 24
million IL instructions a second. Microsoft's, which keeps values in
registers where these templates keep each slot in memory, takes 65%
less time than ours on bench.cs (0.13 s against 0.37), its start
(some 0.06 s) included.

Left: the references (decision 12: on mini-ml's value stack, R26),
the library's adapters called as closures, a method's entry a cell
compiled at its own first call, the code on arm under mini-5i and on
mini-9pi (segflush made real, mini-5i's and mini-qemu's caches of
decoded code told; segattach as mmap and mprotect).

2026-10-30, the references. The author, on the next steps (the
references, a method compiled at its own first call, arm and
mini-9pi's segflush and segattach): "let's do it!".

What is done. A method may hold references (arm64's, in mini-dotnet:
`-S -jit -m 7 -refs` prints that code): instance methods, parameters,
locals, results and slots of references, not of structs, int64s,
doubles or pointers; no try; no generic method or class. A reference
is the interpreter's value (Value.value), a word of mini-ml's: its
slot is on mini-ml's value stack (R26: the method raises it by its
words, each set to null, 1, before anything can collect; the
references given copied there), where the collector finds it and
moves it; an int32's on the machine's stack, each slot a home in both
and the verifier's type saying which. The code itself reads an
object's field (Obj's store, its bytes at the field's offset, its
references), an array's element (its length checked: the runtime's
IndexOutOfRangeException) and length, writes an int32 field or
element, tests a reference (null is 1) and compares two (the same
word, or the same store: Arith's equality); null dereferenced calls the
runtime's NullReferenceException. The rest is a call-out (decision
12's adapters, in the simplest form): the code calls jit_outN, an ML
function of the call-out's number and its operands (an int32 tagged),
which runs that one instruction in the interpreter (Machine.exec, its
loop for one instruction) and returns what it pushes: a call into the
library, to a virtual method, a constructor, an instance method; new,
newarr, ldstr, a static field, a cast, a box, throw, and a reference
stored (so the collector's write barrier is Machine's). A call to a
static method compiled is a BL, unless its class has a static
constructor and is not the caller's (the interpreter's call runs it).

Checked (`tests/run.sh`, 215 checks): every assembly's `-refs` text
assembled by mini-asm; every program with `-jit`, its code run by
mini-ml's build, prints what Microsoft's runtime prints (Main of fib,
hello, shapes compiled now, the library called from the code);
`jit/objects.cs`, new: a list of 300,000 nodes built and walked,
virtual calls over 30,000 shapes, int and byte arrays, strings joined
and repeated, references compared, a static counter, a null and an
index out of range thrown in compiled code and caught by Main (the
interpreter's try); the collector moves the objects many times while
the code holds them.

The speed (the author's machine): `jit/objects.cs`, 1.31 s by
mini-ml's interpreter, 0.97 s with the JIT (26% less; Microsoft's
0.14 s). Its sections: the list (300,000 `new` and a reference stored
in each, call-outs) 1.07 s and 0.82 s, the shapes 0.21 s and 0.18 s, a
static counter called 300,000 times (three call-outs a call) 0.39 s
and 0.32 s: a call-out costs some 350 ns, the interpreter's loop set
up for one instruction (its closures), and an object made by the
interpreter (a store: its record, bytes and references) as much as
the instructions. So next: call-outs made for their instruction
(the field, the method resolved once), separately and measured.

