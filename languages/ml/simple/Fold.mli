(* Constant folding, on Scope's tree before Lower: a toplevel value
 * whose definition is a constant (an integer, a character, a
 * constructor without arguments: a bool, an enumeration's) is that
 * constant where it is used; the integer primitives of constants are
 * computed, as the target's arithmetic would (31 bits on arm, 63 on
 * arm64); a comparison of constants is a bool; an if on a constant is
 * its branch. So
 *
 *   let wide = 1 lsl 20 > 1000          wide: true
 *   let mask w = if wide then w land 0xff else w
 *
 * makes mask's body w land 0xff, small enough to be inlined
 * (Lower.inline_most), with no test left in the copies. A unit's
 * constants go in its summary (Summary.t's constants), so that the
 * units after it in the directory fold them too.
 *
 * others:
 * ocamlopt's Closure (since 1996) gives each value an approximation,
 * Value_const among them, kept in the unit's .cmx: a constant global
 * of another unit is its constant there, a primitive of constants is
 * computed and an if on one is its branch, before and after inlining.
 * flambda does the same, and more. Here only the toplevel's values are
 * followed, not a local let's (a local constant is Lower's own: a
 * known value, no slot). *)

(* on: -O and -O3 (mkconfig's MLOPT); off: -O0, -no-fold *)
val on : bool ref

(* the target's int, in bits: 31 (arm) or 63 (arm64) *)
val bits : int ref

(* a new unit: no constant known *)
val reset : unit -> unit

(* the constants of a summary read (Summary.t's constants) *)
val import : (string * Scope.expr) list -> unit

(* the items folded, in their order: a value folded is a constant for
 * the ones after it *)
val items : Scope.item list -> Scope.item list

(* the unit's own constants, by symbol, for its summary *)
val exports : unit -> (string * Scope.expr) list
