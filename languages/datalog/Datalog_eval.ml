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
  (* the two lists again, as arrays of columns and of slots: walked by a
   * loop at each tuple, where a List.iter called a closure (Compile_il
   * reads the lists) *)
  bind_at : int array;
  bind_to : int array;
  same_at : int array;
  same_to : int array;
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
    let cols (l : (int * int) list) : int array = Array.of_list (List.map fst l) in
    let slots (l : (int * int) list) : int array = Array.of_list (List.map snd l) in
    Scan
      { atom = a; from_new; mask; keys; binds = !binds; same = !same; bind_at = cols !binds; bind_to = slots !binds;
        same_at = cols !same; same_to = slots !same } in
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

(* (a top-level loop: List.find_opt's closure was made at each lookup,
 * 31 million on mini-scheme's Andersen) *)
let rec find_index (mask : int) (l : (int * Index.t) list) : Index.t option =
  match l with [] -> None | (m, index) :: rest -> if m = mask then Some index else find_index mask rest

(* the index of a relation by some columns, made if it is not there *)
let index (r : D.relation) (mask : int) : Index.t =
  (* (not List.assoc_opt: its compare is the polymorphic one, a call
   * into the runtime at each lookup, 2.3 million on mini-datalog's
   * facts) *)
  match find_index mask r.indexes with
  | Some index -> index
  | None ->
      let index = Index.create ~sorted:(Relset.sorted r.set) r.arity (D.columns r.arity mask) in
      for id = 0 to r.count - 1 do
        Index.add index (D.get r id) id
      done;
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
      if mask = 0 then a.rel.count = 0
      else if mask = (1 lsl a.rel.arity) - 1 then not (Relset.mem_by a.rel.set (fun (i : int) -> value env a.args.(i)))
      else
        let cols = D.columns a.rel.arity mask in
        not (Index.exists (index a.rel mask) (fun (i : int) -> value env a.args.(cols.(i))))
  | D.Cmp (op, x, y) -> (
      let x = value env x and y = value env y in
      match op with
      | "=" | "==" -> x = y
      | "\\=" | "\\==" -> x <> y
      | _ -> (
          let c = Prolog.compare p.terms.(x) p.terms.(y) in
          match op with "<" -> c < 0 | ">" -> c > 0 | "=<" -> c <= 0 | _ -> c >= 0))

(* a column's place in a row: its own *)
let same_place : int array = Array.init 63 (fun (c : int) -> c)

(* each way the steps hold together: [found] called with the variables
 * bound (a slot is read only after the step that binds it: nothing is
 * unbound) *)
let rec join (p : D.t) (stats : stats) (env : int array) (steps : step list) (found : unit -> unit) : unit =
  match steps with
  | [] -> found ()
  | Test l :: rest -> if holds p stats env l then join p stats env rest found
  | Scan s :: rest ->
      stats.lookups <- stats.lookups + 1;
      let r = s.atom.rel in
      if s.from_new || s.mask = 0 then begin
        let lo, hi = if s.from_new then (r.delta_from, r.delta_to) else (0, r.count) in
        for id = lo to hi - 1 do
          scanned p stats env s rest found id
        done
      end
      else begin
        (* the key's values in an array, made at each lookup (not kept in
         * the plan: the domains share it), read by a loop where the key
         * was a closure called for each column by the hash and the
         * compare (old: Relset.mem_by r.set key, and Index.iter index
         * r.rows r.arity key (fun keys base -> each ... keys base at)
         * for both kinds of index; mini-cc's Andersen 46 s, ...) *)
        let keys = s.keys in
        let n = Array.length keys in
        (* (a literal array for a key of 1 to 3 columns: made in place,
         * where Array.make is a call into the runtime, caml_make_vect,
         * 6% of mini-scheme's instructions) *)
        let k =
          match n with
          | 1 -> [| value env (snd keys.(0)) |]
          | 2 -> [| value env (snd keys.(0)); value env (snd keys.(1)) |]
          | 3 -> [| value env (snd keys.(0)); value env (snd keys.(1)); value env (snd keys.(2)) |]
          | _ -> Array.init n (fun (i : int) -> value env (snd keys.(i))) in
        if n = r.arity then (if Relset.mem_array r.set k then join p stats env rest found)
        else
          let index = index r s.mask in
          (* (a relation's indexes are of its set's kind) *)
          if not (Relset.sorted r.set) then begin
            let rows = r.rows and arity = r.arity in
            let id = ref (Index.first_array index k) in
            while !id >= 0 do
              each p stats env s rest found rows (!id * arity) same_place;
              id := Index.next index !id
            done
          end
          else
            let at = Index.at index in
            let key (i : int) : int = k.(i) in
            Index.iter index r.rows r.arity key (fun (keys : int array) (base : int) -> each p stats env s rest found keys base at)
      end

(* a tuple of a scan with no index, by its number: its known columns
 * compared (old: Array.for_all of a closure) *)
and scanned (p : D.t) (stats : stats) (env : int array) (s : scan) (rest : step list) (found : unit -> unit) (id : int) : unit =
  let r = s.atom.rel in
  let rows = r.rows and base = id * r.arity and keys = s.keys in
  let i = ref 0 and n = Array.length keys in
  while !i < n && rows.(base + fst keys.(!i)) = value env (snd keys.(!i)) do
    incr i
  done;
  if !i = n then each p stats env s rest found rows base same_place

(* a tuple that matches, column c at keys.(base + at.(c)) (a row, or an
 * index's leaf): its variables bound, the steps after (old: List.iter and
 * List.for_all of closures over s.binds and s.same) *)
and each (p : D.t) (stats : stats) (env : int array) (s : scan) (rest : step list) (found : unit -> unit) (keys : int array)
    (base : int) (at : int array) : unit =
  let bind_at = s.bind_at and bind_to = s.bind_to in
  for j = 0 to Array.length bind_at - 1 do
    env.(bind_to.(j)) <- keys.(base + at.(bind_at.(j)))
  done;
  let same_at = s.same_at and same_to = s.same_to in
  let j = ref 0 and n = Array.length same_at in
  while !j < n && keys.(base + at.(same_at.(!j))) = env.(same_to.(!j)) do
    incr j
  done;
  if !j = n then join p stats env rest found

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

(* the tuples found, added by the domains: each adds to the set those
 * of its own parts, then the rows are added in turn, then each adds to
 * an index the keys of its own parts (a part's hash first computed by
 * slices). Each part sees the tuples in their order, so this is D.add
 * of each in turn. *)
let add_shared (pool : pool) (r : D.relation) (found : int array array) : int =
  let m = Array.length found and size = pool.size in
  let slice (d : int) (m : int) : int * int = (d * m / size, (d + 1) * m / size) in
  let part = Array.make m 0 in
  pool_run pool (fun (d : int) ->
      let lo, hi = slice d m in
      for i = lo to hi - 1 do
        let tuple = found.(i) in
        part.(i) <- Relset.part_of r.set (fun (j : int) -> tuple.(j))
      done);
  let fresh = Array.make m false in
  pool_run pool (fun (d : int) ->
      for i = 0 to m - 1 do
        if part.(i) mod size = d then begin
          let tuple = found.(i) in
          fresh.(i) <- Relset.add r.set tuple
        end
      done);
  let first = r.count in
  Array.iteri (fun (i : int) (tuple : int array) -> if fresh.(i) then ignore (D.append r tuple)) found;
  let added = r.count - first in
  List.iter
    (fun ((_, index) : int * Index.t) ->
      Index.reserve index r.count;
      let part = Array.make added 0 in
      pool_run pool (fun (d : int) ->
          let lo, hi = slice d added in
          for k = lo to hi - 1 do
            part.(k) <- Index.part_of index (D.get r (first + k))
          done);
      pool_run pool (fun (d : int) ->
          for k = 0 to added - 1 do
            if part.(k) mod size = d then Index.add index (D.get r (first + k)) (first + k)
          done))
    r.indexes;
  added

(* what a rule found added after its join, not during it: a tree's
 * range may not change while it is walked (Souffle's rounds, likewise,
 * write their new tuples apart from those they read). On the domains
 * when there are enough. *)
let add_found (stats : stats) (r : D.relation) (found : int array array) : unit =
  match !pool with
  | Some pool when Array.length found >= shared -> stats.derived <- stats.derived + add_shared pool r found
  | _ -> Array.iter (fun (tuple : int array) -> if D.add r tuple then stats.derived <- stats.derived + 1) found

(* the new tuples of the first scan in chunks, taken by the domains in
 * turn; what each finds that is not there kept by chunk, and added in
 * the chunks' order, the same each time. The relations
 * are only read while the domains run. *)
let apply_shared (p : D.t) (stats : stats) (pool : pool) (rule : D.rule) (s : scan) (rest : step list) : unit =
  prepare rest;
  let lo = s.atom.rel.delta_from and hi = s.atom.rel.delta_to in
  let n = (hi - lo + chunk - 1) / chunk in
  let next = Atomic.make 0 in
  let results : int array list array = Array.make n [] in
  let none : stats = { rounds = 0; firings = 0; derived = 0; lookups = 0; profile = [] } in
  let counts : stats array = Array.make pool.size none in
  pool_run pool (fun (d : int) ->
      (* (its counts made here, on its own domain, and given at the
       * end: made by the caller, the domains' records are side by side,
       * several in a line of the cache, which each firing's count
       * would pass from core to core; measured, no difference here) *)
      let mine : stats = { rounds = 0; firings = 0; derived = 0; lookups = 0; profile = [] } in
      let env = Array.make rule.slots (-1) in
      let head (i : int) : int = value env rule.head.args.(i) in
      (* (what this domain found already: without it, a tuple found by
       * a thousand firings was a thousand candidates, which the caller
       * added one by one) *)
      let seen = Tuples.create (Array.length rule.head.args) and h = Relset.hint rule.head.rel.set in
      let c = ref (Atomic.fetch_and_add next 1) in
      while !c < n do
        let got : int array list ref = ref [] in
        for id = lo + (!c * chunk) to min hi (lo + ((!c + 1) * chunk)) - 1 do
          scanned p mine env s rest
            (fun () ->
              mine.firings <- mine.firings + 1;
              if not (Relset.mem_hint rule.head.rel.set h head || Tuples.mem_by seen head) then begin
                let tuple = Array.map (value env) rule.head.args in
                ignore (Tuples.add seen tuple);
                got := tuple :: !got
              end)
            id
        done;
        results.(!c) <- List.rev !got;
        c := Atomic.fetch_and_add next 1
      done;
      counts.(d) <- mine);
  stats.lookups <- stats.lookups + 1;
  Array.iter
    (fun (c : stats) ->
      stats.firings <- stats.firings + c.firings;
      stats.lookups <- stats.lookups + c.lookups)
    counts;
  let all = Array.make (Array.fold_left (fun (n : int) (l : int array list) -> n + List.length l) 0 results) [||] in
  let k = ref 0 in
  Array.iter (List.iter (fun (tuple : int array) -> all.(!k) <- tuple; incr k)) results;
  add_found stats rule.head.rel all

(* a rule applied by one of its plans: the tuples it finds that were not
 * known are added to its head, this round's new ones. Not at all if an
 * atom has no tuple (pointer.dl's assign_deref on an ML program: a lookup for each new
 * point_to, 1.7 million, found nothing) *)
let clock : (unit -> float) ref = ref (fun () -> 0.)

let apply (p : D.t) (stats : stats) (rule : D.rule) (steps : step list) : unit =
  let empty (step : step) : bool =
    match step with
    | Scan s -> if s.from_new then s.atom.rel.delta_from = s.atom.rel.delta_to else s.atom.rel.count = 0
    | Test _ -> false in
  if not (List.exists empty steps) then begin
    let env = Array.make rule.slots (-1) in
    let head (i : int) : int = value env rule.head.args.(i) in
    let fired = stats.firings and added = stats.derived and looked = stats.lookups and t0 = !clock () in
    (match (!pool, steps) with
     | Some pool, Scan s :: rest when s.from_new && s.atom.rel.delta_to - s.atom.rel.delta_from >= shared ->
         apply_shared p stats pool rule s rest
     | _ when not (Relset.sorted rule.head.rel.set) ->
         (* a hashed head: each tuple added as found (a hash's slots and
          * chains do not move under a walk) *)
         let r = rule.head.rel in
         (* the head's values into one array, tested, and added (copied)
          * if new (old: Relset.mem_hint r.set h head, the head a closure
          * called for each column, then Array.map (value env) of it) *)
         let args = rule.head.args in
         let n = Array.length args in
         let tuple = Array.make n 0 in
         join p stats env steps (fun () ->
             stats.firings <- stats.firings + 1;
             for i = 0 to n - 1 do
               tuple.(i) <- value env args.(i)
             done;
             if D.add r tuple then stats.derived <- stats.derived + 1)
     | _ ->
         let r = rule.head.rel in
         let seen = Tuples.create r.arity and got = ref [] and h = Relset.hint r.set in
         join p stats env steps (fun () ->
             stats.firings <- stats.firings + 1;
             (* (most firings find their tuple there: asked before it is made) *)
             if not (Relset.mem_hint r.set h head || Tuples.mem_by seen head) then begin
               let tuple = Array.map (value env) rule.head.args in
               ignore (Tuples.add seen tuple);
               got := tuple :: !got
             end);
         add_found stats r (Array.of_list (List.rev !got)));
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
    c.seconds <- c.seconds +. !clock () -. t0
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
    (* a round's end: the tuples added in it, numbered from delta_to on,
     * are the next one's new ones (Souffle's relations new, delta and
     * full are here three ranges of the same rows) *)
    let since (r : D.relation) (from : int) : unit =
      r.delta_from <- from;
      r.delta_to <- r.count in
    List.iter (fun (r : D.relation) -> since r r.count) heads;
    let turn () : bool =
      let any = ref false in
      List.iter
        (fun (r : D.relation) ->
          if r.count > r.delta_to then any := true;
          since r r.delta_to)
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
    List.iter (fun (r : D.relation) -> since r r.count) heads
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
