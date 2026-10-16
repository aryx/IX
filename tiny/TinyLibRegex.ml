(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibRegex.mli *)

type re =
  | Byte of (char -> bool)            (* a byte that it says yes to *)
  | Bol | Eol
  | Seq of re * re | Alt of re * re
  | Star of re | Plus of re | Opt of re
  | Empty

(* the expression of a pattern, by recursive descent: either := seq
 * ('|' seq)*, seq := repeat*, repeat := atom ('*' | '+' | '?')* *)
let parse pattern =
  let n = String.length pattern and at = ref 0 in
  let peek () = if !at < n then Some pattern.[!at] else None in
  let next () = let c = pattern.[!at] in incr at; c in
  (* a class's byte, a backslash quoting the next *)
  let class_byte () =
    if !at >= n then failwith "malformed []";
    let c = next () in
    if c = '\\' && !at < n then next () else c in
  (* an alternative, or a group, must have something in it *)
  let some what e = match e with Empty -> failwith ("missing operand for " ^ what) | _ -> e in
  let rec either () =
    let e = seq Empty in
    if peek () = Some '|' then begin ignore (next ()); Alt (some "|" e, some "|" (either ())) end else e
  and seq e =
    match peek () with
    | None -> e
    | Some c when c = '|' || c = ')' -> e
    | Some _ -> let r = repeat (atom ()) in seq (match e with Empty -> r | _ -> Seq (e, r))
  and repeat e =
    match peek () with
    | Some '*' -> ignore (next ()); repeat (Star e)
    | Some '+' -> ignore (next ()); repeat (Plus e)
    | Some '?' -> ignore (next ()); repeat (Opt e)
    | _ -> e
  and atom () =
    match next () with
    | '(' -> let e = some "(" (either ()) in if peek () <> Some ')' then failwith "missing )"; ignore (next ()); e
    | ')' -> failwith "unmatched )"
    | '*' | '+' | '?' -> failwith "nothing to repeat"
    | '.' -> Byte (fun _ -> true)
    | '^' -> Bol
    | '$' -> Eol
    | '[' ->
        let negated = peek () = Some '^' in
        if negated then ignore (next ());
        (* the ranges, a byte being a range of one; none, or a - with
         * nothing after it, is malformed *)
        let rec ranges acc =
          if peek () = Some ']' then begin
            ignore (next ());
            if acc = [] then failwith "malformed []";
            acc
          end
          else begin
            if peek () = Some '-' then failwith "malformed []";
            let lo = class_byte () in
            if peek () = Some '-' then begin
              ignore (next ());
              if peek () = Some ']' then failwith "malformed []";
              let hi = class_byte () in ranges ((lo, hi) :: acc)
            end
            else ranges ((lo, lo) :: acc)
          end in
        let rs = ranges [] in
        Byte (fun b -> List.exists (fun (lo, hi) -> b >= lo && b <= hi) rs <> negated)
    | '\\' -> if !at >= n then failwith "a \\ at the end" else let c = next () in Byte (fun b -> b = c)
    | c -> Byte (fun b -> b = c) in
  let e = either () in
  if !at < n then failwith "unmatched )";
  e

(* the automaton's states: each says what leads out of it *)
type state = { mutable edge : edge; mutable mark : int }
and edge =
  | Step of (char -> bool) * state    (* over a byte it says yes to *)
  | Split of state * state            (* to both, without reading *)
  | AtBol of state | AtEol of state   (* to it, at a line's start, end *)
  | Matched

type regex = state

let state edge = { edge = edge; mark = -1 }

(* [build e next]: the states of e, ending where next starts; a loop is a
 * Split made first, then pointed at its body, which ends at it *)
let rec build e next =
  match e with
  | Empty -> next
  | Byte ok -> state (Step (ok, next))
  | Bol -> state (AtBol next)
  | Eol -> state (AtEol next)
  | Seq (a, b) -> build a (build b next)
  | Alt (a, b) -> state (Split (build a next, build b next))
  | Opt a -> state (Split (build a next, next))
  | Star a -> let loop = state Matched in loop.edge <- Split (build a loop, next); loop
  | Plus a -> let loop = state Matched in let body = build a loop in loop.edge <- Split (body, next); body

(* each step of a match marks the states it puts in its set, so that a
 * state is put in it once *)
let generation = ref 0

(* whether the automaton from start matches somewhere in line *)
let matches start line =
  let n = String.length line in
  (* the set with s, and the states s leads to without reading *)
  let rec add at set s =
    if s.mark = !generation then set
    else begin
      s.mark <- !generation;
      match s.edge with
      | Split (a, b) -> add at (add at set a) b
      | AtBol t -> if at = 0 then add at set t else set
      | AtEol t -> if at = n then add at set t else set
      | _ -> s :: set
    end in
  let matched set = List.exists (fun s -> match s.edge with Matched -> true | _ -> false) set in
  (* a match may start at any byte: start is added at each one *)
  let rec run at set =
    if matched set then true
    else if at >= n then false
    else begin
      incr generation;
      let c = line.[at] in
      let set = List.fold_left (fun next s -> match s.edge with Step (ok, t) when ok c -> add (at + 1) next t | _ -> next) [] set in
      run (at + 1) (add (at + 1) set start)
    end in
  incr generation;
  run 0 (add 0 [] start)

let compile pattern = build (parse pattern) (state Matched)
