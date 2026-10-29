(* The annotations that check what mini-ml makes of a hot path
 * (docs/plans/plan_ml_annotations.md): not hints, assertions, the
 * program refused when its code is not what they say. The parser
 * records what each marks, by the span of the expression; the pass
 * that decides it checks it (Lower for the tail calls and [@inline],
 * ssa's Zero_alloc for [@@zero_alloc], Unbox for [@@unboxed_float]).
 * OCaml 4.14 ignores [@@tailrec], [@@zero_alloc] and [@@unboxed_float],
 * attributes it does not know, reads [@inline] as its own (a request
 * to ocamlopt, not checked), and reads
 * [@tailcall] as its own, on the function of an application,
 * (f [@tailcall]) x (warning 51 if the call is not a tail call; on f
 * x [@tailcall] it is misplaced, warning 53): the same meaning.
 *
 *     let rec loop i acc =
 *       if i = 0 then acc else loop (i - 1) (acc + i) [@@tailrec]
 *
 *     let rec count n = if n = 0 then 0 else 1 + count (n - 1) [@@tailrec]
 *     (mini-ml: count, [@@tailrec]: its call of itself at line 3 is not
 *      in tail position)
 *
 * others:
 * Scala's @tailrec and Kotlin's tailrec are [@@tailrec]'s: checked,
 * an error otherwise; OCaml's [@tailcall] a warning; Clang's
 * [[clang::musttail]] a call made a tail call or an error. *)

(* the calls marked [@tailcall], OCaml's way, on the function applied:
 * (f [@tailcall]) x; each a tail call, a jump; by the application's
 * span (and the marked function's, which the parser carries to the
 * application, and parentheses to their own) *)
val tailcalls : (Ast.span, unit) Hashtbl.t

(* the functions marked [@@tailrec] (let rec f x = ... [@@tailrec]):
 * each call of f in its own body a tail call; by the span of the
 * function the binding gives *)
val tailrecs : (Ast.span, unit) Hashtbl.t

(* the functions marked [@@zero_alloc] (let f x = ... [@@zero_alloc],
 * Jane Street's OCaml's name and meaning): f's code, as -O3 makes it
 * (after inlining), allocates nothing; by the span of the function *)
val zero_allocs : (Ast.span, unit) Hashtbl.t

(* the functions marked [@inline], OCaml's way (let[@inline] f x =
 * ..., or [@@inline] after the binding): each inlined where it is
 * called with all its arguments, whatever its size (not -O3's bound,
 * Lower.inline_most); Lower refuses one recursive, or holding a
 * function, a handler or an assertion; by the span of the function.
 * old: one over the bound refused too *)
val inlines : (Ast.span, unit) Hashtbl.t

(* the floats marked [@@unboxed_float] (let x = e [@@unboxed_float], or
 * let r = ref e [@@unboxed_float]: its contents), a function's local:
 * a double in a register or a slot of its own, never a block, by
 * -O3's Unbox, which refuses it otherwise with what boxes it (passed,
 * stored, returned) or makes it a block. Not OCaml's [@@unboxed], a
 * type's, which ix's code uses (type reg = R of int [@@unboxed]); by
 * the span of the bound expression *)
val unboxed_floats : (Ast.span, unit) Hashtbl.t
