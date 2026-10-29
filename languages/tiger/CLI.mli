(* mini-tiger: Tiger, Appel's language from "Modern Compiler
 * Implementation in ML" (1998), compiled to .NET (plan_dotnet.md, its
 * stage 5): what it writes runs on Microsoft's dotnet and on
 * mini-dotnet. Its usage: [usage] in CLI.ml.
 *
 *     queens.tig
 *        | Tiger_lexer, Tiger_parser   ocamllex's and ocamlyacc's
 *     Tiger_ast                        Appel's Absyn
 *        | Tiger_semant                names and types (Appel's 5),
 *        |                             the escapes (his 6)
 *     Tiger_tree                       each name its declaration
 *        | Tiger_emit                  frames as classes, IL (Writer:
 *        |                             languages/dotnet/)
 *     queens.dll, queens.runtimeconfig.json
 *
 *     $ mini-tiger queens.tig && mini-dotnet queens.dll   (or dotnet queens.dll)
 *
 * history:
 * Andrew Appel designed Tiger for his textbooks (in ML, C and Java,
 * 1997-98): a small language of the Algol family, with nested
 * functions, records and arrays, to be compiled in a semester to a
 * real machine's code. fork-tiger (the author's) is a front end of it
 * in OCaml for C-- (Norman Ramsey's portable assembly language), with
 * exceptions added; mini-tiger is written anew from it and Appel's
 * book, its back end .NET's IL, and its cmm one plan_cmm.md's.
 *
 * References: Andrew W. Appel, "Modern Compiler Implementation in ML"
 * (Cambridge University Press, 1998), its appendix the Tiger Language
 * Reference Manual; fork-tiger (~/github/tiger). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
