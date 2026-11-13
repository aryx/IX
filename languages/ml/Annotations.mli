(* The annotations that check what mini-ml makes of a hot path
 * (docs/plans/done/plan_ml_annotations.md). They are not hints but
 * assertions: the program is refused when its code is not what they
 * say. The parser records what each one marks, by the span of the
 * expression, and the pass that decides the matter checks it: Lower
 * for the tail calls and [@inline], ssa's Zero_alloc for
 * [@@zero_alloc], and Unbox for [@@unboxed_float].
 * OCaml 4.14 ignores [@@tailrec], [@@zero_alloc] and [@@unboxed_float],
 * which are attributes it does not know. It reads [@inline] as its own
 * (a request to ocamlopt, which nothing checks). It also reads
 * [@tailcall] as its own, with the same meaning, on the function of an
 * application: (f [@tailcall]) x. It gives warning 51 if the call is
 * not a tail call, and warning 53 for f x [@tailcall], where the
 * attribute is misplaced. One annotation is not an assertion but
 * something the analyses read: an external's [@@raise E] (see raises,
 * at the end).
 *
 *     let rec loop i acc =
 *       if i = 0 then acc else loop (i - 1) (acc + i) [@@tailrec]
 *
 *     let rec count n = if n = 0 then 0 else 1 + count (n - 1) [@@tailrec]
 *     (mini-ml: count, [@@tailrec]: its call of itself at line 3 is not
 *      in tail position)
 *
 * others:
 * Scala's @tailrec and Kotlin's tailrec mean what [@@tailrec] means:
 * they are checked, and an error is given otherwise. OCaml's
 * [@tailcall] gives a warning. Clang's [[clang::musttail]] makes a
 * call a tail call, or gives an error. *)

(* The calls marked [@tailcall], OCaml's way, on the function applied:
 * (f [@tailcall]) x. Each one must be a tail call, compiled as a jump.
 * They are keyed by the application's span. The marked function's
 * span is in the table too: the parser carries its mark to the
 * application, and parentheses carry a mark to their own span. *)
val tailcalls : (Ast.span, unit) Hashtbl.t

(* The functions marked [@@tailrec] (let rec f x = ... [@@tailrec]):
 * each call of f in its own body must be a tail call. They are keyed
 * by the span of the function that the binding gives. *)
val tailrecs : (Ast.span, unit) Hashtbl.t

(* The functions marked [@@zero_alloc] (let f x = ... [@@zero_alloc],
 * with the name and meaning of Jane Street's OCaml): f's code, as -O3
 * makes it (after inlining), must allocate nothing. They are keyed by
 * the span of the function. *)
val zero_allocs : (Ast.span, unit) Hashtbl.t

(* The functions marked [@inline], OCaml's way (let[@inline] f x =
 * ..., or [@@inline] after the binding). Each one is inlined where it
 * is called with all its arguments, whatever its size (-O3's bound,
 * Lower.inline_most, does not apply). Lower refuses such a function
 * when it is recursive, or when it holds a function, a handler or an
 * assertion. They are keyed by the span of the function. *)
val inlines : (Ast.span, unit) Hashtbl.t

(* The floats marked [@@unboxed_float] (let x = e [@@unboxed_float], or
 * let r = ref e [@@unboxed_float], where the mark is on its contents).
 * Such a float is a function's local, and -O3's Unbox keeps it as a
 * double in a register or in a slot of its own, never in a block.
 * Otherwise Unbox refuses it and says what boxes it (it is passed,
 * stored or returned) or makes it a block. This is not OCaml's
 * [@@unboxed], which is on a type and which ix's code uses (type reg =
 * R of int [@@unboxed]). They are keyed by the span of the bound
 * expression. *)
val unboxed_floats : (Ast.span, unit) Hashtbl.t

(* What an external's primitive may raise, said where it is declared
 * (external remove : string -> unit = "sys_remove" [@@raise Sys_error]):
 * a predefined exception that the C code raises. It is keyed by the
 * primitive's name, with one binding for each [@@raise]. Nothing
 * checks it, since the C is not read: the analyses trust it
 * (mini-analyze's Closure_facts puts a raise at each call;
 * docs/plans/done/plan_bug_analyses.md's A2). *)
val raises : (string, string) Hashtbl.t
