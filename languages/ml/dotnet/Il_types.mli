(* ML's types as .NET's (Lower_il.mli's table): the primitives, and the
 * unit's records, variants and exceptions as classes, made when a type
 * is first met, nested in the unit's class (F#'s modules), with the
 * structural Equals and GetHashCode that make OCaml's = .NET's. A type
 * of parameters a generic class, tree`1 (its constructors' classes of
 * the same parameters, their parent tree`1<!0>); a use of it at types
 * its instance, int tree a tree`1<long>, its fields and constructor
 * MemberRefs of that, as C# makes them. Pervasives' ref and option,
 * until units are several (stage 1e), Stdlib's in each assembly. *)

(* the unit's classes forgotten, before another unit *)
val reset : unit -> unit

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

(* the assembly's helper Stdlib.Ml::compare(object, object): OCaml's
 * order of two boxed values (a string's, an int's, a float's, a
 * char's, a boolean's) *)
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

(* a variant's constructor at the variant's type: its class's token,
 * its constructor, its i-th field, its arguments' types there *)
val case : Il_code.c -> int -> Scope.cons -> Scope.ty -> int * int * (int -> int) * Scope.ty list

(* an exception by its symbol, of these arguments: the same *)
val exn : Il_code.c -> int -> string -> Scope.ty list -> int * int * (int -> int)

(* an expression's type, as Typing kept it; its .NET type (a raise's:
 * nothing, whatever its type) *)
val type_of : Scope.expr -> Scope.ty
val is_raise : Scope.expr -> bool
val cts_of : Il_code.c -> Scope.expr -> Signature.t
