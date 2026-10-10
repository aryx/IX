(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Datalog_eval.mli *)

module D = Datalog

type stats = {
  mutable rounds : int;
  mutable firings : int;
  mutable derived : int;
  mutable lookups : int;
}

(*****************************************************************************)
(* A body joined *)
(*****************************************************************************)

(* where an atom's tuples are taken from *)
type source = Everything | These of int array list

(* the index of a relation by some columns, made if it is not there *)
let index (r : D.relation) (mask : int) : (int array, int array list ref) Hashtbl.t =
  match List.assoc_opt mask r.indexes with
  | Some index -> index
  | None ->
      let index : (int array, int array list ref) Hashtbl.t = Hashtbl.create (2 * r.count + 61) in
      List.iter
        (fun (tuple : int array) ->
          let key = D.project mask tuple in
          match Hashtbl.find_opt index key with
          | Some bucket -> bucket := tuple :: !bucket
          | None -> Hashtbl.add index key (ref [ tuple ]))
        r.all;
      r.indexes <- (mask, index) :: r.indexes;
      index

(* the tuples of an atom's relation that may match: by what is known of
 * its columns (a constant, a variable already bound) *)
let candidates (stats : stats) (a : D.atom) (env : int array) : int array list =
  let mask = ref 0 in
  Array.iteri
    (fun (i : int) (x : D.arg) ->
      match x with
      | D.Const _ -> mask := !mask lor (1 lsl i)
      | D.Slot k -> if env.(k) >= 0 then mask := !mask lor (1 lsl i)
      | D.Any -> ())
    a.args;
  stats.lookups <- stats.lookups + 1;
  if !mask = 0 then a.rel.all
  else begin
    let known = Array.map (fun (x : D.arg) -> match x with D.Const c -> c | D.Slot k -> env.(k) | D.Any -> -1) a.args in
    let key = D.project !mask known in
    if Array.length key = a.rel.arity then if Hashtbl.mem a.rel.set key then [ key ] else []
    else match Hashtbl.find_opt (index a.rel !mask) key with Some bucket -> !bucket | None -> []
  end

(* a tuple against an atom: its unbound variables bound (and said, to
 * unbind them); false: it does not match *)
let matches (a : D.atom) (tuple : int array) (env : int array) (bound : int list ref) : bool =
  let ok = ref true in
  Array.iteri
    (fun (i : int) (x : D.arg) ->
      if !ok then
        match x with
        | D.Const c -> if c <> tuple.(i) then ok := false
        | D.Any -> ()
        | D.Slot k ->
            if env.(k) < 0 then begin
              env.(k) <- tuple.(i);
              bound := k :: !bound
            end
            else if env.(k) <> tuple.(i) then ok := false)
    a.args;
  !ok

let value (env : int array) (x : D.arg) : int = match x with D.Const c -> c | D.Slot k -> env.(k) | D.Any -> -1

(* are a negation's or a comparison's variables all bound? *)
let ready (env : int array) (l : D.literal) : bool =
  let known (x : D.arg) : bool = match x with D.Slot k -> env.(k) >= 0 | _ -> true in
  match l with
  | D.Pos _ -> true
  | D.Neg a -> Array.for_all known a.args
  | D.Cmp (_, x, y) -> known x && known y

let holds (p : D.t) (stats : stats) (env : int array) (l : D.literal) : bool =
  match l with
  | D.Pos _ -> true
  | D.Neg a ->
      let bound : int list ref = ref [] in
      not (List.exists (fun (tuple : int array) -> matches a tuple env bound) (candidates stats a env))
  | D.Cmp (op, x, y) -> (
      let x = value env x and y = value env y in
      match op with
      | "=" | "==" -> x = y
      | "\\=" | "\\==" -> x <> y
      | _ -> (
          let c = Prolog.compare p.terms.(x) p.terms.(y) in
          match op with "<" -> c < 0 | ">" -> c > 0 | "=<" -> c <= 0 | _ -> c >= 0))

(* each way the literals hold together: [found] called with the
 * variables bound. [waiting]: the negations and comparisons met before
 * their variables were bound. *)
let rec join (p : D.t) (stats : stats) (env : int array) (lits : (D.literal * source) list) (waiting : D.literal list)
    (found : unit -> unit) : unit =
  let now, waiting = List.partition (ready env) waiting in
  if List.for_all (holds p stats env) now then
    match lits with
    | [] -> found ()
    | (D.Pos a, source) :: rest ->
        let tuples : int array list = match source with Everything -> candidates stats a env | These tuples -> tuples in
        List.iter
          (fun (tuple : int array) ->
            let bound : int list ref = ref [] in
            if matches a tuple env bound then join p stats env rest waiting found;
            List.iter (fun (k : int) -> env.(k) <- -1) !bound)
          tuples
    | (l, _) :: rest -> join p stats env rest (l :: waiting) found

(* a rule applied, one of its atoms maybe from the new tuples only: the
 * tuples it finds that were not known are its head's fresh ones *)
let apply (p : D.t) (stats : stats) (rule : D.rule) (lits : (D.literal * source) list) : unit =
  let env = Array.make rule.slots (-1) in
  join p stats env lits [] (fun () ->
      stats.firings <- stats.firings + 1;
      let tuple = Array.map (value env) rule.head.args in
      if D.add rule.head.rel tuple then begin
        stats.derived <- stats.derived + 1;
        rule.head.rel.fresh <- tuple :: rule.head.rel.fresh
      end)

(*****************************************************************************)
(* The strata, and the fixpoint *)
(*****************************************************************************)

(* each relation's stratum: at least that of what it reads, and one more
 * than that of what it negates *)
let stratify (p : D.t) : int =
  let n = Hashtbl.length p.relations in
  let changed = ref true and top = ref 0 in
  Hashtbl.iter (fun (_ : string) (r : D.relation) -> r.stratum <- 0) p.relations;
  while !changed do
    changed := false;
    List.iter
      (fun (rule : D.rule) ->
        let head = rule.head.rel in
        let raise_to (s : int) : unit =
          if s > head.stratum then begin
            if s > n then
              raise (D.Error (Printf.sprintf "%s/%d is negated through its own recursion: no order to compute it in" head.name head.arity, rule.at));
            head.stratum <- s;
            if s > !top then top := s;
            changed := true
          end in
        List.iter
          (fun (l : D.literal) ->
            match l with
            | D.Pos a -> raise_to a.rel.stratum
            | D.Neg a -> raise_to (a.rel.stratum + 1)
            | D.Cmp _ -> ())
          rule.body)
      p.rule_list
  done;
  !top

let everything (rule : D.rule) : (D.literal * source) list = List.map (fun (l : D.literal) -> (l, Everything)) rule.body

(* the body with its k-th literal first, from the new tuples only *)
let from_new (rule : D.rule) (k : int) (a : D.atom) : (D.literal * source) list =
  let others = List.filteri (fun (i : int) (_ : D.literal) -> i <> k) rule.body in
  (D.Pos a, These a.rel.delta) :: List.map (fun (l : D.literal) -> (l, Everything)) others

let run ~(naive : bool) (p : D.t) : stats =
  let stats : stats = { rounds = 0; firings = 0; derived = 0; lookups = 0 } in
  let top = stratify p in
  let rules = List.rev p.rule_list in
  for s = 0 to top do
    let mine = List.filter (fun (rule : D.rule) -> rule.head.rel.stratum = s) rules in
    (* (each once: a relation with two rules is one relation) *)
    let heads : D.relation list =
      List.fold_left
        (fun (acc : D.relation list) (rule : D.rule) -> if List.memq rule.head.rel acc then acc else rule.head.rel :: acc)
        [] mine in
    (* a round's end: the fresh tuples are the next one's new ones *)
    let turn () : bool =
      let any = ref false in
      List.iter
        (fun (r : D.relation) ->
          (match r.fresh with [] -> () | _ -> any := true);
          r.delta <- r.fresh;
          r.fresh <- [])
        heads;
      stats.rounds <- stats.rounds + 1;
      !any in
    List.iter (fun (rule : D.rule) -> apply p stats rule (everything rule)) mine;
    while turn () do
      List.iter
        (fun (rule : D.rule) ->
          if naive then apply p stats rule (everything rule)
          else
            List.iteri
              (fun (k : int) (l : D.literal) ->
                match l with
                | D.Pos a when a.rel.stratum = s && a.rel.rules > 0 -> (
                    match a.rel.delta with [] -> () | _ -> apply p stats rule (from_new rule k a))
                | _ -> ())
              rule.body)
        mine
    done;
    List.iter (fun (r : D.relation) -> r.delta <- []) heads
  done;
  stats

let answers (p : D.t) (q : D.query) : string list =
  let stats : stats = { rounds = 0; firings = 0; derived = 0; lookups = 0 } in
  let env = Array.make (Array.length q.names) (-1) in
  let found : string list ref = ref [] in
  join p stats env [ (D.Pos q.goal, Everything) ] [] (fun () ->
      found := D.show p q.goal.rel (Array.map (value env) q.goal.args) :: !found);
  List.sort_uniq String.compare !found
