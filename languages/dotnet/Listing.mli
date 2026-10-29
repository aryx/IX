(* An assembly as text: its tables row by row (-tables), and its types
 * and methods with their IL, as Microsoft's ildasm writes them (-S).
 * What the reader (Image, Signature, Il) understood, shown; the first
 * stage of plan_dotnet.md, and the way to look at what mini-tiger and
 * mini-csc write.
 *
 *     $ mini-dotnet -S hello.dll
 *     .assembly hello
 *     .class Hello extends [System.Runtime]System.Object
 *     {
 *       .method static void Main()   // RVA 0x2050, 11 bytes
 *       {
 *         .entrypoint
 *         .maxstack 8
 *         IL_0000: ldstr "Hello, World!"
 *         IL_0005: call void [System.Console]System.Console::WriteLine(string)
 *         IL_000a: ret
 *       }
 *       ...
 *
 * The names are the tokens' rows followed: a TypeRef's scope (the
 * assembly in brackets), a MemberRef's class and signature. *)

(* a token as ildasm names it: a type, a field or method with its class *)
val token_name : Image.t -> int -> string
(* a type's full name: Namespace.Name, a nested one Outer/Inner *)
val type_name : Image.t -> int -> string

(* -tables: each table that has rows, its columns' names, a row a line *)
val tables : Image.t -> string
(* -S: the types, their fields and methods, the IL *)
val listing : Image.t -> string

(* the survey's numbers, Survey.cs -size's: types, methods, bytes of
 * IL; each body's IL decoded (Il.Bad_il if one is not) *)
val sizes : Image.t -> int * int * int
