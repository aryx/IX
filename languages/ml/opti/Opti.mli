(* Passes on the simple back end's stack machine (Lower's code, before
 * Gen), each switchable (mini-ml -O, or -O<name> for one), chosen by
 * measuring where mini-ml's code spends what ocamlopt's does not
 * (variants/opti.md). Each makes code of Lower's own instructions, so
 * the simple back end is the same with them or without:
 *
 * - tails: a function's tail call of itself, with all its arguments,
 *   is a jump into its body, the arguments stored into its parameters
 *   (ocamlopt's, for a self tail call): no prologue, no epilogue, no
 *   slots zeroed again, which the collector does not need since what
 *   they hold is a value still;
 * - eqs: x = k and x <> k, k an integer, compare the words (a tagged
 *   integer equals only itself, a block never one), with no test that
 *   x is an integer and no call of the runtime's compare.
 *
 * Both on Ir's example, mini-ml -O -dir:
 *
 *     let rec loop i acc = if i = 0 then acc else loop (i - 1) (acc + i)
 *
 *     Label 11                             tails: the body's start
 *     Int 0; Get 1; Op (Cmp Eq); Jz 3      eqs: it was Poly Eq
 *     Get 2; Ret
 *     Label 3
 *     ...; Set 3; ...; Set 4; ...; Set 5   the arguments, as before
 *     Get 5; Get 4; Get 3                  tails: all read, then all
 *     Set 2; Set 1; Set 0                  written, the last first: a
 *     Jmp 11                               parameter may be an argument
 *
 * Without tails the call is already a jump: Gen writes a tail call
 * as the function's epilogue and a B, so that a loop written as a
 * recursion does not grow the stack, which ML promises. What tails
 * saves is the epilogue and the prologue between two turns.
 *
 * cs-history:
 * That a call in tail position is a jump that passes arguments, and
 * a loop only a special case of it, is Guy Steele's (1977), against
 * the belief of the time that procedure calls were expensive and
 * goto the fast way. Scheme made it a rule of the language: an
 * implementation must run such a loop in constant space. C compilers
 * do it when they can prove nothing of the frame is still needed,
 * and promise nothing.
 *
 * References: Guy Steele, "Debunking the 'expensive procedure call'
 * myth, or, procedure call implementations considered harmful, or,
 * LAMBDA: the ultimate GOTO" (ACM National Conference, 1977);
 * docs/plans/variants/opti.md, the measurements. *)

val passes : (string * (Ir.func -> Ir.func)) list

(* the passes named, in the order of [passes], on each function *)
val run : string list -> Ir.unit_ -> Ir.unit_
