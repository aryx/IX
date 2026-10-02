(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Dfa.mli *)

type t = { trans : int array array; accept : int array; starts : int list }

(* a state of the nondeterministic automaton: where it goes for free,
 * where on a character of a set, and the clause it ends *)
type nstate = { mutable eps : int list; mutable on : (string * int) option; mutable ends : int }

let make (rules : Lex.rule list) : t =
  let nfa = ref [||] and n = ref 0 in
  let fresh () =
    if !n = Array.length !nfa then nfa := Array.append !nfa (Array.init (max 64 !n) (fun _ -> { eps = []; on = None; ends = -1 }));
    incr n;
    !n - 1
  in
  let eps a b = !nfa.(a).eps <- b :: !nfa.(a).eps in
  (* r between two states *)
  let rec build (r : Lex.regexp) a b =
    match r with
    | Chars set -> let s = fresh () in eps a s; !nfa.(s).on <- Some (set, b)
    | Eps -> eps a b
    | Seq (x, y) -> let m = fresh () in build x a m; build y m b
    | Alt (x, y) -> build x a b; build y a b
    | Star x -> let m = fresh () in eps a m; eps m b; build x m m
    | Bind (_, x) -> build x a b
  in
  let rule (r : Lex.rule) =
    let start = fresh () in
    List.iteri (fun k (c : Lex.clause) -> let last = fresh () in !nfa.(last).ends <- k; build c.re start last) r.clauses;
    start
  in
  let starts = List.map rule rules in
  (* the states reached for free from those of a set, sorted *)
  let closure set =
    let seen = Hashtbl.create 64 in
    let rec visit s = if not (Hashtbl.mem seen s) then begin Hashtbl.replace seen s (); List.iter visit !nfa.(s).eps end in
    List.iter visit set;
    List.sort compare (Hashtbl.fold (fun s () acc -> s :: acc) seen [])
  in
  (* the deterministic states, by their set; those not yet looked at *)
  let ids = Hashtbl.create 256 and sets = ref [] and count = ref 0 and todo = Queue.create () in
  let state set =
    match Hashtbl.find_opt ids set with
    | Some id -> id
    | None -> let id = !count in incr count; Hashtbl.replace ids set id; sets := set :: !sets; Queue.push (id, set) todo; id
  in
  let starts = List.map (fun s -> state (closure [ s ])) starts in
  let rows = ref [] in
  while not (Queue.is_empty todo) do
    let id, set = Queue.pop todo in
    let moves = List.filter_map (fun s -> !nfa.(s).on) set in
    let row = Array.init 257 (fun c ->
      match List.filter_map (fun (chars, target) -> if chars.[c] = '\001' then Some target else None) moves with
      | [] -> -1
      | targets -> state (closure targets)) in
    let ends = List.fold_left (fun best s -> let e = !nfa.(s).ends in if e >= 0 && (best < 0 || e < best) then e else best) (-1) set in
    rows := (id, row, ends) :: !rows
  done;
  let trans = Array.make !count [||] and accept = Array.make !count (-1) in
  List.iter (fun (id, row, ends) -> trans.(id) <- row; accept.(id) <- ends) !rows;
  { trans; accept; starts }
