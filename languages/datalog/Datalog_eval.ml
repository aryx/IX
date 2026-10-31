(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Datalog_eval.mli *)

module D = Datalog

type stats = {
  mutable rounds : int;
  mutable firings : int;
  mutable derived : int;
  mutable lookups : int;
  mutable profile : (D.rule * cost) list;
}

and cost = { mutable fired : int; mutable added : int; mutable looked : int; mutable seconds : float }

(*****************************************************************************)
(* A body's plan *)
(*****************************************************************************)

(* a body as steps run in order (Souffle's RAM, smaller), chosen once a
 * rule and its atom from the new tuples: what each atom knows of its
 * columns when it is reached, which variables it binds, where each
 * negation or comparison is tested, is decided here, and a join does
 * nothing else than look up, compare and bind.
 * old: a join found out at each tuple which variables were bound (an
 * environment's -1), bound them in a list to undo, and held the tests
 * met too soon; the mask of an atom's known columns made each time *)
type step =
  | Scan of scan
  | Test of D.literal (* a negation or a comparison, its variables bound *)

and scan = {
  atom : D.atom;
  from_new : bool;          (* the last round's new tuples only *)
  mask : int;               (* the columns known, a bit each: the index *)
  keys : (int * D.arg) array;   (* (column, value): those columns' *)
  binds : (int * int) list;     (* (column, slot): a variable it binds *)
  same : (int * int) list;      (* (column, slot): the same again, p(X, X) *)
}

(* the order of a body's atoms: after the one from the new tuples, the
 * atom with the most columns known (a constant, a variable an atom
 * before binds), a whole tuple known first (a membership test), the
 * order written on a tie; each test as soon as its variables are bound.
 * old: the order written, the new tuples' atom first: from new
 * point_to(X, L) tuples, assign_content(P, Q), point_to(Q, X),
 * point_to(X, L) scanned every assign_content for each one (rc's
 * analysis: 20 million lookups, 1.1 million now) *)
let plan (slots : int) (first : D.atom option) (body : D.literal list) : step list =
  let bound = Array.make slots false in
  let known (x : D.arg) : bool = match x with D.Const _ -> true | D.Slot k -> bound.(k) | D.Any -> false in
  let scan (a : D.atom) (from_new : bool) : step =
    let keys = ref [] and binds = ref [] and same = ref [] in
    Array.iteri
      (fun (i : int) (x : D.arg) ->
        match x with
        | D.Any -> ()
        | D.Slot k when not (known x) ->
            if List.exists (fun ((_, k') : int * int) -> k' = k) !binds then same := (i, k) :: !same
            else binds := (i, k) :: !binds
        | _ -> keys := (i, x) :: !keys)
      a.args;
    List.iter (fun ((_, k) : int * int) -> bound.(k) <- true) !binds;
    let keys = Array.of_list (List.rev !keys) in
    let mask = Array.fold_left (fun (m : int) ((i, _) : int * D.arg) -> m lor (1 lsl i)) 0 keys in
    Scan { atom = a; from_new; mask; keys; binds = !binds; same = !same } in
  let score (a : D.atom) : int * int =
    let n = Array.fold_left (fun (n : int) (x : D.arg) -> if known x then n + 1 else n) 0 a.args in
    ((if n = Array.length a.args then 1 else 0), n) in
  let ready (l : D.literal) : bool =
    match l with
    | D.Pos _ -> false
    | D.Neg a -> Array.for_all (fun (x : D.arg) -> x = D.Any || known x) a.args
    | D.Cmp (_, x, y) -> known x && known y in
  let rec next (tests : D.literal list) (atoms : D.atom list) : step list =
    let now, later = List.partition ready tests in
    let rest =
      match atoms with
      | [] -> [] (* (a rule is safe: no test is left) *)
      | a :: others ->
          let best = List.fold_left (fun (b : D.atom) (x : D.atom) -> if compare (score x) (score b) > 0 then x else b) a others in
          let s = scan best false in
          s :: next later (List.filter (fun (x : D.atom) -> x != best) atoms) in
    List.map (fun (l : D.literal) -> Test l) now @ rest in
  let atoms = List.filter_map (fun (l : D.literal) -> match l with D.Pos a -> Some a | _ -> None) body in
  let tests = List.filter (fun (l : D.literal) -> match l with D.Pos _ -> false | _ -> true) body in
  match first with
  | None -> next tests atoms
  | Some a ->
      let s = scan a true in
      s :: next tests atoms

(*****************************************************************************)
(* A plan run *)
(*****************************************************************************)

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

let value (env : int array) (x : D.arg) : int = match x with D.Const c -> c | D.Slot k -> env.(k) | D.Any -> -1

(* a negation's columns that are not _, a bit each *)
let known (a : D.atom) : int =
  let mask = ref 0 in
  Array.iteri (fun (i : int) (x : D.arg) -> if x <> D.Any then mask := !mask lor (1 lsl i)) a.args;
  !mask

let holds (p : D.t) (stats : stats) (env : int array) (l : D.literal) : bool =
  match l with
  | D.Pos _ -> true
  | D.Neg a ->
      (* (no tuple has those values in the columns that are not _) *)
      stats.lookups <- stats.lookups + 1;
      let mask = known a in
      let key = D.project mask (Array.map (value env) a.args) in
      if mask = 0 then a.rel.count = 0
      else if Array.length key = a.rel.arity then not (Tuples.mem a.rel.set key)
      else not (Hashtbl.mem (index a.rel mask) key)
  | D.Cmp (op, x, y) -> (
      let x = value env x and y = value env y in
      match op with
      | "=" | "==" -> x = y
      | "\\=" | "\\==" -> x <> y
      | _ -> (
          let c = Prolog.compare p.terms.(x) p.terms.(y) in
          match op with "<" -> c < 0 | ">" -> c > 0 | "=<" -> c <= 0 | _ -> c >= 0))

(* each way the steps hold together: [found] called with the variables
 * bound (a slot is read only after the step that binds it: nothing is
 * unbound) *)
let rec join (p : D.t) (stats : stats) (env : int array) (steps : step list) (found : unit -> unit) : unit =
  match steps with
  | [] -> found ()
  | Test l :: rest -> if holds p stats env l then join p stats env rest found
  | Scan s :: rest -> (
      stats.lookups <- stats.lookups + 1;
      let r = s.atom.rel in
      if s.from_new || s.mask = 0 then List.iter (scanned p stats env s rest found) (if s.from_new then r.delta else r.all)
      else
        let key = Array.map (fun ((_, x) : int * D.arg) -> value env x) s.keys in
        if Array.length key = r.arity then (if Tuples.mem r.set key then join p stats env rest found)
        else match Hashtbl.find_opt (index r s.mask) key with Some bucket -> List.iter (each p stats env s rest found) !bucket | None -> ())

(* a tuple of a scan with no index: its known columns compared *)
and scanned (p : D.t) (stats : stats) (env : int array) (s : scan) (rest : step list) (found : unit -> unit) (tuple : int array) : unit =
  if Array.for_all (fun ((i, x) : int * D.arg) -> tuple.(i) = value env x) s.keys then each p stats env s rest found tuple

(* a tuple that matches: its variables bound, the steps after *)
and each (p : D.t) (stats : stats) (env : int array) (s : scan) (rest : step list) (found : unit -> unit) (tuple : int array) : unit =
  List.iter (fun ((i, k) : int * int) -> env.(k) <- tuple.(i)) s.binds;
  if List.for_all (fun ((i, k) : int * int) -> tuple.(i) = env.(k)) s.same then join p stats env rest found

(*****************************************************************************)
(* A rule on several domains *)
(*****************************************************************************)

let jobs = ref 1

(* the domains that wait for a job, [job d] on each, the caller's 0 *)
type pool = {
  size : int;
  lock : Parallel.lock;
  start : Parallel.cond;
  finished : Parallel.cond;
  mutable job : int -> unit;
  mutable generation : int;     (* how many jobs were given *)
  mutable left : int;           (* the workers still at this one *)
  mutable stop : bool;
  mutable failed : exn option;
}

let worker (pool : pool) (d : int) () : unit =
  let seen = ref 0 in
  Parallel.take pool.lock;
  while not pool.stop do
    if pool.generation = !seen then Parallel.wait pool.start pool.lock
    else begin
      seen := pool.generation;
      let job = pool.job in
      Parallel.give pool.lock;
      let failed : exn option = try job d; None with e -> Some e in
      Parallel.take pool.lock;
      if failed <> None then pool.failed <- failed;
      pool.left <- pool.left - 1;
      if pool.left = 0 then Parallel.signal pool.finished
    end
  done;
  Parallel.give pool.lock

let pool_make (size : int) : pool =
  let pool : pool =
    { size; lock = Parallel.lock (); start = Parallel.cond (); finished = Parallel.cond (); job = (fun (_ : int) -> ());
      generation = 0; left = 0; stop = false; failed = None } in
  for d = 1 to size - 1 do
    Parallel.spawn (worker pool d)
  done;
  pool

(* [job] on every domain, back when all are done *)
let pool_run (pool : pool) (job : int -> unit) : unit =
  Parallel.take pool.lock;
  pool.job <- job;
  pool.generation <- pool.generation + 1;
  pool.left <- pool.size - 1;
  Parallel.broadcast pool.start;
  Parallel.give pool.lock;
  let mine : exn option = try job 0; None with e -> Some e in
  Parallel.take pool.lock;
  while pool.left > 0 do
    Parallel.wait pool.finished pool.lock
  done;
  let failed = if mine <> None then mine else pool.failed in
  pool.failed <- None;
  Parallel.give pool.lock;
  match failed with Some e -> raise e | None -> ()

let pool_stop (pool : pool) : unit =
  Parallel.take pool.lock;
  pool.stop <- true;
  Parallel.broadcast pool.start;
  Parallel.give pool.lock

let pool : pool option ref = ref None

(* the new tuples a domain takes at a time, and how many make a rule
 * worth sharing out *)
let chunk = 32
let shared = 4 * chunk

let rec at_least (n : int) (l : int array list) : bool = n <= 0 || match l with [] -> false | _ :: l -> at_least (n - 1) l

(* the indexes the steps will ask for, made now: on the domains they
 * are only read *)
let prepare (steps : step list) : unit =
  List.iter
    (fun (step : step) ->
      match step with
      | Scan s when (not s.from_new) && s.mask <> 0 && Array.length s.keys < s.atom.rel.arity -> ignore (index s.atom.rel s.mask)
      | Test (D.Neg a) ->
          let mask = known a in
          if mask <> 0 && mask <> (1 lsl a.rel.arity) - 1 then ignore (index a.rel mask)
      | _ -> ())
    steps

(* the new tuples of the first scan in chunks, taken by the domains in
 * turn; what each finds that is not there kept by chunk, and added by
 * the caller in the chunks' order, the same each time. The relations
 * are only read while the domains run. *)
let apply_shared (p : D.t) (stats : stats) (pool : pool) (rule : D.rule) (s : scan) (rest : step list) : unit =
  prepare rest;
  let delta = Array.of_list s.atom.rel.delta in
  let n = (Array.length delta + chunk - 1) / chunk in
  let next = Atomic.make 0 in
  let results : int array list array = Array.make n [] in
  let counts : stats array =
    Array.init pool.size (fun (_ : int) -> { rounds = 0; firings = 0; derived = 0; lookups = 0; profile = [] }) in
  pool_run pool (fun (d : int) ->
      let mine = counts.(d) in
      let env = Array.make rule.slots (-1) in
      let head (i : int) : int = value env rule.head.args.(i) in
      (* (what this domain found already: without it, a tuple found by
       * a thousand firings was a thousand candidates, which the caller
       * added one by one) *)
      let seen = Tuples.create (Array.length rule.head.args) in
      let c = ref (Atomic.fetch_and_add next 1) in
      while !c < n do
        let got : int array list ref = ref [] in
        for i = !c * chunk to min (Array.length delta) ((!c + 1) * chunk) - 1 do
          scanned p mine env s rest
            (fun () ->
              mine.firings <- mine.firings + 1;
              if not (Tuples.mem_by rule.head.rel.set head || Tuples.mem_by seen head) then begin
                let tuple = Array.map (value env) rule.head.args in
                ignore (Tuples.add seen tuple);
                got := tuple :: !got
              end)
            delta.(i)
        done;
        results.(!c) <- List.rev !got;
        c := Atomic.fetch_and_add next 1
      done);
  stats.lookups <- stats.lookups + 1;
  Array.iter
    (fun (c : stats) ->
      stats.firings <- stats.firings + c.firings;
      stats.lookups <- stats.lookups + c.lookups)
    counts;
  Array.iter
    (List.iter (fun (tuple : int array) ->
         if D.add rule.head.rel tuple then begin
           stats.derived <- stats.derived + 1;
           rule.head.rel.fresh <- tuple :: rule.head.rel.fresh
         end))
    results

(* a rule applied by one of its plans: the tuples it finds that were not
 * known are its head's fresh ones. Not at all if an atom has no tuple
 * (pointer.dl's assign_deref on an ML program: a lookup for each new
 * point_to, 1.7 million, found nothing) *)
let apply (p : D.t) (stats : stats) (rule : D.rule) (steps : step list) : unit =
  let empty (step : step) : bool =
    match step with
    | Scan s -> if s.from_new then s.atom.rel.delta = [] else s.atom.rel.count = 0
    | Test _ -> false in
  if not (List.exists empty steps) then begin
    let env = Array.make rule.slots (-1) in
    let head (i : int) : int = value env rule.head.args.(i) in
    let fired = stats.firings and added = stats.derived and looked = stats.lookups and t0 = Sys.time () in
    (match (!pool, steps) with
     | Some pool, Scan s :: rest when s.from_new && at_least shared s.atom.rel.delta ->
         apply_shared p stats pool rule s rest
     | _ ->
         join p stats env steps (fun () ->
             stats.firings <- stats.firings + 1;
             (* (most firings find their tuple there: asked before it is made) *)
             if not (Tuples.mem_by rule.head.rel.set head) then begin
               let tuple = Array.map (value env) rule.head.args in
               ignore (D.add rule.head.rel tuple);
               stats.derived <- stats.derived + 1;
               rule.head.rel.fresh <- tuple :: rule.head.rel.fresh
             end));
    let c =
      match List.assq_opt rule stats.profile with
      | Some c -> c
      | None ->
          let c = { fired = 0; added = 0; looked = 0; seconds = 0. } in
          stats.profile <- (rule, c) :: stats.profile;
          c in
    c.fired <- c.fired + stats.firings - fired;
    c.added <- c.added + stats.derived - added;
    c.looked <- c.looked + stats.lookups - looked;
    c.seconds <- c.seconds +. Sys.time () -. t0
  end

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

(* the body's plan with its k-th atom from the new tuples *)
let from_new (rule : D.rule) (k : int) (a : D.atom) : step list =
  plan rule.slots (Some a) (List.filteri (fun (i : int) (_ : D.literal) -> i <> k) rule.body)

let run ~(naive : bool) (p : D.t) : stats =
  let stats : stats = { rounds = 0; firings = 0; derived = 0; lookups = 0; profile = [] } in
  let top = stratify p in
  let rules = List.rev p.rule_list in
  if !jobs > 1 && Parallel.available then pool := Some (pool_make !jobs);
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
    (* each rule's plans: on everything; with each atom of this
     * stratum's relations from the new tuples *)
    let whole = List.map (fun (rule : D.rule) -> (rule, plan rule.slots None rule.body)) mine in
    let by_new =
      List.concat_map
        (fun (rule : D.rule) ->
          List.concat
            (List.mapi
               (fun (k : int) (l : D.literal) ->
                 match l with D.Pos a when a.rel.stratum = s && a.rel.rules > 0 -> [ (rule, from_new rule k a) ] | _ -> [])
               rule.body))
        mine in
    List.iter (fun ((rule, steps) : D.rule * step list) -> apply p stats rule steps) whole;
    while turn () do
      List.iter (fun ((rule, steps) : D.rule * step list) -> apply p stats rule steps) (if naive then whole else by_new)
    done;
    List.iter (fun (r : D.relation) -> r.delta <- []) heads
  done;
  (match !pool with Some pl -> pool_stop pl; pool := None | None -> ());
  stats

let answers (p : D.t) (q : D.query) : string list =
  let stats : stats = { rounds = 0; firings = 0; derived = 0; lookups = 0; profile = [] } in
  let env = Array.make (Array.length q.names) (-1) in
  let found : string list ref = ref [] in
  join p stats env (plan (Array.length q.names) None [ D.Pos q.goal ]) (fun () ->
      found := D.show p q.goal.rel (Array.map (value env) q.goal.args) :: !found);
  List.sort_uniq String.compare !found
