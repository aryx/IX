(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/eval/Js_scope.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_scope.mli *)
open Js_value

(*****************************************************************************)
(* The simple way: a table of names in each scope *)
(*****************************************************************************)

let own_simple (vars : (string, binding) Hashtbl.t) (x : string) : binding option = Hashtbl.find_opt vars x
let declare_simple (vars : (string, binding) Hashtbl.t) (x : string) (b : binding) : unit = Hashtbl.replace vars x b

(* a for's next iteration: the same names, in new bindings holding the
 * same values (Hashtbl.copy would share the bindings, and every
 * iteration's closures would see the last i) *)
let copy_simple (vars : (string, binding) Hashtbl.t) : (string, binding) Hashtbl.t =
  let copy = Hashtbl.create 8 in
  Hashtbl.iter (fun x (b : binding) -> Hashtbl.replace copy x { b with value = b.value }) vars;
  copy

(*****************************************************************************)
(* opti: an array of bindings in each scope *)
(*****************************************************************************)

(* opti: with tables, 100,000 calls of a function of two arguments were
 * 1,708 million instructions (callgrind), two thirds of them hashing
 * names, comparing them and making tables: a table for each block and
 * each call, a name hashed in each scope up to the one that has it.
 * With slots and places: see Js_scope.mli for the numbers *)

let no_names : string array = [||]
let no_cells : binding array = [||]
let nothing : binding = { value = Undefined; constant = false }
let empty () : slots = { names = no_names; cells = no_cells; used = 0; index = None; fixed = 0 }


(* the slot of [x], or -1: the names gone through, the last declared
 * first; then, for the first [fixed] of them, the index *)
let slot_of (sl : slots) (x : string) : int =
  let rec go (i : int) =
    if i < sl.fixed then match sl.index with Some index -> ( match Hashtbl.find_opt index x with Some i -> i | None -> -1) | None -> -1
    else
      let n = Array.unsafe_get sl.names i in
      if n == x || (String.length n = String.length x && String.equal n x) then i else go (i - 1)
  in
  go (sl.used - 1)

(* names past sixteen (the globals; a program in one function, as
 * js_of_ocaml makes them) are found by an index. It is never written
 * once made -- a function's calls share theirs (Js_ast.frame) --: one
 * more is made when sixteen names have come since *)
let index_of (names : string array) (n : int) : (string, int) Hashtbl.t =
  let index = Hashtbl.create (2 * n) in
  for i = 0 to n - 1 do
    Hashtbl.replace index names.(i) i
  done;
  index

let own_opti (sl : slots) (x : string) : binding option =
  let i = slot_of sl x in
  if i < 0 then None else Some (Array.unsafe_get sl.cells i)

let declare_opti (sl : slots) (x : string) (b : binding) : unit =
  let i = slot_of sl x in
  if i >= 0 then sl.cells.(i) <- b
  else (
    (* no room: both arrays made anew, twice as long -- never written
     * in place past their end, so a frame can share its function's
     * array of names (Js_ast.frame) with every other call *)
    if sl.used >= Array.length sl.cells then (
      let room = max 4 (2 * sl.used) in
      let names = Array.make room "" and cells = Array.make room nothing in
      Array.blit sl.names 0 names 0 sl.used;
      Array.blit sl.cells 0 cells 0 sl.used;
      sl.names <- names;
      sl.cells <- cells);
    sl.names.(sl.used) <- x;
    sl.cells.(sl.used) <- b;
    sl.used <- sl.used + 1;
    if sl.used - sl.fixed > 16 then (
      sl.index <- Some (index_of sl.names sl.used);
      sl.fixed <- sl.used))

let copy_opti (sl : slots) : slots =
  if sl.used = 0 then empty ()
  else
    {
      names = Array.sub sl.names 0 sl.used;
      cells = Array.init sl.used (fun i -> { (sl.cells.(i)) with value = sl.cells.(i).value });
      used = sl.used;
      index = sl.index;
      fixed = sl.fixed;
    }

(* [x] looked for from [s] up, by its name, and where it was found
 * written in [p] *)
let rec learn (s : scope) (x : string) (p : Js_ast.place) (hops : int) : binding option =
  let found = match s.vars with Slots sl -> ( match slot_of sl x with -1 -> None | i -> Some (i, sl.cells.(i))) | Table _ -> None in
  match (found, s.parent) with
  | Some (slot, b), _ ->
      p.hops <- hops;
      p.slot <- slot;
      Some b
  | None, Some parent -> learn parent x p (hops + 1)
  | None, None -> None

let rec up (s : scope) (hops : int) : scope = if hops = 0 then s else match s.parent with Some parent -> up parent (hops - 1) | None -> s

(* the place tried first: that many scopes up, that slot, if its name
 * is [x] there; else looked for again *)
let find_opti (s : scope) (x : string) (p : Js_ast.place) : binding option =
  if p.hops < 0 then learn s x p 0
  else
    match (up s p.hops).vars with
    | Slots sl when p.slot < sl.used && (let n = Array.unsafe_get sl.names p.slot in n == x || String.equal n x) -> Some (Array.unsafe_get sl.cells p.slot)
    | _ -> learn s x p 0

(* find_opti with no option made: [nothing] when there is none (the
 * compiled code's: Js_compile) *)
let learned (s : scope) (x : string) (p : Js_ast.place) : binding = match learn s x p 0 with Some b -> b | None -> nothing

let at (s : scope) (x : string) (p : Js_ast.place) : binding =
  if p.hops < 0 then learned s x p
  else
    match (if p.hops = 0 then s else up s p.hops).vars with
    | Slots sl when p.slot < sl.used && (let n = Array.unsafe_get sl.names p.slot in n == x || String.equal n x) -> Array.unsafe_get sl.cells p.slot
    | _ -> learned s x p

(*****************************************************************************)
(* Scopes *)
(*****************************************************************************)

let global () : scope =
  let vars = if !Mini_opti.enabled then Slots (empty ()) else Table (Hashtbl.create 64) in
  { vars; parent = None; subject = None; in_with = false; strict = false }

(* of its parent's kind: an engine is all tables or all slots *)
let fresh (parent : scope) : vars = match parent.vars with Table _ -> Table (Hashtbl.create 8) | Slots _ -> Slots (empty ())
let nested (parent : scope) : scope = { vars = fresh parent; parent = Some parent; subject = None; in_with = parent.in_with; strict = parent.strict }
let strict (parent : scope) : scope = { (nested parent) with strict = true }
let with_subject (parent : scope) (o : value) : scope = { (nested parent) with subject = Some o; in_with = true }

let frame (parent : scope) ~(names : string array) ~(index : (string, int) Hashtbl.t option) ~(cells : binding array) ~(strict : bool) : scope =
  let used = Array.length cells in
  { vars = Slots { names; cells; used; index; fixed = (match index with None -> 0 | Some _ -> used) }; parent = Some parent; subject = None; in_with = parent.in_with; strict }

let slotted (s : scope) : bool = match s.vars with Slots _ -> true | Table _ -> false
let own (s : scope) (x : string) : binding option = match s.vars with Table vars -> own_simple vars x | Slots sl -> own_opti sl x
let share (s : scope) (x : string) (b : binding) : unit = match s.vars with Table vars -> declare_simple vars x b | Slots sl -> declare_opti sl x b
let declare (s : scope) (x : string) ~(constant : bool) (v : value) : unit = share s x { value = v; constant }
let copy (s : scope) : scope = { s with vars = (match s.vars with Table vars -> Table (copy_simple vars) | Slots sl -> Slots (copy_opti sl)) }

(* the scope that has the name, the nearest first: the same words for
 * a table and for slots *)
let rec lookup (s : scope) (x : string) : binding option =
  match own s x with Some b -> Some b | None -> ( match s.parent with Some parent -> lookup parent x | None -> None)

let find (s : scope) (x : string) (p : Js_ast.place) : binding option = match s.vars with Table _ -> lookup s x | Slots _ -> find_opti s x p
