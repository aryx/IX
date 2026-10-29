(* mini-csc: a C# reduced to what the survey's simpler programs need,
 * compiled to .NET (plan_dotnet.md, its stage 6 and decision 11):
 * classes, interfaces, virtual methods, statics, constructors, a
 * property's getter, arrays, strings, exceptions, foreach over arrays
 * and the library's collections, out parameters. Not: structs,
 * generics of the program's own, lambdas, interpolation, switch. Its
 * usage: [usage] in CLI.ml.
 *
 *     shapes.cs
 *        | Csc_lexer, Csc_parser    ocamllex's; by hand (C# is not LALR)
 *     Csc_ast
 *        | Csc_types                the classes, the library's from
 *        |                          Library, overloads
 *        | Csc_compile, Csc_emit    the classes declared, the bodies'
 *        |                          IL (Writer: languages/dotnet/)
 *     shapes.dll, shapes.runtimeconfig.json
 *
 * Its assemblies run on Microsoft's dotnet and on mini-dotnet; its
 * test (tests/features.cs) prints what Microsoft's csc's assembly
 * prints.
 *
 * history:
 * C# (2000, Anders Hejlsberg's team at Microsoft) was .NET's language,
 * Java's shape with Delphi's properties and events; its compiler, csc,
 * was in C++ until Roslyn (2014), in C#, open source, its parser
 * written by hand. Mono had its own, mcs (Miguel de Icaza, 2001), the
 * first C# compiler written in C#.
 *
 * References: ECMA-334, "C# Language Specification", 1st edition
 * (2001), the language this reduced one is of. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
