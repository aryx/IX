(* What a library's container does, for the facts: written at each call
 * given all its arguments, in place of the call (Closure_facts.call), as
 * an external's is, and once as the library's own function, for what
 * names it as a value (List.map (Hashtbl.find h) l).
 *
 * design:
 * A container written in ML is one set of cells for its whole program.
 * Hashtbl's buckets are made in Hashtbl.replace, so every table's are
 * one object: mini-cc's 50 tables gave each bucket all their 526 keys,
 * and a find in any of them found the keys of all. Contexts do not
 * separate them: the bucket is made in replace's replace_bucket, a local
 * function whose key and info, captured, have one set for all callers
 * (contexts.dl's global). A model has no cells: a table is one object,
 * made where Hashtbl.create is called, its keys one field, its values
 * another, as an array's elements are one (Closure_facts's arr:elt).
 *
 * The same for List: a list's cells, each function's parameter, held
 * every list of the program, 949 elements, and each load of a List
 * function's body went through them all; @'s cells too, one site for
 * every append. What it saves, measured: Models.ml (mini-analyze -dead on
 * mini-cc 36 s to 12 s, on mini-ml 51 s to 10 s).
 *
 * A modeled function's body is not read (its unit's binding: the model as
 * a function instead), so the model and the real code never meet: for
 * Hashtbl, every function of an interface whose type is abstract, none of
 * its cells seen by a caller; for List, a type not abstract, the model
 * reads and writes its real cells, and what is not modeled (partition,
 * split, map2) stays as written; Pervasives' @ too, alone of its unit.
 * dynamic.sh does not check what the models replace: List's and Hashtbl's
 * functions, and a function whose closure is a model's (model:...,
 * written where the real one is).
 *
 * others:
 * Doop analyzes the JDK's collections as written, and pays for it (its
 * "heap abstractions" for HashMap); Infer and Facebook's Pulse model
 * them; Soot's Spark and WALA give a few native methods models.
 *)

(* a model's variables: its k-th argument (1 ...), its result, a variable
 * of its own *)
type v = Arg of int | Ret | Tmp of int

type op =
  | New of v                    (* an object of the result's type made here *)
  | Load of v * v * string      (* dst, from, the field *)
  | Store of v * string * v     (* into, the field, what *)
  | Assign of v * v             (* dst, src *)
  | Scalar of v                 (* a number, unit, a constant constructor *)
  | Call of v * v * v           (* dst, the function, its argument *)
  | Raise of string             (* the exception's symbol, caml_exn_Not_found *)
  | Global of v * string        (* holds what the global does (a derived
                                   summary's: List.hd's Pervasives.failwith) *)

(* false: no model, the library's code read as written (mini-analyze
 * -no-models: to compare, Models.ml's numbers, tests/models/) *)
val on : bool ref

(* the summaries derived from the library's code (analyzers/summaries/,
 * plan_analysis_scale.md, step 3), by symbol; with [derived_on], read
 * first, the models written here for the rest (mini-analyze -summaries) *)
val derived : (string, int * op list) Hashtbl.t
val derived_on : bool ref

(* a global's model, by its symbol (Hashtbl.find): its arity and what it does *)
val find : string -> (int * op list) option

(* the units whose let groups are replaced, each whose every function is
 * modeled or summarized (Hashtbl whole, List in part) *)
val modeled_unit : string -> bool
