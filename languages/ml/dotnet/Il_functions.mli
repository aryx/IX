(* The unit's functions, as Lower_il compiles them: each a static
 * method of the unit's class, its arguments from its nest of
 * Efunctions (the last matched when it has cases); the variables a
 * lambda names (those of its method it captures); and the classes that
 * make a function given fewer arguments than it takes a Func, one a
 * number of arguments given (Lower_il.mli's table). *)

(* a function of the unit: its method, its arguments' variables (None:
 * unit's, or _) and .NET types, its arguments' and result's ML types,
 * the cases on its last argument if it is matched, its body *)
type fn = {
  tok : int;
  fname : string;
  params : (Scope.var option * Signature.t) list;
  ptys : Scope.ty list;
  rty : Scope.ty;
  cases : Scope.case list option;
  body : Scope.expr;
  gvars : string list;                  (* its type's variables: its method's generic parameters *)
}

(* the unit's closures' classes, numbered (reset by each unit) *)
val closures : int ref

(* the unit's functions by variable (inside a let rec) and by symbol
 * (from the toplevel's later items); its values' static fields *)
type env = { by_var : (int, fn) Hashtbl.t; by_sym : (string, fn) Hashtbl.t; fields : (string, int * Signature.t) Hashtbl.t }

(* a pattern that is no test: Some (its variable, None for _ or ()) *)
val simple : Scope.pattern -> Scope.var option option

(* a function's arguments, as its Efunction's nest: their variables and
 * types; the last's cases if it is matched; the body *)
val params : Scope.expr -> (Scope.var option * Scope.ty) list * Scope.case list option * Scope.expr

(* a type's variables, each once, in order *)
val tvars_of : Scope.ty -> string list

(* the generic type's variables, as an instance gives them *)
val instantiation : Scope.ty -> Scope.ty -> (string * Scope.ty) list

(* the expressions naming a variable (its uses), in an expression *)
val uses : int -> Scope.expr -> Scope.expr list

(* the variables an expression names, each once, in order *)
val named : Scope.expr -> int list

(* a function's type after its first i arguments *)
val rest : fn -> int -> Scope.ty

(* the class of a function given i arguments (generic in its type
 * variables): the class, its Invoke (the next argument's), its
 * signature; made once (levels, reset by each assembly) *)
val levels : (string, Il_types.tclass * int * Signature.meth) Hashtbl.t
val level : Il_code.c -> fn -> int -> Il_types.tclass * int * Signature.meth

val is_function : Scope.expr -> bool

(* a toplevel variable's global *)
val global_of : (Scope.var * Scope.global) list -> Scope.var -> Scope.global option

(* a function's argument's type, from its first case's pattern *)
val pattern_type : Scope.pattern -> Scope.ty
