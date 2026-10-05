(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Lalr.mli *)

type symbol = T of int | N of int
type action = Shift of int | Reduce of int | Accept | Fail

type t = {
  terms : string array;
  nonterms : string array;
  rules : (int * symbol array) array;
  nrules : int;
  kernels : (int * int) list array;
  actions : action array array;
  defaults : action array;
  gotos : int array array;
  starts : int list;
  sr : int; rr : int;
}

let error (r : Yacc.rule) fmt = Printf.ksprintf (fun m -> raise (Yacc.Error (r.rline, m))) fmt

let index (a : string array) x = let rec go i = if i = Array.length a then -1 else if a.(i) = x then i else go (i + 1) in go 0

(* a set of terminals as flags; a's taken into b, whether b grew *)
let union (a : Bytes.t) (b : Bytes.t) =
  let grew = ref false in
  Bytes.iteri (fun i c -> if c = '\001' && Bytes.get b i = '\000' then begin Bytes.set b i '\001'; grew := true end) a;
  !grew

let make (g : Yacc.t) : t =
  (*-------------------------------------------------------------------------*)
  (* The symbols and the rules *)
  (*-------------------------------------------------------------------------*)
  let declared = List.map fst g.tokens in
  let only_prec = List.filter (fun x -> not (List.mem x declared)) (List.concat_map snd g.precs) in
  let terms = Array.of_list (("$end" :: declared) @ only_prec) in
  let nonterms = Array.of_list (List.fold_left (fun acc (r : Yacc.rule) -> if List.mem r.lhs acc then acc else acc @ [ r.lhs ]) [] g.rules) in
  let nt = Array.length terms and nn = Array.length nonterms in
  let symbol (r : Yacc.rule) x =
    match index nonterms x, index terms x with
    | n, _ when n >= 0 -> N n
    | _, t when t >= 0 -> T t
    | _ -> error r "%s: no token and no rule of that name" x
  in
  let nrules = List.length g.rules in
  let starts = List.map (fun s -> match index nonterms s with -1 -> raise (Yacc.Error (0, s ^ ": %start, without a rule")) | n -> n) g.starts in
  let rules = Array.of_list (
    List.map (fun (r : Yacc.rule) -> index nonterms r.lhs, Array.of_list (List.map (symbol r) r.rhs)) g.rules
    @ List.mapi (fun k s -> -1 - k, [| N s |]) starts) in
  (* a token's precedence (its line's rank, from 1) and associativity; a
   * rule's: %prec's token's, else its last terminal's *)
  let token_prec = Array.make nt (0, Yacc.Nonassoc) in
  List.iteri (fun level (assoc, names) -> List.iter (fun x -> token_prec.(index terms x) <- (level + 1, assoc)) names) g.precs;
  let rule_prec = Array.make (Array.length rules) 0 in
  List.iteri (fun i (r : Yacc.rule) ->
    rule_prec.(i) <-
      (match r.prec with
       | Some x -> (match index terms x with -1 -> error r "%%prec %s: no such token" x | t -> fst token_prec.(t))
       | None -> Array.fold_left (fun p s -> match s with T t -> fst token_prec.(t) | N _ -> p) 0 (snd rules.(i)))) g.rules;
  let by_lhs = Array.make nn [] in
  Array.iteri (fun i (lhs, _) -> if lhs >= 0 then by_lhs.(lhs) <- by_lhs.(lhs) @ [ i ]) rules;
  (*-------------------------------------------------------------------------*)
  (* What a non-terminal may be: nothing, and its first terminals *)
  (*-------------------------------------------------------------------------*)
  let nullable = Array.make nn false and first = Array.init nn (fun _ -> Bytes.make nt '\000') in
  (* the first terminals of the symbols from the dot into set; whether they may all be nothing *)
  let first_of (rhs : symbol array) dot set =
    let rec go i grew =
      if i = Array.length rhs then true, grew
      else match rhs.(i) with
        | T t -> let g = Bytes.get set t = '\000' in Bytes.set set t '\001'; false, grew || g
        | N n -> let g = union first.(n) set in if nullable.(n) then go (i + 1) (grew || g) else false, grew || g
    in
    go dot false
  in
  let changed = ref true in
  while !changed do
    changed := false;
    Array.iter (fun (lhs, rhs) ->
      if lhs >= 0 then begin
        let all, grew = first_of rhs 0 first.(lhs) in
        if grew || (all && not nullable.(lhs)) then changed := true;
        if all then nullable.(lhs) <- true
      end) rules
  done;
  (*-------------------------------------------------------------------------*)
  (* The LR(0) states *)
  (*-------------------------------------------------------------------------*)
  let after (rule, dot) = let rhs = snd rules.(rule) in if dot < Array.length rhs then Some rhs.(dot) else None in
  (* the kernel's items and those of the non-terminals after a dot *)
  let closure kernel =
    let seen = Hashtbl.create 64 and out = ref [] in
    let rec add item =
      if not (Hashtbl.mem seen item) then begin
        Hashtbl.replace seen item ();
        out := item :: !out;
        match after item with Some (N n) -> List.iter (fun r -> add (r, 0)) by_lhs.(n) | _ -> ()
      end
    in
    List.iter add kernel;
    List.rev !out
  in
  let ids = Hashtbl.create 512 and kernels = ref [] and count = ref 0 and todo = Queue.create () in
  let state kernel =
    let kernel = List.sort compare kernel in
    match Hashtbl.find_opt ids kernel with
    | Some id -> id
    | None -> let id = !count in incr count; Hashtbl.replace ids kernel id; kernels := kernel :: !kernels; Queue.push (id, kernel) todo; id
  in
  let start_states = List.mapi (fun k _ -> state [ (nrules + k, 0) ]) starts in
  (* each state's items, and where it goes on a symbol *)
  let items = Hashtbl.create 512 and trans = Hashtbl.create 512 in
  while not (Queue.is_empty todo) do
    let id, kernel = Queue.pop todo in
    let all = closure kernel in
    Hashtbl.replace items id all;
    let symbols = List.fold_left (fun acc item -> match after item with Some s when not (List.mem s acc) -> acc @ [ s ] | _ -> acc) [] all in
    Hashtbl.replace trans id (List.map (fun s ->
      s, state (List.filter_map (fun (r, d) -> if after (r, d) = Some s then Some (r, d + 1) else None) all)) symbols)
  done;
  let nstates = !count in
  let kernels = Array.of_list (List.rev !kernels) in
  (*-------------------------------------------------------------------------*)
  (* The lookaheads *)
  (*-------------------------------------------------------------------------*)
  let la = Hashtbl.create 4096 in
  let look s item = match Hashtbl.find_opt la (s, item) with Some b -> b | None -> let b = Bytes.make nt '\000' in Hashtbl.replace la (s, item) b; b in
  List.iteri (fun k s -> Bytes.set (look s (nrules + k, 0)) 0 '\001') start_states;
  changed := true;
  while !changed do
    changed := false;
    for s = 0 to nstates - 1 do
      List.iter (fun (rule, dot) ->
        let mine = look s (rule, dot) in
        match after (rule, dot) with
        | None -> ()
        | Some sym ->
            (* the same item in the next state *)
            if union mine (look (List.assoc sym (Hashtbl.find trans s)) (rule, dot + 1)) then changed := true;
            (match sym with
             | T _ -> ()
             | N n ->
                 (* what may follow n here: the rest's first terminals, and the item's own if the rest may be nothing *)
                 let follow = Bytes.make nt '\000' in
                 let all, _ = first_of (snd rules.(rule)) (dot + 1) follow in
                 if all then ignore (union mine follow);
                 List.iter (fun r -> if union follow (look s (r, 0)) then changed := true) by_lhs.(n))) (Hashtbl.find items s)
    done
  done;
  (*-------------------------------------------------------------------------*)
  (* The actions *)
  (*-------------------------------------------------------------------------*)
  let sr = ref 0 and rr = ref 0 in
  let actions = Array.init nstates (fun _ -> Array.make nt Fail) and defaults = Array.make nstates Fail in
  let gotos = Array.init nstates (fun _ -> Array.make nn (-1)) in
  let reduction r = if r >= nrules then Accept else Reduce r in
  for s = 0 to nstates - 1 do
    let moves = Hashtbl.find trans s in
    List.iter (fun (sym, target) -> match sym with N n -> gotos.(s).(n) <- target | T _ -> ()) moves;
    (* the rules at their end here, the earlier first *)
    let ended = List.sort compare (List.filter_map (fun (r, d) -> if after (r, d) = None then Some r else None) (Hashtbl.find items s)) in
    let kept = ref [] in
    for t = 0 to nt - 1 do
      let reduces = List.filter (fun r -> Bytes.get (look s (r, Array.length (snd rules.(r)))) t = '\001') ended in
      let shift = List.assoc_opt (T t) moves in
      (* yacc's choice: the shift if any, else the earliest rule; then each
       * other reduction against it *)
      let action =
        match shift, reduces with
        | None, [] -> Fail
        | Some target, _ ->
            List.fold_left (fun (pref : action) r ->
              match pref with
              | Shift _ ->
                  let tp, assoc = token_prec.(t) and rp = rule_prec.(r) in
                  if tp = 0 || rp = 0 then (incr sr; pref)
                  else if tp < rp then reduction r
                  else if tp > rp then pref
                  else (match assoc with Left -> reduction r | Right -> pref | Nonassoc -> Fail)
              | Fail -> Fail                      (* neither, by a %nonassoc *)
              | Reduce _ | Accept -> incr rr; pref) (Shift target) reduces
        | None, r :: others -> List.iter (fun _ -> incr rr) others; reduction r
      in
      actions.(s).(t) <- action;
      (match action with Reduce _ | Accept -> if not (List.mem action !kept) then kept := action :: !kept | _ -> ())
    done;
    (* no shift left (a precedence may have taken them all) and one rule: the default *)
    if not (Array.exists (fun (a : action) -> match a with Shift _ -> true | _ -> false) actions.(s)) then
      (match !kept with [ a ] -> defaults.(s) <- a | _ -> ())
  done;
  { terms; nonterms; rules; nrules; kernels; actions; defaults; gotos; starts = start_states; sr = !sr; rr = !rr }
