(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Models.mli for what a model is.
 *
 * An optimization of the pointer analysis, before any of its precision:
 * the time is the facts' (lib_code/datalog/points_to/andersen.dl's, run
 * first by every analysis), not the engine's.
 *
 * Found by the hot rule's joins. mini-datalog -profile: on mini-cc,
 * andersen.dl's
 *
 *     flow(P, L) :- load(P, X, F), pt(X, O), fpt(O, F, L).
 *
 * 70.7 million firings for 1.1 million facts, 26 s of the 36; each
 * answer found some 60 times. Counting each load's objects times their
 * field's set: half on con:::.0, a list cell's head, of List's code, as
 * written in lib_core:
 *
 *     let rec iter f = function [] -> () | a :: l -> f a; iter f l
 *
 *     List.iter's l       one variable for every caller: 637 cells
 *     each cell's head    949 elements, every list's of the program
 *     a = hd l            637 x 949 joins, for 1,205 answers
 *
 * and the same in map, mem, assoc, fold_left, ... (each its parameter,
 * its cells), in @ (one cell site for every append: a list made by @ is
 * one list, mini-ml's 1,500 cells), and in Hashtbl's buckets (one for all
 * 50 tables of mini-cc, 526 keys each). The types do not separate them
 * (an 'a list's cell holds any element); a model at each call does: a
 * list passed there has its own cells, and List.iter's a only its
 * elements.
 *
 * Measured, mini-analyze on this machine (64 arm64 cores, one run each,
 * 2026-11-03), HEAD before the models against the models; the units of
 * each program's mkfile (lib_code/datalog/tests/mk_units.sh):
 *
 *     mini-cc (41 units)  before            the models
 *     the call graph      36.1 s  1.1 GB    12.4 s  0.37 GB
 *     -dead               35.7 s  3.8 GB    12.3 s  1.2 GB
 *     -caps               36.0 s  3.8 GB    12.4 s  1.2 GB
 *     -exn                247 s  12.3 GB    46.2 s  3.8 GB
 *
 *     mini-ml (47 units)  before            the models
 *     the call graph      70.3 s  1.4 GB    21.0 s  0.28 GB
 *     -dead               51.3 s  3.8 GB    10.1 s  1.0 GB
 *     -caps               51.0 s  3.9 GB    10.4 s  1.0 GB
 *     -exn                out of memory at 14 GB, both
 *
 * mini-cc's -exn read for the first time in the sweep's 180 s (its 6
 * exceptions; lib_code/datalog/tests/exn_ix.txt). Each model's share, on
 * mini-cc's Andersen alone (mini-datalog, its facts): 70.7 million
 * firings; Hashtbl's 64.4; and List's 13.7. On mini-ml, List and Hashtbl
 * without @ were slower than none, 134 s against 70: the lists made by @
 * still one list, a model's c = c.tl walked it whole at each call, 2.5
 * times the lookups; with @, 21 s.
 *
 * Precision came with it, a call's closures its own: -exn 14 reports
 * fewer in 11 programs, none more (10 tried on the programs, each caught:
 * awk's Exit_program, shell's Word.Error, the linker's Link.Error, ...),
 * List.iter's one call of f having been every closure given to any
 * List.iter; mini-cc's call graph 12 functions fewer reached (Signature's
 * decoders, called by List.init's one call of f). -dead's and -caps's
 * reports the same on the 44 programs (sweep.sh); dynamic.sh none missed.
 *
 * road-not-taken: contexts, the textbook answer to a polymorphic
 * function's callers merged. One for each call of a polymorphic or
 * higher-order function (call-site sensitivity for those alone): 152
 * million firings against 159 without contexts; the merge moved to
 * Hashtbl's buckets, made in replace's local replace_bucket, whose key
 * and info, captured, have one set for all callers (contexts.dl's
 * global). Then a local function in its closure's context (m-CFA's, as
 * contexts.dl's curried stages): 123 million, and mini-prolog's Halt
 * reported again. Cells of one type made one (every int list's): 5%.
 *
 * Why a model does what a clone, or a context, would not, though it is
 * one, the library's code copied at each call:
 *  - the whole call tree, to any depth. A context names a call by one
 *    call site; the library calls its own helpers (replace's
 *    replace_bucket, rev's rev_append, init's init_aux), whose context
 *    is then their one call site in the library, every caller's. A
 *    model has no call inside: its objects are named by the caller's
 *    call, however deep the real code went;
 *  - no closure. What a closure captures is one set for every context
 *    (contexts.dl's global, m-CFA's flat environment: followed by
 *    context, exponential), and Hashtbl's code is closures over key and
 *    info;
 *  - simpler than the code. A clone keeps its shape, an array of
 *    buckets, their Cons chains, resize copying them; a model is one
 *    object and two fields. And a loop over a list, to a flow-insensitive
 *    analysis, is its two facts, c = l and c = c.tl: the clone reduced to
 *    what this analysis can see of it;
 *  - in the facts, so in every analysis. Contexts come after andersen.dl,
 *    which had the merge itself (26 of mini-cc's 36 s), and multiply
 *    what they keep (pt/6 3.9 million tuples, pt/2 1.1): never cheaper
 *    than the analysis without them. A model makes that one cheaper, and
 *    -dead, -caps and the call graph, which have no context, with it.
 * Its price is a model to write, and check, for each function; the
 * contexts are automatic. Worth it for a few containers, called
 * everywhere: 53 functions here (16 of Hashtbl, 36 of List, @).
 *
 * design: what keeps it sound. A modeled function's body is not read, so
 * the model and the real code never meet (Models.mli). The facts after a
 * model are named as without it (Closure_facts.call: the calls' and the
 * temporaries' numbers it replaces), so a change of the facts is only
 * the model's. Its calls of what it is given say so (model_call), for
 * bugs/stack.dl, which follows only a unit's own calls. dynamic.sh does
 * not check what the models replace (it ran, and no fact says it). A
 * model raises what its function's code may (analyzers/tests/models/:
 * each one called, what escapes and what is called the same as with
 * mini-analyze -no-models, the library read as written; the numbers
 * above, the same option against none).
 *
 * old: List's and Hashtbl's bodies read as written, as every unit's;
 * lib_core's ML code, so no external's copy at each call (Closure_facts's
 * prim_body) applied to them. *)

type v = Arg of int | Ret | Tmp of int

type op =
  | New of v
  | Load of v * v * string
  | Store of v * string * v
  | Assign of v * v
  | Scalar of v
  | Call of v * v * v
  | Raise of string

let failure : string = "caml_exn_Failure"
(* (what the real code may raise: compare's Invalid_argument, a functional
 * value compared, in every find, mem and assoc; Array.make's, in create
 * and a resize; checked by analyzers/tests/models/) *)
let invalid : string = "caml_exn_Invalid_argument"
let not_found : string = "caml_exn_Not_found"

(* ---- Hashtbl: a table one object, its keys a field, its values another *)

let key : string = "tbl:key"
let value : string = "tbl:val"

(* every binding of the table in Arg 2: its key in Tmp 1, its value in Tmp 2 *)
let bindings : op list = [ Load (Tmp 1, Arg 2, key); Load (Tmp 2, Arg 2, value) ]

(* f k v, a call for each argument, f's result in Tmp 4 *)
let each_binding : op list =
  bindings @ [ Call (Tmp 3, Arg 1, Tmp 1); Call (Tmp 4, Tmp 3, Tmp 2) ]

let stored : op list =
  [ Store (Arg 1, key, Arg 2); Store (Arg 1, value, Arg 3); Scalar Ret;
    Raise invalid ]

let hashtbl : (string * (int * op list)) list =
  [ ("create", (1, [ New Ret; Raise invalid ]));
    ("clear", (1, [ Scalar Ret ]));
    ("reset", (1, [ Scalar Ret ]));
    ("copy", (1, [ New Ret; Raise invalid;
                   Load (Tmp 1, Arg 1, key); Store (Ret, key, Tmp 1);
                   Load (Tmp 2, Arg 1, value); Store (Ret, value, Tmp 2) ]));
    ("length", (1, [ Scalar Ret ]));
    ("add", (3, stored));
    ("replace", (3, stored));
    ("remove", (2, [ Scalar Ret; Raise invalid ]));
    ("mem", (2, [ Scalar Ret; Raise invalid ]));
    ("find", (2, [ Load (Ret, Arg 1, value); Raise not_found; Raise invalid ]));
    (* (a list: its cell's tail the cell itself, or []) *)
    ("find_all", (2, [ New Ret; Raise invalid; Load (Tmp 1, Arg 1, value);
                       Store (Ret, "con:::.0", Tmp 1); Store (Ret, "con:::.1", Ret);
                       Scalar Ret ]));
    ("find_opt", (2, [ New Ret; Raise invalid; Load (Tmp 1, Arg 1, value);
                       Store (Ret, "con:Some.0", Tmp 1); Scalar Ret ]));
    ("iter", (2, each_binding @ [ Scalar Ret ]));
    (* f k v acc, acc first init then what f returned *)
    ("fold", (3, bindings @ [ Assign (Tmp 5, Arg 3); Call (Tmp 3, Arg 1, Tmp 1);
                              Call (Tmp 4, Tmp 3, Tmp 2); Call (Tmp 5, Tmp 4, Tmp 5);
                              Assign (Ret, Tmp 5) ]));
    (* f k v: None, or Some v', the binding's new value *)
    ("filter_map_inplace",
     (2, each_binding @ [ Load (Tmp 5, Tmp 4, "con:Some.0");
                          Store (Arg 2, value, Tmp 5); Scalar Ret ])) ]

(* ---- List: the real cells, a model of a loop over them
 *
 * design:
 * A list is not abstract: its cells are made and taken apart by every
 * caller (::, a match), so the model reads and writes them, con:::.0
 * and con:::.1, and the functions not modeled stay as written. A loop
 * over a list is two facts, flow-insensitive: c = l, then c = c.tl, so
 * c points to every cell of l, and x = c.hd to every element. A list
 * made is one cell of this call, its tail itself or [] *)

let hd : string = "con:::.0"
let tl : string = "con:::.1"

(* the elements of the list in a, in Tmp e (its cells in Tmp (e + 1)) *)
let elements (a : v) (e : int) : op list =
  [ Assign (Tmp (e + 1), a); Load (Tmp (e + 1), Tmp (e + 1), tl);
    Load (Tmp e, Tmp (e + 1), hd) ]

(* the result a list of what is in x *)
let made (x : v) : op list =
  [ New Ret; Store (Ret, hd, x); Store (Ret, tl, Ret); Scalar Ret ]

let some (x : v) : op list = [ New Ret; Store (Ret, "con:Some.0", x); Scalar Ret ]

(* f called on each element of Arg 2 (in Tmp 1), its result in Tmp 3 *)
let each : op list = elements (Arg 2) 1 @ [ Call (Tmp 3, Arg 1, Tmp 1) ]

(* f i x: an index first *)
let each_i : op list =
  elements (Arg 2) 1
  @ [ Scalar (Tmp 4); Call (Tmp 5, Arg 1, Tmp 4); Call (Tmp 3, Tmp 5, Tmp 1) ]

(* a pair's second field in Tmp 3, of the elements of Arg 2 (assoc's) *)
let second : op list = elements (Arg 2) 1 @ [ Load (Tmp 3, Tmp 1, "tuple:2.1") ]

(* cmp x y, of the elements of Arg 2 *)
let compared : op list = each @ [ Call (Tmp 4, Tmp 3, Tmp 1) ]

let list : (string * (int * op list)) list =
  [ ("length", (1, [ Scalar Ret ]));
    ("hd", (1, [ Load (Ret, Arg 1, hd); Raise failure ]));
    ("tl", (1, [ Load (Ret, Arg 1, tl); Raise failure ]));
    ("nth", (2, elements (Arg 1) 1
                @ [ Assign (Ret, Tmp 1); Raise failure; Raise invalid ]));
    ("rev", (1, elements (Arg 1) 1 @ made (Tmp 1)));
    ("rev_append", (2, elements (Arg 1) 1 @ made (Tmp 1) @ [ Assign (Ret, Arg 2) ]));
    ("iter", (2, each @ [ Scalar Ret ]));
    ("iteri", (2, each_i @ [ Scalar Ret ]));
    ("map", (2, each @ made (Tmp 3)));
    ("rev_map", (2, each @ made (Tmp 3)));
    ("mapi", (2, each_i @ made (Tmp 3)));
    ("filter", (2, each @ made (Tmp 1)));
    ("find_all", (2, each @ made (Tmp 1)));
    ("filteri", (2, each_i @ made (Tmp 1)));
    ("filter_map", (2, each @ [ Load (Tmp 4, Tmp 3, "con:Some.0") ] @ made (Tmp 4)));
    ("concat_map", (2, each @ elements (Tmp 3) 4 @ made (Tmp 4)));
    (* f acc x, acc first init then what f returned *)
    ("fold_left", (3, [ Assign (Tmp 3, Arg 2) ] @ elements (Arg 3) 1
                      @ [ Call (Tmp 4, Arg 1, Tmp 3); Call (Tmp 3, Tmp 4, Tmp 1);
                          Assign (Ret, Tmp 3) ]));
    ("fold_right", (3, [ Assign (Tmp 3, Arg 3) ] @ elements (Arg 2) 1
                       @ [ Call (Tmp 4, Arg 1, Tmp 1); Call (Tmp 3, Tmp 4, Tmp 3);
                           Assign (Ret, Tmp 3) ]));
    ("mem", (2, [ Scalar Ret; Raise invalid ]));
    ("memq", (2, [ Scalar Ret ]));
    ("mem_assoc", (2, [ Scalar Ret; Raise invalid ]));
    ("exists", (2, each @ [ Scalar Ret ]));
    ("for_all", (2, each @ [ Scalar Ret ]));
    ("find", (2, each @ [ Assign (Ret, Tmp 1); Raise not_found ]));
    ("find_opt", (2, each @ some (Tmp 1)));
    ("find_map", (2, each @ [ Assign (Ret, Tmp 3); Scalar Ret ]));
    ("assoc", (2, second @ [ Assign (Ret, Tmp 3); Raise not_found; Raise invalid ]));
    ("assq", (2, second @ [ Assign (Ret, Tmp 3); Raise not_found ]));
    ("assoc_opt", (2, second @ some (Tmp 3) @ [ Raise invalid ]));
    ("assq_opt", (2, second @ some (Tmp 3)));
    ("remove_assoc", (2, elements (Arg 2) 1 @ made (Tmp 1) @ [ Raise invalid ]));
    ("init", (2, [ Scalar (Tmp 1); Call (Tmp 2, Arg 2, Tmp 1); Raise invalid ]
                 @ made (Tmp 2)));
    ("sort", (2, compared @ made (Tmp 1)));
    ("stable_sort", (2, compared @ made (Tmp 1)));
    ("sort_uniq", (2, compared @ made (Tmp 1)));
    ("iter2", (3, elements (Arg 2) 1 @ elements (Arg 3) 3
                  @ [ Call (Tmp 5, Arg 1, Tmp 1); Call (Tmp 6, Tmp 5, Tmp 3);
                      Scalar Ret; Raise invalid ]));
    ("concat", (1, elements (Arg 1) 1 @ elements (Tmp 1) 3 @ made (Tmp 3)));
    ("flatten", (1, elements (Arg 1) 1 @ elements (Tmp 1) 3 @ made (Tmp 3))) ]

(* (l1 @ l2: l1's elements in a cell of this call, then l2's cells; written,
 * one cell site for every append, every list made by @ one list, which a
 * model's c = c.tl walked whole: mini-ml's 1,500 cells, 1,353 elements) *)
let pervasives : (string * (int * op list)) list =
  [ ("@", (2, elements (Arg 1) 1 @ made (Tmp 1) @ [ Assign (Ret, Arg 2) ])) ]

let units : (string * (string * (int * op list)) list) list =
  [ ("Hashtbl", hashtbl); ("List", list); ("Pervasives", pervasives) ]

let on : bool ref = ref true

let find (sym : string) : (int * op list) option =
  match String.index_opt sym '.' with
  | Some _ when not !on -> None
  | Some i -> (
      match List.assoc_opt (String.sub sym 0 i) units with
      | Some fs ->
          List.assoc_opt (String.sub sym (i + 1) (String.length sym - i - 1)) fs
      | None -> None)
  | None -> None

let modeled_unit (name : string) : bool = !on && List.mem_assoc name units
