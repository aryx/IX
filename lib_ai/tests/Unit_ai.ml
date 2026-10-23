(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's playground/tests/Unit_ai.ml; the tests of the ways through a map and of aim_error, the parts of Ai copied; the optional arguments back by a module at its top *)

(* Ai: its ways through a map, and a bot's aim *)

(* the playground's optional arguments again, over ix's said ones *)
module Ai = struct
  include Ai
  let way ?(diagonal = false) = way ~diagonal
  let way_over ?(diagonal = false) = way_over ~diagonal
  let flow ?(diagonal = false) = flow ~diagonal
  let aim_error ?(settle = 30.) = aim_error ~settle
end

let t = Testo.create
let cell = Alcotest.(pair int int)

(*****************************************************************************)
(* Ways through a map *)
(*****************************************************************************)

(* a wall across the middle, with one gap:
 *
 *     y=0  . . . . .
 *     y=1  # # # . #
 *     y=2  . . . . .
 *)
let rows = [| "....."; "###.#"; "....." |]

let walkable ((x, y) : int * int) : bool =
  y >= 0 && y < Array.length rows && x >= 0 && x < String.length rows.(y) && rows.(y).[x] = '.'

let test_way () =
  let path = Ai.way ~walkable (0, 0) (0, 2) in
  (* through the gap at x = 3, which is the only way down *)
  Alcotest.(check int) "eight steps around the wall" 8 (List.length path);
  Alcotest.check cell "and it ends where it was going" (0, 2) (List.nth path 7);
  Alcotest.(check bool) "the tile it stands on is not a step" true (not (List.mem (0, 0) path));
  Alcotest.(check bool) "it never walks into the wall" true (List.for_all walkable path);
  (* the gap closed: no way at all, and the same for a goal in a wall *)
  let shut (x, y) = walkable (x, y) && not (x = 3 && y = 1) in
  Alcotest.(check (list cell)) "no way through" [] (Ai.way ~walkable:shut (0, 0) (0, 2));
  Alcotest.(check (list cell)) "nor into a wall" [] (Ai.way ~walkable (0, 0) (0, 1))

let test_way_diagonal () =
  let open_ (x, y) = x >= 0 && x < 3 && y >= 0 && y < 3 in
  Alcotest.(check int) "four steps, four ways" 4 (List.length (Ai.way ~walkable:open_ (0, 0) (2, 2)));
  Alcotest.(check int) "two, with the corners" 2 (List.length (Ai.way ~walkable:open_ ~diagonal:true (0, 0) (2, 2)))

(* mud in the middle of the road: the cheapest way is the long one *)
let test_way_over () =
  let cost (x, y) = if x < 0 || x > 4 || y < 0 || y > 2 then Float.infinity else if (x, y) = (2, 1) then 10. else 1. in
  let path = Ai.way_over ~cost (0, 1) (4, 1) in
  Alcotest.(check bool) "it goes round the mud" true (not (List.mem (2, 1) path));
  Alcotest.(check int) "six steps instead of four" 6 (List.length path);
  (* and straight through it when the mud is only a little slower *)
  let shallow (c : int * int) = if cost c = 10. then 1.5 else cost c in
  Alcotest.(check bool) "but not round a puddle" true (List.mem (2, 1) (Ai.way_over ~cost:shallow (0, 1) (4, 1)))

let test_flow () =
  let f = Ai.flow ~walkable (0, 2) in
  Alcotest.(check (option (float 1e-9))) "eight steps away" (Some 8.) (Ai.steps_to_go f (0, 0));
  Alcotest.(check (option (float 1e-9))) "nothing to do here" (Some 0.) (Ai.steps_to_go f (0, 2));
  Alcotest.(check (option cell)) "the only way out is right" (Some (1, 0)) (Ai.next_step f (0, 0));
  Alcotest.(check (option cell)) "down through the gap" (Some (3, 1)) (Ai.next_step f (3, 0));
  Alcotest.(check (option cell)) "on the goal there is nowhere better" None (Ai.next_step f (0, 2));
  Alcotest.(check (option cell)) "and a wall is not on the field" None (Ai.next_step f (0, 1));
  (* every tile of the map leads to the goal, which is what a flow
     field is for: one search, and the whole crowd knows the way *)
  let reachable = List.filter walkable (List.concat_map (fun y -> List.init 5 (fun x -> (x, y))) [ 0; 1; 2 ]) in
  Alcotest.(check bool) "every tile knows where to go" true
    (List.for_all (fun c -> c = (0, 2) || Ai.next_step f c <> None) reachable)

let test_aim_error () =
  (* it wanders, it starts inside the spread, and it settles as the
     target stays in sight *)
  let miss seen_for = Ai.aim_error ~spread:10. ~seen_for ~seed:3 () in
  Alcotest.(check bool) "within the spread at once" true (Float.abs (miss 0) <= 10.);
  Alcotest.(check bool) "smaller after a second of looking" true (Float.abs (miss 60) < Float.abs (miss 0));
  Alcotest.(check bool) "nearly gone after four" true (Float.abs (miss 240) < 1.);
  Alcotest.(check bool) "two bots miss differently" true (miss 10 <> Ai.aim_error ~spread:10. ~seen_for:10 ~seed:4 ())

let tests =
  [
    t "Ai.way, around a wall" test_way;
    t "Ai.way, the corners" test_way_diagonal;
    t "Ai.way_over, round the mud" test_way_over;
    t "Ai.flow, one search for a crowd" test_flow;
    t "Ai.aim_error, the wobble that settles" test_aim_error;
  ]
