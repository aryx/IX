(* DWARF's descriptions read back (.debug_info, with .debug_abbrev,
 * versions 2 to 5): what gcc's and clang's programs say of their
 * types and variables, the entries mini-acid makes acid's declarations
 * of (plan_debugger.md, stage 8a: Acid_dwarf).
 *
 * The section is a tree of entries for each compilation unit, each
 * entry a tag (a structure, a member, a variable, a pointer type...)
 * and attributes (its name, its type, its size, its offset, its
 * location...):
 *
 *     compile_unit "target.c"
 *       structure_type "Point"  byte_size 8
 *         member "x"  type -> int  data_member_location 0
 *         member "y"  type -> int  data_member_location 4
 *       typedef "Point"  type -> the structure
 *       base_type "int"  byte_size 4  encoding signed
 *       variable "n1"  type -> Node  location DW_OP_addr 0x20018
 *
 * An entry says only its abbreviation's number: the abbreviation, in
 * .debug_abbrev, says its tag and which attributes follow in which
 * forms (a 4-byte offset in .debug_str, an unsigned LEB128, a
 * reference to another entry...). A type is a reference: the graph
 * of types is the entries'.
 *
 * Plan 9's 5c writes acid's text instead (-a): a debugger's language
 * as the format, the work of DWARF's reader left to the compiler.
 *
 * References: the DWARF 5 standard (2017), sections 2, 5 and 7. *)

type value =
  | Int of int
  | Str of string
  | Ref of int          (* another entry, by its offset in .debug_info *)
  | Block of string     (* an expression (a location), bytes *)
  | Flag

type die = { off : int; tag : int; attrs : (int * value) list; children : die list }

(* the compilation units of an ELF (file its bytes), their trees *)
val read : string -> Elf_file.t -> die list

(* an attribute (DW_AT_...) of an entry *)
val attr : die -> int -> value option
val name : die -> string option
val int : die -> int -> int option
val ref_ : die -> int -> int option

(* the entries by their offsets, for the references *)
val index : die list -> (int, die) Hashtbl.t
