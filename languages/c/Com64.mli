(* 64-bit arithmetic done as calls to libc, on a machine that cannot do
 * it itself (com64.c). On arm, 5c treats a vlong as a structure, and
 * its operators, its conversions and its tests become calls (_addv,
 * _sl2v, _testv...). This is a convention of the machine, not part of
 * 5c's code, so both back ends need it: compat calls it from its xcom,
 * and simple from its hook. *)

(* the complexity given to a call when the Sethi-Ullman order is
 * computed *)
val fnx : int

(* n rewritten as a call to libc, when it is an operation on vlongs
 * (on arm, where the machine's machcap does nothing itself); None when
 * n stays as it is *)
val com64 : Tree.expr -> Tree.expr option

(* a vlong tested as a condition, by a call to _testv *)
val bool64 : Tree.expr -> Tree.expr
