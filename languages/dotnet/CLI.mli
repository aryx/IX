(* mini-dotnet: .NET's assemblies, as Microsoft's C# compiler writes
 * them, read and run (docs/plans/done/plan_dotnet.md). Its usage: [usage]
 * in CLI.ml.
 *
 *     hello.dll                 a PE file, its metadata a database
 *        | Image                the PE's sections, the metadata's
 *        |                      heaps and 45 tables (Metadata: their
 *        |                      shapes), a method's body
 *        | Signature, Il        the blobs' types; the IL's opcodes
 *        |---------- Listing    -tables, -S (as ildasm), -size
 *        | Types                a class loaded when first named: laid
 *        |                      out, its virtual methods' slots; the
 *        |                      tokens resolved, generics instantiated
 *        | Machine              the IL run on tagged values (Value);
 *        |                      the exceptions' two passes
 *     what it prints            Library: System's classes, ix's own,
 *                               OCaml functions over the machine's values
 *
 *     $ mini-dotnet survey/programs/fib.dll
 *     6765
 *     102334155
 *     -1323752223              the 47th, past int32: wrapped, as .NET
 *     $ mini-dotnet -s survey/programs/queens.dll
 *     15863724
 *     92 solutions
 *     360572 instructions
 *
 * Checked by running what Microsoft's compiler wrote and comparing
 * what is printed with what Microsoft's runtime prints for the same
 * file (tests/run.sh): the same file, two runtimes.
 *
 * history:
 * Microsoft's .NET Framework (2002) was its answer to Java: a virtual
 * machine, the CLR, with a library and C#, a language by Anders
 * Hejlsberg (Turbo Pascal's and Delphi's author). Its machine, the
 * CLI, was made a standard (ECMA-335, 2001; ISO 23271), and Microsoft
 * published a version of it as source, "Rotor" (2002), for teaching.
 * Mono (Miguel de Icaza, 2004) ran it on Linux. In 2016 .NET Core,
 * Microsoft's own, became open source and ran everywhere; it is
 * today's .NET, whose `dotnet` runs the same files as here.
 * Before: the runtime grew from COM's (COM+ 2.0, its codename
 * Lightning), and was announced in 2000 as NGWS, then .NET. Sun had
 * sued Microsoft in 1997 over its Java (J++, its own extensions); the
 * extensions (delegates, calls of native code) came back in C#, and
 * Hejlsberg came from J++.
 * Project 7 (1998-2000): some fifteen language groups, Eiffel,
 * Mercury, Haskell, Standard ML, Scheme, Oberon, Python, COBOL among
 * them, given the runtime before it shipped to port their languages;
 * the common type system was to be shared, a class of one language
 * subclassed in another, and their reports changed the machine (the
 * tail. prefix). Generics (.NET 2.0, 2005) came from Microsoft
 * Research Cambridge (Andrew Kennedy, Don Syme, PLDI 2001), reified
 * in the machine, where Java's (2004) are erased by its compiler; F#
 * (Syme, 2005) followed.
 * Singularity (Microsoft Research, Galen Hunt and Jim Larus, 2003-2008)
 * an operating system in C#: Bartok compiled the whole system's IL
 * ahead of time, the verifier's guarantee standing in for the MMU
 * (processes isolated by their types, one address space); Midori
 * (2008-2015) carried it on.
 *
 * References: ECMA-335, "Common Language Infrastructure", 6th edition
 * (2012): Partition I the concepts, II the file and its metadata, III
 * the instructions; David Stutz, Ted Neward, Geoff Shilling, "Shared
 * Source CLI Essentials" (O'Reilly, 2003), Rotor read; Serge Lidin,
 * ".NET IL Assembler" (Apress, 2014). *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
