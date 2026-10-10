(* A C file as Datalog facts (docs/plans/plan_prolog.md, stage 8): what
 * each function does to pointers, said in the relations of the
 * author's pointer analysis (languages/datalog/analyses/pointer.dl, 2014), for
 * mini-datalog to run its rules on. mini-cc -facts.
 *
 * Each expression is made a few simple instructions over variables, a
 * temporary for each value in between (pfff's datalog_c.ml did the
 * same over its own tree; this one is written over Tree, before the
 * typing: a member still has its name there). Nothing is said of the
 * order of the instructions, nor of what is no pointer: the analysis
 * asks neither.
 *
 *   p = q          assign(p, q).              p = &x      assign_address(p, x).
 *   p = *q         assign_content(p, q).      *p = q      assign_deref(p, q).
 *   p = a[i]       assign_array_elt(p, a).    a[i] = q    assign_array_deref(a, q).
 *   p = &a[i]      assign_array_element_address(p, a).
 *   p = x->f       assign_load_field(p, x, F).     x->f = q   assign_store_field(x, F, q).
 *   p = &x->f      assign_field_address(p, x, F).
 *   r = f(a, b)    call_direct(I, f). argument(I, 1, a). argument(I, 2, b). call_ret(I, r).
 *   r = p(a)       call_indirect(I, p). ...   (p a pointer to a function; or its star, called)
 *   a function f   parameter(f, 1, V). return(f, ret_f). point_to(f, f).
 *   "..."          point_to(T, S).            malloc(n)   point_to(T, M).
 *   an array a     point_to(a, E): its elements are one place.
 *
 * A local x of f is f__x, a temporary f__tN, a member m is _fld__m
 * (whatever its structure: the analysis is by field's name), a call
 * _in_f_line_N_K. *)

(* a function's name and its body, as the parser gives them *)
val func : Tree.sym -> Tree.stmt -> unit

(* a global's initializer: the symbol, a value put in it (Declare.gextern's) *)
val global : Tree.sym -> Tree.expr -> unit

(* the facts so far, a line each, in the order found, each once *)
val text : unit -> string
