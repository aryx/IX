(* Constant folding, on Scope's tree before Lower:
 * - a toplevel value whose definition is a constant (an integer, a
 *   character, or a constructor without arguments, such as a bool or
 *   an enumeration's constructor) is replaced by that constant where it
 *   is used;
 * - the integer primitives applied to constants are computed, as the
 *   target's arithmetic would compute them (31 bits on arm, 63 on
 *   arm64);
 * - a comparison of constants becomes a bool;
 * - an if on a constant becomes its branch.
 * So
 *
 *   let wide = 1 lsl 20 > 1000          wide: true
 *   let mask w = if wide then w land 0xff else w
 *
 * makes mask's body w land 0xff, which is small enough to be inlined
 * (Lower.inline_most), with no test left in the copies. A unit's
 * constants go in its summary (Summary.t's constants), so that the
 * units compiled after it fold them too: the units of its directory,
 * and a unit of another directory that finds it by an -I (as with
 * lib_core's Sys.word_size, which is %word_size).
 *
 * others:
 * ocamlopt's Closure (since 1996) gives each value an approximation,
 * Value_const being one of them, which is kept in the unit's .cmx. A
 * constant global of another unit is replaced by its constant there,
 * a primitive applied to constants is computed, and an if on a
 * constant becomes its branch, both before and after inlining.
 * flambda does the same, and more. Here only the toplevel's values are
 * followed, not those of a local let (Lower handles a local constant
 * itself, as a known value that needs no slot). *)

(* on with -O and -O3 (mkconfig's MLOPT); off with -O0 and -no-fold *)
val on : bool ref

(* the size of the target's int, in bits: 31 (arm) or 63 (arm64). It
 * gives the value of %int_size, and %word_size is one more, whether
 * they are folded or not (Lower reads it too). *)
val bits : int ref

(* starts a new unit, with no constant known *)
val reset : unit -> unit

(* adds the constants of a summary that was read (Summary.t's
 * constants) *)
val import : (string * Scope.expr) list -> unit

(* the items folded, in their order: a value that is folded to a
 * constant is a constant for the items after it *)
val items : Scope.item list -> Scope.item list

(* the unit's own constants, by symbol, for its summary *)
val exports : unit -> (string * Scope.expr) list
