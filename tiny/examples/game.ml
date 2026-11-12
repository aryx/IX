(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* game: a ball that bounces in a box, the arrows turning it, on
 * TinyLibPlayground, which runs a game given as a model and functions:
 * the shapes of a model (view), the model after a key (key) and after
 * a frame (frame). The playground draws the shapes, waits for a key
 * or the next frame, and ends at a q. It links TinyLibSystem,
 * TinyLibDraw and TinyLibPlayground, from /lib/ml (the Buildfile beside
 * it):
 *
 *	cd /examples; build game; ./game
 *)
open TinyLibPlayground

(* where the ball is, and where it goes at each frame *)
type model = { x : int; y : int; dx : int; dy : int }

let width = 320
let height = 240
let size = 16

let view m =
  [ Rect (0xaa, width, height);
    Move (8, 4, Words (0, "game: the arrows turn it, q quits"));
    Move (m.x, m.y, Rect (0xf0, size, size)) ]

(* an arrow turns the ball that way, at the same speed *)
let key k m =
  match k with
  | Left -> { x = m.x; y = m.y; dx = - (abs m.dx); dy = m.dy }
  | Right -> { x = m.x; y = m.y; dx = abs m.dx; dy = m.dy }
  | Up -> { x = m.x; y = m.y; dx = m.dx; dy = - (abs m.dy) }
  | Down -> { x = m.x; y = m.y; dx = m.dx; dy = abs m.dy }
  | _ -> m

(* a step; a wall sends it back (the text's line is the top one) *)
let frame m =
  let dx = if m.x + m.dx < 0 || m.x + m.dx > width - size then - m.dx else m.dx in
  let dy = if m.y + m.dy < 24 || m.y + m.dy > height - size then - m.dy else m.dy in
  { x = m.x + dx; y = m.y + dy; dx = dx; dy = dy }

let game = {
  width = width; height = height;
  init = (fun _ -> { x = 40; y = 60; dx = 3; dy = 2 });
  view = view; key = key; frame = frame; sound = (fun _ _ -> []);
  music = (fun _ -> None);
}

let () = TinyLibSystem.main "game" (fun caps _ -> run caps game)
