(* A float not boxed inside a function (plan_ml_floats.md, decision 2):
 * an SSA value that is a double in a floating-point register, beside
 * the words. mini-ml's float is a block of its own (Double_tag), and
 * x *. y +. z made two, the first read once by the second then left to
 * the collector; here it is none, and one if the sum leaves as a word.
 *
 * The doubles: what Float2, FloatOfInt, FloatIndex and FloatRound make
 * (a sum, a product, a float of an int, a Float.Array's, a floor...), and a phi with a double among its operands (a
 * loop's float, in a ref that Opti's refs made a slot). Each such Prim
 * is a Dprim, its float operands doubles: a double as it is, a word
 * unboxed where it is read (Unbox, its block's two words loaded); and
 * FloatCmp and IntOfFloat too when an operand is a double. Wherever
 * else a double is read (stored, passed, returned, a field of a block,
 * Float1's operand), it is boxed once, after its definition (Box).
 *
 *     let dot (x : float) y z = (x *. 0.8) +. (y *. 0.1) +. (z *. 0.6)
 *
 *     mini-ml -dssa -boxed-floats:      mini-ml -dssa:
 *     v4 = block d0<>                   v4 = block d0<>
 *     v5 = caml_mulfloat v3 v4          v13 = unbox v3
 *     ...                               v14 = unbox v4
 *     v9 = caml_mulfloat v1 v8          v5 = caml_mulfloat(d) v13 v14
 *     v10 = caml_addfloat v9 v7         ...
 *     v11 = caml_addfloat v10 v5        v11 = caml_addfloat(d) v10 v5
 *     ret v11                           v12 = box v11
 *                                       ret v12
 *
 * five blocks before, one after. A double is not a value the collector
 * reads: Alloc keeps it in a register across an allocation, and only a
 * call (of ML or of C, or compare's) makes it go to memory, a slot of
 * the machine stack, which the collector does not scan. Not in a
 * function with a handler (its values in memory at each raise: Alloc),
 * which stays as it was.
 *
 * The same bytes: a double in a register is the double that would
 * have been in a block, and no multiplication and addition are fused
 * (FMA: ocamlopt's arm64 does; here never).
 *
 * cs-history:
 * Unboxing floats is as old as compiling ML to machine code: Xavier
 * Leroy's "Unboxed objects and polymorphic typing" (POPL 1992) gave
 * Gallium's compilers floats out of their boxes where the types say
 * so, and ocamlopt's Cmmgen unboxes a let-bound float whose uses are
 * float operations, as here a value whose uses are. SML/NJ and MLton
 * went further, the whole program's representations chosen at once.
 *
 * References: Xavier Leroy, "Unboxed objects and polymorphic typing"
 * (POPL 1992); OCaml's asmcomp/cmmgen.ml (unbox_float);
 * docs/plans/plan_ml_floats.md. *)

(* on, unless mini-ml -boxed-floats *)
val on : bool ref

(* the function's doubles found and made so (fn.doubles), its code
 * rewritten in place *)
val func : Ssa.func -> Ssa.func

(* [@@unboxed_float] (Annotations.mli): each marked variable of the
 * function never boxed, a double around its loops, or the program
 * refused (Failure, its line) with what boxes it or makes it a block *)
val check : Ssa.func -> unit
