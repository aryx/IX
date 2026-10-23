(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ways.mli *)

let cell = 32.

type grid = {
  level : Level.t;
  ox : float;
  oy : float;
  columns : int;
  rows : int;
  (* no wall across the cell's middle: once for the level *)
  open_ : bool array;
  (* the sector under the middle, whose room changes (a door) *)
  sectors : Level.sector array;
  mutable flow : Ai.flow option;
  mutable goal : int * int;
  mutable built : int; (* the tic *)
}

let grid : grid option ref = ref None

(* a wall within 8 of the middle, its box of 16 by 16: one-sided, or
 * blocking; the lines of the blockmap's cells under the box *)
let walled (level : Level.t) (x : float) (y : float) : bool =
  let bm = level.blockmap in
  let crosses (l : Level.line) : bool =
    (l.back = None || l.flags land (Level.blocking lor 2) <> 0)
    && Float.min l.v1.x l.v2.x < x +. 8.
    && Float.max l.v1.x l.v2.x > x -. 8.
    && Float.min l.v1.y l.v2.y < y +. 8.
    && Float.max l.v1.y l.v2.y > y -. 8.
    && Collision.box_on_line_side (x -. 8.) (x +. 8.) (y -. 8.) (y +. 8.) l = -1
  in
  let in_cell ((cx, cy) : float * float) : bool =
    let bx = int_of_float (Float.floor ((cx -. bm.originx) /. 128.))
    and by = int_of_float (Float.floor ((cy -. bm.originy) /. 128.)) in
    bx >= 0 && bx < bm.columns && by >= 0 && by < bm.rows
    && Array.exists
         (fun (k : int) -> crosses level.lines.(k))
         bm.cells.((by * bm.columns) + bx)
  in
  List.exists in_cell
    [
      (x -. 8., y -. 8.);
      (x +. 8., y -. 8.);
      (x -. 8., y +. 8.);
      (x +. 8., y +. 8.);
    ]

let make (level : Level.t) : grid =
  let xs =
    Array.concat
      (Array.to_list
         (Array.map (fun (l : Level.line) -> [| l.v1.x; l.v2.x |]) level.lines))
  in
  let ys =
    Array.concat
      (Array.to_list
         (Array.map (fun (l : Level.line) -> [| l.v1.y; l.v2.y |]) level.lines))
  in
  let ox = Array.fold_left Float.min infinity xs
  and oy = Array.fold_left Float.min infinity ys in
  let columns =
    int_of_float ((Array.fold_left Float.max neg_infinity xs -. ox) /. cell) + 1
  in
  let rows =
    int_of_float ((Array.fold_left Float.max neg_infinity ys -. oy) /. cell) + 1
  in
  let middle (k : int) : float * float =
    ( ox +. ((float (k mod columns) +. 0.5) *. cell),
      oy +. ((float (k / columns) +. 0.5) *. cell) )
  in
  let sectors =
    Array.init (columns * rows) (fun (k : int) ->
        let x, y = middle k in
        Level.sector_at level x y)
  in
  let open_ =
    Array.init (columns * rows) (fun (k : int) ->
        let x, y = middle k in
        not (walled level x y))
  in
  {
    level;
    ox;
    oy;
    columns;
    rows;
    open_;
    sectors;
    flow = None;
    goal = (-1, -1);
    built = -100;
  }

let cell_of (g : grid) (x : float) (y : float) : int * int =
  ( int_of_float (Float.floor ((x -. g.ox) /. cell)),
    int_of_float (Float.floor ((y -. g.oy) /. cell)) )

let walkable (g : grid) ((c, r) : int * int) : bool =
  c >= 0 && c < g.columns && r >= 0 && r < g.rows
  &&
  let k = (r * g.columns) + c in
  let s = g.sectors.(k) in
  g.open_.(k) && s.ceiling -. s.floor >= World.height

(* the grid of this level, and its flow from the player's cell *)
let flow (t : World.t) : grid * Ai.flow =
  let g =
    match !grid with
    | Some g when g.level == t.level -> g
    | _ ->
        let g = make t.level in
        grid := Some g;
        g
  in
  let here = cell_of g t.player.x t.player.y in
  (match g.flow with
  | Some _ when here = g.goal || t.tic - g.built < 16 -> ()
  | _ ->
      g.flow <- Some (Ai.flow ~walkable:(walkable g) ~diagonal:true here);
      g.goal <- here;
      g.built <- t.tic);
  match g.flow with Some f -> (g, f) | None -> assert false

let direction (t : World.t) (m : Things.mobj) : int option =
  let g, f = flow t in
  match Ai.next_step f (cell_of g m.mx m.my) with
  | None -> None
  | Some (c, r) ->
      let x = g.ox +. ((float c +. 0.5) *. cell)
      and y = g.oy +. ((float r +. 0.5) *. cell) in
      let a = Float.atan2 (y -. m.my) (x -. m.mx) in
      Some
        (((int_of_float (Float.round (a /. (World.pi /. 4.))) mod 8) + 8) mod 8)

let aim_error (m : Things.mobj) : float =
  Ai.aim_error ~spread:(World.pi /. 16.) ~settle:30. ~seen_for:m.seen_for
    ~seed:m.phase ()
