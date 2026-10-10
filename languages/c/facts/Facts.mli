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
 * _in_f_line_N_K.
 *
 * The compiler's part ends at the facts; the answer is the rules':
 * point_to(V, M), which variable may hold the address of which
 * place, and from it call_edge(I, F), which functions a call through
 * a pointer may reach. A kernel is where that is worth asking: its
 * drivers are tables of pointers to functions, and no grep says who
 * calls a driver's read. mini-ml's Closure_facts says a unit of ML in
 * the same relations, where every call is such a call.
 *
 * terminology:
 * The analysis is the cheapest of its family in three ways, each a
 * word. Flow-insensitive: a function is a set of assignments, their
 * order forgotten (so p = &x; p = &y; says p may point to both, at
 * any line). Context-insensitive: a function is analyzed once for
 * all its callers, whose arguments are mixed. Field-based: x->f is
 * one place for every x. Each could be refined, at a price; this
 * one is the base the others are measured against.
 *
 * cs-history:
 * It is Lars Andersen's analysis (1994): each assignment a
 * constraint that one set of places includes another, solved to a
 * fixpoint, cubic in the worst case. Bjarne Steensgaard's (1996)
 * makes the sets equal instead of included, by union-find, in
 * nearly linear time and with coarser answers. The step to Datalog
 * was to see that such constraints are rules of logic and their
 * solving a database's work (John Whaley and Monica Lam, 2004, for
 * Java, with relations stored as binary decision diagrams; Doop
 * after them), which is how the author's pointer.dl is written.
 *
 * References: Lars Ole Andersen, "Program Analysis and Specialization
 * for the C Programming Language" (his thesis, Copenhagen, 1994);
 * Bjarne Steensgaard, "Points-to analysis in almost linear time"
 * (POPL 1996); John Whaley and Monica Lam, "Cloning-based
 * context-sensitive pointer alias analysis using binary decision
 * diagrams" (PLDI 2004). *)

(* a function's name and its body, as the parser gives them *)
val func : Tree.sym -> Tree.stmt -> unit

(* a global's initializer: the symbol, a value put in it (Declare.gextern's) *)
val global : Tree.sym -> Tree.expr -> unit

(* the facts so far, a line each, in the order found, each once *)
val text : unit -> string
