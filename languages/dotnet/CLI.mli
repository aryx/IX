(* mini-dotnet: .NET's assemblies, as Microsoft's C# compiler writes
 * them, read and listed (docs/plans/plan_dotnet.md; its stage 1, the
 * machine that runs them its next stages). Its usage: [usage] in
 * CLI.ml.
 *
 *     hello.dll                 a PE file, its metadata a database
 *        | Image                the PE's sections, the metadata's
 *        |                      heaps and 45 tables (Metadata: their
 *        |                      shapes), a method's body
 *        | Signature, Il        the blobs' types; the IL's opcodes
 *     Listing  ---------------  -tables, -S (as ildasm), -size
 *
 * References: ECMA-335, "Common Language Infrastructure", 6th edition
 * (2012): Partition II the file, Partition III the instructions. *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
