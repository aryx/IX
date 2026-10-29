(* An assembly written: the reader's inverse (Image), for the compilers
 * to .NET (mini-tiger, mini-csc). A compiler names what it uses and
 * defines, in any order, and gets a token for each, to put in its
 * instructions; then gives each method its IL. The writer lays the
 * rows out, renumbers the tokens it had to, sizes the indexes, and
 * writes the PE around the metadata (ECMA-335, Partition II, 24-25).
 *
 *     let w = Writer.create "hello" in
 *     let console = Writer.type_ref w (Writer.assembly_ref w "System.Console") "System" "Console" in
 *     let wl = Writer.member_ref w console "WriteLine" { (static) void (string) } in
 *     let prog = Writer.type_def w "" "Hello" 0x100001 obj in
 *     let main = Writer.method_def w prog "Main" 0x16 { void () } in
 *     Writer.set_body w main [] [| Ldstr (Writer.user_string w "hi"); Call wl; Ret |] [];
 *     Writer.set_entry_point w main;
 *     Writer.write w      (* 2,048 bytes: Microsoft's dotnet runs it *)
 *
 * A field's and a method's row are known only at the end (a table
 * holds a type's fields together, and a compiler may add one to a
 * class it made earlier): their tokens are provisional until then, and
 * the instructions are renumbered as they are written. A method's
 * .maxstack is computed from its instructions (Il.stack_effect), each
 * branch's depth the same as where it comes from.
 *
 * What is written is what .NET needs, no more: one section (.text)
 * without the stub of machine code that Windows's loader once called
 * (.NET Core never runs it), no attributes, no names of parameters.
 * The file is written the same each time: its GUID is a digest of its
 * name, its date 0. *)

type t

(* an assembly to be written, of this name (its module name.dll) *)
val create : string -> t

(* tokens for what the assembly uses: another assembly (version 8.0.0.0,
 * Microsoft's key), one of its types, a member of a type, a type
 * built of others (a generic instance, an array as a class) *)
val assembly_ref : t -> string -> int
val type_ref : t -> int -> string -> string -> int
val member_ref : t -> int -> string -> Signature.meth -> int
val field_ref : t -> int -> string -> Signature.t -> int
val type_spec : t -> Signature.t -> int
val user_string : t -> string -> int

(* and for what it defines: a type (namespace, name, flags, the token
 * of what it extends; 0 for none), its fields and methods (their flags,
 * ECMA's II.23.1) *)
val type_def : t -> string -> string -> int -> int -> int
val field_def : t -> int -> string -> int -> Signature.t -> int
val method_def : t -> int -> string -> int -> Signature.meth -> int
(* a nested type's enclosing one *)
val nest : t -> int -> int -> unit

(* an exception clause, by instructions' indexes as the branches *)
type clause = {
  kind : int;              (* 0 catch, 2 finally *)
  try_start : int;
  try_end : int;
  handler_start : int;
  handler_end : int;
  catch : int;             (* the type caught, a token *)
}

(* a method's body: its locals' types, its instructions (a branch's
 * target the index of an instruction), its clauses *)
val set_body : t -> int -> Signature.t list -> Il.op array -> clause list -> unit
val set_entry_point : t -> int -> unit

(* the file *)
val write : t -> string

(* what Microsoft's dotnet needs beside a program to run it: its
 * runtimeconfig.json, .NET 8 *)
val runtime_config : string
