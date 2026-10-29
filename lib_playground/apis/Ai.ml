(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ai.mli *)

(* ix: the author's playground's playground/apis/Ai.ml; its ways through a map, and aim_error with the wobble it stands on from libs/ai/bots/Bot.ml (Bot not copied); its optional arguments said, its functions annotated (lib_playground/ai/README.md) *)

(*****************************************************************************)
(* Ways through a map *)
(*****************************************************************************)

let straight : (int * int) list = [ (1, 0); (-1, 0); (0, 1); (0, -1) ]
let corners : (int * int) list = [ (1, 1); (1, -1); (-1, 1); (-1, -1) ]

(* the grid as Pathfind sees it: what a tile's neighbours are and
 * what each costs. A corner costs what it really is, sqrt 2, or
 * diagonal ways come out cheaper than they are *)
let problem_of ~(cost : int * int -> float) ~(diagonal : bool) (goal : int * int) : (int * int) Pathfind.problem =
  let one (d : int * int) : (int * int) * float = (d, 1.) in
  let steps =
    if diagonal then List.map one straight @ List.map (fun (d : int * int) -> (d, sqrt 2.)) corners
    else List.map one straight in
  {
    neighbors =
      (fun ((x, y) : int * int) ->
        List.filter_map
          (fun (((dx, dy), far) : (int * int) * float) ->
            let c = (x + dx, y + dy) in
            let k = cost c in
            if Float.is_finite k then Some (c, k *. far) else None)
          steps);
    goal = (fun (c : int * int) -> c = goal);
    (* never more than the truth, or A* stops being A*: one per step
     * (the cheapest a tile can be), and the diagonal's shortcut taken
     * into account when there are diagonals *)
    estimate =
      (fun ((x, y) : int * int) ->
        let gx, gy = goal in
        let dx = float_of_int (abs (x - gx)) and dy = float_of_int (abs (y - gy)) in
        if diagonal then Float.max dx dy +. ((sqrt 2. -. 1.) *. Float.min dx dy) else dx +. dy);
  }

let way_over ~(cost : int * int -> float) ~(diagonal : bool) (from : int * int) (to_ : int * int) : (int * int) list =
  if not (Float.is_finite (cost to_)) then []
  else
    match (Pathfind.astar (problem_of ~cost ~diagonal to_) from).path with
    | _ :: rest -> rest (* the tile it is standing on is not a step *)
    | [] -> []

let way ~(walkable : int * int -> bool) ~(diagonal : bool) (from : int * int) (to_ : int * int) : (int * int) list =
  way_over ~cost:(fun (c : int * int) -> if walkable c then 1. else infinity) ~diagonal from to_

(* the cost to the goal from every tile it can be reached from. One
 * search, from the goal outward: the steps cost the same both ways,
 * so a field built from the goal is every tile's way to it *)
type flow = { to_go : (int * int, float) Hashtbl.t; diagonal : bool }

let flow ~(walkable : int * int -> bool) ~(diagonal : bool) (goal : int * int) : flow =
  let cost (c : int * int) : float = if walkable c then 1. else infinity in
  let field = Pathfind.field (problem_of ~cost ~diagonal goal) goal in
  let to_go = Hashtbl.create (List.length field) in
  List.iter (fun ((c, k) : (int * int) * float) -> Hashtbl.replace to_go c k) field;
  { to_go; diagonal }

let steps_to_go (f : flow) (tile : int * int) : float option = Hashtbl.find_opt f.to_go tile

(* downhill: of the neighbours on the field, the one closest to the
 * goal, and None on the goal itself (nothing is closer) *)
let next_step (f : flow) ((x, y) : int * int) : (int * int) option =
  match Hashtbl.find_opt f.to_go (x, y) with
  | None -> None
  | Some here ->
      let steps = if f.diagonal then straight @ corners else straight in
      List.fold_left
        (fun (best : ((int * int) * float) option) ((dx, dy) : int * int) ->
          let c = (x + dx, y + dy) in
          match Hashtbl.find_opt f.to_go c with
          | Some k when k < here -> ( match best with Some (_, kb) when kb <= k -> best | _ -> Some (c, k))
          | _ -> best)
        None steps
      |> Option.map (fun ((c, _) : (int * int) * float) -> c)

(*****************************************************************************)
(* A bot's aim *)
(*****************************************************************************)

(* a smooth wobble in [-1, 1]: two sines that don't share a period, so
 * it doesn't repeat visibly (Bot.ml's) *)
let wobble (t : float) (seed : int) : float =
  let s = float_of_int seed in
  (sin ((t *. 0.37) +. (s *. 1.7)) +. sin ((t *. 0.11) +. (s *. 0.9))) /. 2.

(* (Bot.aim_error) *)
let aim_error ~(spread : float) ~(settle : float) ~(seen_for : int) ~(seed : int) () : float =
  let decay = if settle <= 0. then 0. else 0.5 ** (float_of_int seen_for /. settle) in
  spread *. decay *. wobble (float_of_int seen_for) seed
