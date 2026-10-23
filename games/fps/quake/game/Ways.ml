(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ways.mli *)

open Model
open Edict

let cell = 32.
let half = 32 (* cells each side of the player's *)

type grid = {
  z : float; (* the floor's height: the player's origin *)
  flow : Ai.flow;
  goal : int * int; (* the player's cell, in the level's numbering *)
  built : float;
}

let grid : grid option ref = ref None

let cell_of (x : float) (y : float) : int * int =
  ( int_of_float (Float.floor (x /. cell)),
    int_of_float (Float.floor (y /. cell)) )

(* (hull 1's contents at p: empty where the player's box fits) *)
let empty (w : world) (p : vec) : bool =
  let t = Trace.move w.level 1 p p [] in
  not (t.startsolid || t.allsolid)

let make (w : world) : grid =
  let o = w.play.body.origin in
  let cx, cy = cell_of o.x o.y in
  let walkable ((c, r) : int * int) : bool =
    abs (c - cx) <= half
    && abs (r - cy) <= half
    &&
    let m =
      { x = (float c +. 0.5) *. cell; y = (float r +. 0.5) *. cell; z = o.z }
    in
    empty w m
    &&
    (* (a floor within 40 under it) *)
    let t = Trace.move w.level 1 m { m with z = m.z -. 40. } [] in
    t.fraction < 1.
  in
  {
    z = o.z;
    flow = Ai.flow ~walkable ~diagonal:true (cx, cy);
    goal = (cx, cy);
    built = time w;
  }

let direction (w : world) (e : t) : float option =
  let o = w.play.body.origin in
  let here = cell_of o.x o.y in
  let g =
    match !grid with
    | Some g
      when (g.goal = here || time w -. g.built < 0.5) && time w >= g.built ->
        g
    | _ ->
        let g = make w in
        grid := Some g;
        g
  in
  (* (on the player's floor, the monster's feet at the player's) *)
  if Float.abs (e.origin.z -. g.z) > 24. then None
  else
    match Ai.next_step g.flow (cell_of e.origin.x e.origin.y) with
    | None -> None
    | Some (c, r) ->
        let x = (float c +. 0.5) *. cell and y = (float r +. 0.5) *. cell in
        Some (vectoyaw { x = x -. e.origin.x; y = y -. e.origin.y; z = 0. })

let aim_error (e : t) : float =
  Ai.aim_error ~spread:22.5 ~settle:30. ~seen_for:e.seen_for ~seed:e.id ()
