(* ML's types as .NET's (Lower_il.mli's table): the primitives, and the
 * unit's records, variants and exceptions as classes, made when a type
 * is first met, nested in the unit's class (F#'s modules), with the
 * structural Equals and GetHashCode that make OCaml's = .NET's. A type
 * of parameters a generic class, tree`1 (its constructors' classes of
 * the same parameters, their parent tree`1<!0>); a use of it at types
 * its instance, int tree a tree`1<long>, its fields and constructor
 * MemberRefs of that, as C# makes them. Pervasives' ref and option,
 * until units are several (stage 1e), Stdlib's in each assembly. *)

(* a class made for a type or by the lowering: its TypeDef, its generic
 * parameters' number, its fields (declared in its own parameters) *)
type tclass = {
  tok : int;
  arity : int;
  mutable fields : (string * Signature.t) list;
  mutable ftoks : int list;
  mutable ctor : int;
}

(* such a class at type arguments; its token (isinst, a parent); its
 * i-th field, its constructor, a method of it, at those *)
val at : tclass -> Signature.t list -> Signature.t
val type_tok : Il_code.c -> tclass -> Signature.t list -> int
val field_tok : Il_code.c -> tclass -> Signature.t list -> int -> int
val ctor_tok : Il_code.c -> tclass -> Signature.t list -> int
val method_tok : Il_code.c -> tclass -> Signature.t list -> string -> int -> Signature.meth -> int

(* a class of the lowering's own (a closure's, a partial
 * application's): nested in the unit's, generic in so many parameters,
 * its fields set by its constructor *)
val helper_class : Il_code.c -> string -> int -> (string * Signature.t) list -> tclass

(* the unit's classes forgotten, before another unit *)
val reset : unit -> unit

(* the types of the expressions the back end makes itself, by their
 * spans (negative: no source's) *)
(* a type's variables (params) replaced by args; its abbreviations
 * expanded at its top *)
val subst : string list -> Scope.ty list -> Scope.ty -> Scope.ty
val unabbrev : Scope.ty -> Scope.ty

val synthetic : (Ast.span, Scope.ty) Hashtbl.t

(* and of the variables they bind; a variable's type, those first, then
 * Typing's *)
val synthetic_vars : (int, Scope.ty) Hashtbl.t
val var_type : int -> Scope.ty option

(* the types the assembly's units declare, by path (Lower_il records
 * each unit's): what is abstract in a .mli is its .ml's there *)
val implementations : (string, Scope.tdecl) Hashtbl.t

(* a type's declaration (its constructor's) *)
val decl : Scope.ty -> Scope.tdecl

(* an ML type's .NET type, its class made if needed; unit's Void.
 * Refused: what a later stage has (a tuple, a type of parameters). A
 * type variable: the polymorphic function's parameter (Il_code.c's
 * tvars), else an object *)
val cts : Il_code.c -> int -> Scope.ty -> Signature.t

(* a type as a Func's argument or result (unit an object, null); a
 * function's type, Func<A, B> *)
val arg_type : Il_code.c -> int -> Scope.ty -> Signature.t
val func : Il_code.c -> int -> Scope.ty -> Scope.ty -> Signature.t

(* a .NET type's token, as newarr, box and ldelem.any take it *)
val type_token : Il_code.c -> Signature.t -> int

(* the assembly's helper Stdlib.Ml::compare(object, object): OCaml's
 * order of two boxed values (a string's, an int's, a float's, a
 * char's, a boolean's) *)
(* OCaml's Hashtbl.hash, the assembly's Stdlib.Ml::hash(object): the
 * same on every runtime (a string's by its chars, not .NET's
 * GetHashCode, which Microsoft's varies by process) *)
val ml_hash : Il_code.c -> int
val ml_compare : Il_code.c -> int

(* a Func type's Invoke, its constructor (an object, a method's
 * address: ldftn) *)
val invoke : Il_code.c -> Signature.t -> int
val func_ctor : Il_code.c -> Signature.t -> int

(* a record's field at the record's type (a FieldDef, or a MemberRef
 * of the generic class's instance), by its name, its first; its
 * constructor there (the fields in order); a field's type there *)
val field : Il_code.c -> int -> Scope.ty -> string -> int
val field0 : Il_code.c -> int -> Scope.ty -> int
val record_ctor : Il_code.c -> int -> Scope.ty -> int
val label_type : Scope.label -> Scope.ty -> Scope.ty

(* a tuple's i-th field at its type (Stdlib.tuple`n's Item), its
 * constructor there *)
val tuple_field : Il_code.c -> int -> Scope.ty -> int -> int
val tuple_ctor : Il_code.c -> int -> Scope.ty -> int

(* a variant's constructor at the variant's type: its class's token,
 * its constructor, its i-th field, its arguments' types there *)
(* a constant constructor's one value (its class's static Instance: ==
 * holds of two, as of OCaml's), at a type *)
val constant : Il_code.c -> int -> Scope.cons -> Scope.ty -> int
val case : Il_code.c -> int -> Scope.cons -> Scope.ty -> int * int * (int -> int) * Scope.ty list

(* an exception by its symbol, of these arguments: the same *)
val exn : Il_code.c -> int -> string -> Scope.ty list -> int * int * (int -> int)

(* the calls of Pervasives' functions mapped to .NET's library (print_*,
 * ^, string_of_int, failwith, invalid_arg): their IL after the
 * arguments, when Pervasives itself is not compiled with the program *)
val builtin : Il_code.c -> string -> Il.op list option

(* an expression's type, as Typing kept it; its .NET type (a raise's:
 * nothing, whatever its type) *)
val type_of : Scope.expr -> Scope.ty
val is_raise : Scope.expr -> bool
val cts_of : Il_code.c -> Scope.expr -> Signature.t
