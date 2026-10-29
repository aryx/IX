(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* lib_playground/ai and the playground's Ai under mini-ml (../mini_ml.sh): what
 * mini-doom asks of them -- a flow field and its next steps, a way, an
 * aim error -- and Pathfind's searches, the same numbers as OCaml's *)

(* a wall at x = 5 but for its last two rows *)
let walkable ((x, y) : int * int) : bool =
  x >= 0 && y >= 0 && x < 12 && y < 8 && not (x = 5 && y < 6)

let show (path : (int * int) list) : unit =
  List.iter (fun ((x, y) : int * int) -> Printf.printf "(%d,%d)" x y) path;
  print_newline ()

let () =
  let goal = (10, 1) in
  let f = Ai.flow ~walkable ~diagonal:false goal in
  (match Ai.steps_to_go f (0, 0) with
  | Some k -> Printf.printf "from (0,0): %g\n" k
  | None -> print_endline "none");
  (* downhill from (0, 0) to the goal *)
  let rec walk (c : int * int) (acc : (int * int) list) : (int * int) list =
    match Ai.next_step f c with
    | Some n -> walk n (n :: acc)
    | None -> List.rev acc in
  show (walk (0, 0) []);
  Printf.printf "next on the goal: %b, in the wall: %b\n"
    (Ai.next_step f goal = None)
    (Ai.next_step f (5, 0) = None);
  let w = Ai.way ~walkable ~diagonal:true (0, 0) goal in
  Printf.printf "way, diagonal: %d steps\n" (List.length w);
  show w;
  let p : (int * int) Pathfind.problem =
    {
      neighbors =
        (fun ((x, y) : int * int) ->
          List.filter_map
            (fun ((dx, dy) : int * int) ->
              let c = (x + dx, y + dy) in
              if walkable c then Some (c, 1.) else None)
            [ (1, 0); (-1, 0); (0, 1); (0, -1) ]);
      goal = (fun (c : int * int) -> c = goal);
      estimate =
        (fun ((x, y) : int * int) -> float (abs (x - 10) + abs (y - 1)));
    }
  in
  let r = Pathfind.astar p (0, 0) in
  let d = Pathfind.dijkstra p (0, 0) in
  let b = Pathfind.breadth_first p (0, 0) in
  Printf.printf "astar: cost %g, visited %d; dijkstra %g, %d; bfs %g, %d\n"
    r.cost (List.length r.visited) d.cost (List.length d.visited) b.cost
    (List.length b.visited);
  for s = 0 to 4 do
    Printf.printf "aim %d: %.6f\n" (s * 20)
      (Ai.aim_error ~spread:10. ~settle:30. ~seen_for:(s * 20) ~seed:7 ())
  done
