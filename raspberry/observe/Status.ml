(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Status.mli *)

open Common

type cpu = { pc : int64; user : bool; label : string; ran : int; waited : int }

type t = {
  every : float;
  symbols : (int64 * string) array;   (* by address, unsigned *)
  start : float;
  mutable last : float;
  mutable last_now : int;
  counts : (string, int) Hashtbl.t;   (* the instructions run, by place *)
  mutable busy : int;
  mutable idle : int;
  mutable waiting : string;           (* the last idle sample's place *)
}

let create ~every ~symbols =
  let symbols = Array.of_list symbols in
  Array.sort (fun (a, _) (b, _) -> Int64.unsigned_compare a b) symbols;
  let now = Unix.gettimeofday () in
  { every; symbols; start = now; last = now; last_now = 0; counts = Hashtbl.create 64; busy = 0; idle = 0; waiting = "" }

(* the symbol at or below [pc], and the offset from it *)
let name t pc =
  let lo = ref 0 and hi = ref (Array.length t.symbols) in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if Int64.unsigned_compare (fst t.symbols.(mid)) pc <= 0 then lo := mid + 1 else hi := mid
  done;
  if !lo = 0 then None else let a, n = t.symbols.(!lo - 1) in Some (n, Int64.sub pc a)

(* a user program's PC as is (the kernel's symbols are not its); a
 * kernel's as its function, the offset only in [precise] *)
let place t ~precise (c : cpu) =
  let where = match c.user, name t c.pc with
    | false, Some (n, off) -> if precise then Printf.sprintf "%s+0x%Lx" n off else n
    | true, _ -> Printf.sprintf "(user) 0x%Lx" c.pc
    | false, None -> Printf.sprintf "0x%Lx" c.pc in
  c.label ^ " " ^ where

let sample t cpus =
  List.iter (fun (c : cpu) ->
    if c.waited > 0 then (t.idle <- t.idle + c.waited; t.waiting <- place t ~precise:true c);
    if c.ran > 0 then begin
      t.busy <- t.busy + c.ran;
      (* a user program's samples as one, whatever its PC *)
      let k = if c.user then c.label ^ " (user)" else place t ~precise:false c in
      Hashtbl.replace t.counts k (c.ran + (Hashtbl.find_opt t.counts k ||| 0))
    end) cpus

let report t ~now =
  let host = Unix.gettimeofday () in
  if host -. t.last < t.every then None
  else begin
    let total = max 1 (t.busy + t.idle) in
    let pct n = 100 * n / total in
    let top = List.sort (fun (_, a) (_, b) -> compare b a) (Hashtbl.fold (fun k n acc -> (k, n) :: acc) t.counts []) in
    let top = List.filteri (fun i (_, n) -> i < 4 && pct n > 0) top in
    let busy = String.concat ", " (List.map (fun (k, n) -> Printf.sprintf "%d%% %s" (pct n) k) top) in
    let line = Printf.sprintf "[%.0fs] board %.1fs (+%.1fs), idle %d%%%s%s"
      (host -. t.start) (float_of_int now /. 1e6) (float_of_int (now - t.last_now) /. 1e6) (pct t.idle)
      (if busy = "" then "" else ": " ^ busy)
      (if t.idle > 0 && pct t.idle >= 90 then "; waiting at " ^ t.waiting else "") in
    t.last <- host; t.last_now <- now;
    Hashtbl.reset t.counts; t.busy <- 0; t.idle <- 0;
    Some line
  end
