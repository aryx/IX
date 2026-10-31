(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A sorted set against a hash, for the test of a rule's head
 * (Btree.mli's design, plan_ml_multicore.md's Status): 9.5 million
 * pairs (p, l) in a Tuples and in a Btree, then the lookups that rule
 * 81 of pointer.dl makes, point_to(P, L) :- assign(P, Q),
 * point_to(Q, L), from a new assign(P, Q): one p, the l's of Q in
 * order, nearly all there. Each way's nanoseconds a lookup on a
 * domain, on 1, 8 and 32 domains (OCaml 5's build; one under 4.14's).
 * usage: dune exec languages/datalog/tests/btree_bench.exe *)

let n = 9_500_000
let ps = 200_000
let ls = 120_000

(* f d on domains 0 to size - 1, back when all are done *)
let on_domains (size : int) (f : int -> unit) : unit =
  let lock = Parallel.lock () and finished = Parallel.cond () in
  let left = ref size in
  let one (d : int) () : unit =
    f d;
    Parallel.take lock;
    decr left;
    Parallel.signal finished;
    Parallel.give lock in
  for d = 1 to size - 1 do
    Parallel.spawn (one d)
  done;
  one 0 ();
  Parallel.take lock;
  while !left > 0 do
    Parallel.wait finished lock
  done;
  Parallel.give lock

let () =
  Random.init 3;
  let s = Tuples.create 2 and t = Btree.create 2 in
  let k = ref 0 in
  while !k < n do
    let p = Random.int ps and l = Random.int ls in
    if Tuples.add s [| p; l |] then begin
      ignore (Btree.add_by t (fun (i : int) -> if i = 0 then p else l));
      incr k
    end
  done;
  (* a run: a p, and up to 40 of its l's in order *)
  let runs : (int * int array) array =
    Array.init 200_000 (fun (_ : int) ->
        let p = Random.int ps in
        let got = ref [] and m = ref 0 in
        Btree.iter_from t
          (fun (i : int) -> if i = 0 then p else min_int)
          (fun (keys : int array) (b : int) ->
            if keys.(b) = p && !m < 40 then begin
              got := keys.(b + 1) :: !got;
              incr m;
              true
            end
            else false);
        (p, Array.of_list (List.rev !got))) in
  let total = Array.fold_left (fun (a : int) ((_, l) : int * int array) -> a + Array.length l) 0 runs in
  let ways : (string * (Btree.hint -> int -> int -> bool)) list =
    [ ("Tuples.mem_by", (fun (_ : Btree.hint) (p : int) (l : int) -> Tuples.mem_by s (fun (i : int) -> if i = 0 then p else l)));
      ("Tuples.mem2", (fun (_ : Btree.hint) (p : int) (l : int) -> Tuples.mem2 s p l));
      ("Btree.mem_by", (fun (_ : Btree.hint) (p : int) (l : int) -> Btree.mem_by t (fun (i : int) -> if i = 0 then p else l)));
      ("Btree.mem_hint", (fun (h : Btree.hint) (p : int) (l : int) -> Btree.mem_hint t h (fun (i : int) -> if i = 0 then p else l)));
      ("Btree.mem2_hint", (fun (h : Btree.hint) (p : int) (l : int) -> Btree.mem2_hint t h p l)) ] in
  List.iter
    (fun ((name, mem) : string * (Btree.hint -> int -> int -> bool)) ->
      List.iter
        (fun (size : int) ->
          if size = 1 || Parallel.available then begin
            let found = Array.make size 0 in
            let t0 = Unix.gettimeofday () in
            on_domains size (fun (d : int) ->
                (* (counted here, stored at the end: the domains' cells of
                 * [found] share a line of the cache, which an increment
                 * each lookup would pass from core to core) *)
                let h = Btree.hint t and mine = ref 0 in
                for r = 0 to Array.length runs - 1 do
                  if r mod size = d then begin
                    let p, l = runs.(r) in
                    Array.iter (fun (l : int) -> if mem h p l then incr mine) l
                  end
                done;
                found.(d) <- !mine);
            let dt = Unix.gettimeofday () -. t0 in
            Printf.printf "%-16s %2d domains: %6.1f ns a lookup on a domain (%d of %d found)\n%!" name size
              (dt *. 1e9 *. float_of_int size /. float_of_int total)
              (Array.fold_left ( + ) 0 found) total
          end)
        [ 1; 8; 32 ])
    ways
