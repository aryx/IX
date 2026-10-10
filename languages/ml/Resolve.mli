(* The pass that resolves the names: the parser's tree (Ast) to the
 * scoped one (Scope), a unit at a time; Scope's header says what a
 * name becomes. Another unit's names come from its .mli, or its .ml,
 * through the loader.
 *
 * cs-history:
 * A unit that is a file in two parts, the interface others compile
 * against and the implementation they never read, is Modula-2's
 * (Niklaus Wirth, about 1980; Mesa at Xerox before it), and Caml
 * Light took it as its module system: x.mli and x.ml. C's header is
 * the same intent with nothing to check it, a text pasted in. The
 * modules of Standard ML (David MacQueen, 1984), signatures,
 * structures and functors inside the language, came to Caml with
 * Caml Special Light (1995) and were laid over the files; the
 * dialect here is the files, and structures as name spaces.
 *
 * others:
 * What is read. Modula-2 and OCaml compile an interface once, to a
 * symbol file or a .cmi, and a unit that names it loads that. Here
 * the .mli's text is parsed again by each unit that names it, as a
 * C compiler does a header: one format less, and a .mli is short.
 * It does not scale to C++'s headers: Go's designers name the
 * headers read again by every file as what made their builds slow,
 * and a Go package is compiled against the compiled form of what it
 * imports (Rob Pike, "Go at Google", 2012). *)
open Scope

(* Type-directed fields, the poor man's: the field named so of a record
 * type, for Typing, which knows r's type in r.l when Scope doesn't; a
 * field Scope found in no type in scope has no position yet (pos < 0) *)
val type_field : tdecl -> string -> label option

exception Error of int * string

(* a unit's implementation, M the module's name (its file's,
 * capitalized) *)
(* mlpp: implicit, whether the classes' dictionaries are left out of the
 * calls (the source) or written (mlpp's output) *)
val implementation : implicit:bool -> loader -> string -> Ast.structure -> item list

(* mlpp: the classes (plan_ml_bootstrap.md, "Type classes"): [%using: t]'s
 * type, t using; whether a type is a class, whether the unit and those
 * it named have any; a class's instance at a type (its path, "*2" for a
 * pair): its name as the unit writes it, its type as written *)
val using_d : tdecl
val implicit : bool ref
val is_class : tdecl -> bool
val has_classes : unit -> bool
val instance : tdecl -> string -> (string * ty) option

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
