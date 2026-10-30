(* The metadata's shape: what the 45 tables of an assembly hold, column
 * by column, as data (ECMA-335, Partition II, chapter 22). The reader
 * (Image) walks it to find each row's bytes; the writer (Writer) to lay
 * them out; the listing (Listing) to name them.
 *
 * An assembly describes itself. Where a C program's object file has
 * code, a symbol table and relocations, an assembly has a small
 * relational database: a table of the types it defines (TypeDef), of
 * their fields (Field) and methods (MethodDef), of the types and
 * members of other assemblies it uses (TypeRef, MemberRef)... A row
 * names another by its number, which is its token's low 24 bits, the
 * table's number the high 8:
 *
 *     call 0x0A000001          MemberRef, row 1
 *       MemberRef #1   Class: TypeRef #3   Name: "WriteLine"   Signature: blob 0x1A
 *       TypeRef #3     Scope: AssemblyRef #2   Name: "Console"   Namespace: "System"
 *       AssemblyRef #2 Name: "System.Console"   Version: 8.0.0.0
 *
 * So `System.Console::WriteLine(string)` is found by its name when the
 * call is first run: no header file, no link step.
 *
 * A column is a number (2 or 4 bytes), an index into one of the heaps
 * (the strings, the blobs of signatures, the GUIDs: 2 bytes or 4, by
 * the heap's size), an index of a row of one table (2 bytes or 4, by
 * that table's rows), or a coded index: a row of one of several tables,
 * the table in the low bits. So a row's size is known only once every
 * table's count is: the reader reads the counts first.
 *
 *     TypeDefOrRef: 2 bits   00 TypeDef   01 TypeRef   10 TypeSpec
 *     0x0D = 3 << 2 | 01     TypeRef, row 3
 *
 * Of the 45 tables, the survey's ten programs fill 19
 * (survey/survey.txt); the others still need their shape, since a
 * table's place in the file is after all those before it.
 *
 * others:
 * The JVM's class file is the same idea at a smaller scale: one class a
 * file, its constant pool a list of entries naming each other by index.
 * A .NET assembly is a whole program's (or library's) classes in one
 * database, and the tables are sorted and indexed for a loader to
 * search: the parent of a method is found by the MethodList ranges of
 * TypeDef, not stored in the method.
 *
 * References: ECMA-335, 6th edition (2012), Partition II, 22 (the
 * tables), 24.2.6 (the #~ stream and the sizes of indexes). *)

(* the kind of a column *)
type column =
  | U8          (* stored as 2 bytes: Constant's Type and its padding *)
  | U16
  | U32
  | String      (* an index into #Strings *)
  | Guid        (* into #GUID *)
  | Blob        (* into #Blob *)
  | Table of int            (* a row of that table *)
  | Coded of coded          (* a row of one of several *)

(* a coded index: its name, the bits of the tag, the tables by tag (-1:
 * a tag no table has, CustomAttributeType's) *)
and coded = { cname : string; bits : int; tables : int array }

val type_def_or_ref : coded
val has_constant : coded
val has_custom_attribute : coded
val has_field_marshal : coded
val has_decl_security : coded
val member_ref_parent : coded
val has_semantics : coded
val method_def_or_ref : coded
val member_forwarded : coded
val implementation : coded
val custom_attribute_type : coded
val resolution_scope : coded
val type_or_method_def : coded

(* the tables, by number: their names and their columns' (name, kind) *)
val count : int
val name : int -> string
val columns : int -> (string * column) array

(* the tables' numbers, for the reader's code *)
val t_module : int
val t_type_ref : int
val t_type_def : int
val t_field : int
val t_method_def : int
val t_param : int
val t_interface_impl : int
val t_member_ref : int
val t_constant : int
val t_custom_attribute : int
val t_class_layout : int
val t_stand_alone_sig : int
val t_property_map : int
val t_property : int
val t_method_semantics : int
val t_method_impl : int
val t_module_ref : int
val t_type_spec : int
val t_field_rva : int
val t_assembly : int
val t_assembly_ref : int
val t_nested_class : int
val t_generic_param : int
val t_method_spec : int
val t_generic_param_constraint : int

(* a column's index in its table's, by its name: Not_found if none *)
val col : int -> string -> int

(* a token: the table in its high 8 bits, the row (from 1) in its low
 * 24; 0x70 is #US's, the user's strings (ldstr) *)
val token : int -> int -> int
val token_table : int -> int
val token_row : int -> int
val t_user_string : int
