(* The pass that resolves the names: the parser's tree (Ast) to the
 * scoped one (Scope), a unit at a time; Scope's header says what a
 * name becomes. Another unit's names come from its .mli, or its .ml,
 * through the loader. *)
open Scope

(* Type-directed fields, the poor man's: the field named so of a record
 * type, for Typing, which knows r's type in r.l when Scope doesn't; a
 * field Scope found in no type in scope has no position yet (pos < 0) *)
val type_field : tdecl -> string -> label option

exception Error of int * string

(* a unit's implementation, M the module's name (its file's,
 * capitalized) *)
val implementation : loader -> string -> Ast.structure -> item list

(* the predefined types *)
val int_t : ty
val char_t : ty
val string_t : ty
val float_t : ty
val bool_t : ty
val unit_t : ty
val exn_t : ty
val array_d : tdecl
val list_d : tdecl
(* the type of a literal 3l or 3L: the stdlib's Int32.t or Int64.t
 * ("Int32", "Int64"), which int32 and int64 name *)
val boxed_int_type : string -> ty

val format_d : tdecl
val format4_d : tdecl

(* a type the current unit declares, by its path *)
val own_type : string -> tdecl option

(* a global's symbol, M.x *)
val symbol : string list -> string -> string

(* the unit's own interface, if it has one: its values' types *)
val interface : unit -> (string * ty) list option

(* the other units the last implementation named (-M) *)
val units_named : unit -> string list
