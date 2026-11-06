(* A library function's summary, derived from its facts, in Models'
 * vocabulary (plan_analysis_scale.md, step 3): what Models.ml writes by
 * hand for List and Hashtbl, made of the code itself.
 *
 *     lib_core's facts            a function's tree: its curried
 *     (-no-models: List and  -->  stages, its local functions; its
 *     Hashtbl as written)         variables Tmps, its parameters
 *                                 copied from Arg i, its result Ret
 *                                    |
 *                                    v
 *     a call in the tree: its parameters and result (inside, Andersen's)
 *     a call through anything else: Call (the caller's analysis makes it)
 *     a global read: Global;  raise_of: Raise;  the rest one op a fact
 *
 * design:
 * Why a summary is the tree and not each function. A call of a local
 * function, or of the function itself, is written as assignments to
 * its parameters, not as a call: the tree's objects are then the
 * caller's call's, however deep the code went, which is what makes
 * Models precise (Models.ml's design note); a loop over a list becomes
 * c = l, c = c.tl. A tree with a try, a global written, or a primitive
 * called through a variable is not summarized: its body is kept. *)

type op = Models.op =
  | New of Models.v
  | Load of Models.v * Models.v * string
  | Store of Models.v * string * Models.v
  | Assign of Models.v * Models.v
  | Scalar of Models.v
  | Call of Models.v * Models.v * Models.v
  | Raise of string
  | Global of Models.v * string

(* a fact: its relation, its atoms (numbers as their digits) *)
type fact = string * string list

(* [derive ~units facts]: each function of those units (by its symbol,
 * List.iter) summarized: its arity, its ops; or why not *)
val derive :
  units:string list -> fact list ->
  (string * (int * op list, string) result) list

(* facts read from mini-analyze -facts's text *)
val parse : string -> fact list

(* an op as Models.ml writes it (Load (Tmp 3, Arg 2, "con:::.0")) *)
val show : op -> string

(* the summaries as a file's text, a function a line (its symbol, its
 * arity) then its ops a line each, indented (Load T3 A2 con:::.0); and
 * read back *)
val to_text : (string * (int * op list)) list -> string
val of_text : string -> (string * (int * op list)) list
