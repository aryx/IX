(* [@@zero_alloc] checked (Annotations.mli, plan_ml_annotations.md's
 * step 2): a function so marked allocates nothing, read on its SSA
 * form once every optimization is done (Unbox, Untag, Licm, Cse), so
 * after inlining and with its floats unboxed: what runs is what is
 * checked.
 *
 *     let dot (a : float array) b =
 *       let s = ref 0.0 in
 *       for i = 0 to Array.length a - 1 do s := !s +. a.(i) *. b.(i) done;
 *       !s [@@zero_alloc]
 *     (mini-ml -O3: dot [@@zero_alloc]: it boxes a float, its result)
 *
 * Refused: a block made (a tuple, a record, a constructor's, a
 * closure), a float boxed, an int32's block, a polymorphic comparison
 * (compare, in C: give the type), a call of a function not itself
 * [@@zero_alloc] in this unit (another unit's, an unknown closure, a
 * partial application), a call of C but the runtime's few that make
 * nothing (a string's length and bytes, = on strings, a float array's
 * length). A raise is allowed, and what is made on its way, in the
 * block of code that ends in it (the exception's block, which mini-ml
 * makes at each raise, Not_found's too): the error's path, not the
 * hot one, as Jane Street's check leaves it out. So is a handler.
 *
 * Only ssa's code is checked (-O3, -ssa): without it, the annotation
 * is not looked at, as OCaml 4.14 does not, since nothing is promised
 * of simple's code (its floats are blocks). The error names the
 * function's line, not the instruction's: SSA's values have none.
 *
 * others:
 * Jane Street's OCaml (flambda-backend) checks [@zero_alloc] the same
 * way, on the code after inlining, with "assume" and "opt" variants
 * and the paths that end in a raise left out unless "strict";
 * Java's real-time (RTSJ) NoHeapRealtimeThread and Rust's no_std
 * without alloc are the same promise for a whole thread or crate. *)

(* the function refused (Failure, with its line) if it is marked and
 * allocates *)
val check : Ssa.func -> unit
