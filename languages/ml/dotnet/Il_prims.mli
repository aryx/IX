(* The primitives' calls, IL: an external's of OCaml's (%addint, a
 * comparison, an array's element, Obj.repr...), its code here; one of
 * C (sqrt_float, caml_flush), a call of the runtime unit's function of
 * its name (lib_core/dotnet/Runtime.ml), its arguments converted to the
 * function's parameters; one naming a .NET member (decision 7: dotnet:
 * ..., Il_externals), its call. The operands compiled by Il_exprs,
 * given as a record of its functions (the two are one recursion). *)

type compiler = {
  expr : Scope.expr -> unit;
  operands : Scope.expr list -> unit;
  values : Scope.expr list -> unit;
  drop : Scope.expr -> unit;
}

(* a call of the runtime unit's function, all its arguments given, it
 * not polymorphic; false (nothing emitted) otherwise *)
val runtime_call :
  Il_code.c -> Il_code.code -> compiler -> Scope.expr -> Il_functions.fn -> Scope.expr list -> bool

(* a value of the type where a call left none (a raise's method, a
 * unit's): never reached, the stack typed as the caller's *)
val default : Il_code.code -> Signature.t -> unit

(* a call of an external naming a .NET member: the external's string,
 * its ML type, its arguments *)
val dotnet : Il_code.c -> Il_code.code -> compiler -> Scope.expr -> string -> Scope.ty -> Scope.expr list -> unit

(* a primitive applied: its name, its arguments *)
val prim : Il_code.c -> Il_functions.env -> Il_code.code -> compiler -> Scope.expr -> string -> Scope.expr list -> unit
