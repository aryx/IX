(* Passes on the simple back end's stack machine (Lower's code, before
 * Gen), each switchable (mini-ml -O, or -O<name> for one), chosen by
 * measuring where mini-ml's code spends what ocamlopt's does not
 * (plan_opti_twin.md). Each makes code of Lower's own instructions, so
 * the simple back end is the same with them or without:
 *
 * - tails: a function's tail call of itself, with all its arguments,
 *   is a jump into its body, the arguments stored into its parameters
 *   (ocamlopt's, for a self tail call): no prologue, no epilogue, no
 *   slots zeroed again, which the collector does not need since what
 *   they hold is a value still;
 * - eqs: x = k and x <> k, k an integer, compare the words (a tagged
 *   integer equals only itself, a block never one), with no test that
 *   x is an integer and no call of the runtime's compare. *)

val passes : (string * (Lower.func -> Lower.func)) list

(* the passes named, in the order of [passes], on each function *)
val run : string list -> Lower.unit_ -> Lower.unit_
