(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Inlining (Lower.inline_most): the unit's own small functions, a local
 * one that captures, one in tail position, and Small's, which mini-ml
 * -O3 copies here from Small's summary (run.sh's units in order); the
 * answers the same at -O0, which copies nothing *)

let sq x = x * x + 1
let twice f x = f (f x)

(* a loop calling small functions: copied in its body *)
let sum n =
  let acc = ref 0 in
  for i = 0 to n do acc := !acc + sq i + Small.at i done;
  !acc

(* a local function capturing a parameter, in its own function *)
let scaled k l =
  let mul x = x * k in
  List.map (fun x -> mul x) l |> List.fold_left (fun a b -> a + mul b) 0

(* a call in tail position, a loop by itself *)
let rec count n acc = if Small.less n 1 then acc else count (n - 1) (acc + 1)
let last n = count n 0

let () =
  Printf.printf "%d %d %d\n" (sq 7) (sum 10) (twice sq 2);
  Printf.printf "%d %d\n" (scaled 3 [ 1; 2; 3 ]) (last 100000);
  Printf.printf "%.4f %.4f %.4f\n" (Small.norm 1.) (Small.norm (-1.)) (Small.norm 100.);
  Printf.printf "%d %d\n" (Small.fine 7.5) (Small.fine (-0.25));
  Printf.printf "%b %b\n" (Small.norm nan = Small.norm nan) (Small.clamp 0. 1. nan >= 0.);
  Printf.printf "%b %b %b\n" (Small.less 1 2) (Small.same "ab" ("a" ^ "b")) (Small.same "ab" "ba");
  Printf.printf "%.1f %.1f %.1f\n" (Small.clamp 0. 1. (-2.)) (Small.clamp 0. 1. 0.5) (Small.clamp 0. 1. 3.);
  (match Small.checked 5 + Small.checked (-3) with
   | n -> Printf.printf "no %d\n" n
   | exception Small.Negative n -> Printf.printf "negative %d\n" n);
  (* a partial application: not copied, a closure *)
  let f = Small.clamp 0. in
  Printf.printf "%.1f\n" (f 2. 5.)
