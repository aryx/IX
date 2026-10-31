(* ML's types as .NET's (Lower_il.mli's table): the primitives, and the
 * unit's records, variants and exceptions as classes, made when a type
 * is first met, nested in the unit's class (F#'s modules), with the
 * structural Equals and GetHashCode that make OCaml's = .NET's. *)

(* a type's declaration (its constructor's) *)
val decl : Scope.ty -> Scope.tdecl

(* an ML type's .NET type, its class made if needed; unit's Void.
 * Refused: what a later stage has (a function, a tuple, a type of
 * parameters, a polymorphic value) *)
val cts : Il_code.c -> int -> Scope.ty -> Signature.t

(* a record type's field, its constructor (the fields in order) *)
val field : Il_code.c -> int -> Scope.tdecl -> string -> int
val record_ctor : Il_code.c -> int -> Scope.tdecl -> int

(* a variant's constructor: its class, its constructor, its i-th field *)
val case : Il_code.c -> int -> Scope.cons -> int * int * (int -> int)

(* an exception by its symbol, of these arguments: the same *)
val exn : Il_code.c -> int -> string -> Scope.ty list -> int * int * (int -> int)

(* an expression's type, as Typing kept it; its .NET type (a raise's:
 * nothing, whatever its type) *)
val type_of : Scope.expr -> Scope.ty
val is_raise : Scope.expr -> bool
val cts_of : Il_code.c -> Scope.expr -> Signature.t
