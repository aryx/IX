(* The pass that resolves the names. It turns the parser's tree (Ast)
 * into the scoped one (Scope), a unit at a time; Scope's header says
 * what a name becomes. Another unit's names come from its .mli, or its .ml,
 * through the loader.
 *
 * cs-history:
 * A unit that is a file in two parts, the interface that others
 * compile against and the implementation that they never read, comes
 * from Modula-2 (Niklaus Wirth, about 1980; Mesa at Xerox had it
 * before). Caml Light took it as its module system: x.mli and x.ml.
 * C's header has the same intent with nothing to check it; it is a
 * text pasted in. The modules of Standard ML (David MacQueen, 1984),
 * which are signatures, structures and functors inside the language,
 * came to Caml with Caml Special Light (1995) and were laid over the
 * files. The dialect here has the files, and structures used as name
 * spaces.
 *
 * others:
 * What is read. Modula-2 and OCaml compile an interface once, to a
 * symbol file or a .cmi, and a unit that names it loads that. Here
 * the .mli's text is parsed again by each unit that names it, as a
 * C compiler does with a header. This saves a file format, and a .mli
 * is short. It does not scale to C++'s headers: Go's designers say
 * that the headers read again by every file made their builds slow,
 * and a Go package is compiled against the compiled form of what it
 * imports (Rob Pike, "Go at Google", 2012). *)
open Scope

(* the capabilities that an object type names, with its aliases and
 * groups expanded one level: < Cap.stdout; caps; .. >. Typing treats
 * all objects as one type. *)
val capabilities : ty -> string list

(* A poor man's type-directed fields: the field of that name in a
 * record type. It is for Typing, which knows r's type in r.l when
 * Scope does not. A field that Scope found in no type in scope has no
 * position yet (pos < 0). *)
val type_field : tdecl -> string -> label option

(* a type's constructors, and a record type's fields, by their path,
 * if it has them (for mini-ml -g's descriptions: debug/Acid_ml) *)
val type_conses : tdecl -> (string * cons) list option
val type_fields : tdecl -> (string * label) list option

exception Error of int * string

(* a unit's implementation, where M is the module's name (its file's
 * name, capitalized) *)
(* mlpp: implicit says whether the classes' dictionaries are left out
 * of the calls (in the source) or written (in mlpp's output) *)
val implementation : implicit:bool -> loader -> string -> Ast.structure -> item list

(* mlpp: the classes (plan_ml_bootstrap.md, "Type classes").
 * - using_d is the type of [%using: t], which is t using;
 * - is_class says whether a type is a class;
 * - has_classes says whether the unit and those it named have any;
 * - instance gives a class's instance at a type (the type's path, or
 *   "*2" for a pair): its name as the unit writes it, and its type as
 *   written. *)
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
 * (given "Int32" or "Int64"), which int32 and int64 name *)
val boxed_int_type : string -> ty

val format_d : tdecl
val format4_d : tdecl

(* a type that the current unit declares, by its path; and all of
 * them *)
val own_type : string -> tdecl option
val own_types_all : unit -> tdecl list

(* a global's symbol, M.x *)
val symbol : string list -> string -> string

(* the unit's exceptions, in order, with their symbols and their
 * arguments' types (mini-ml -g describes them) *)
val exceptions : unit -> (string * ty list) list

(* the unit's own interface, if it has one: the types of its values *)
val interface : unit -> (string * ty) list option

(* the other units the last implementation named (-M) *)
val units_named : unit -> string list
