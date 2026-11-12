(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibPlayground.ml's first game, a page: a square the arrows move, 8
 * pixels a key, on a field it does not leave; it blinks twice a
 * second, and the seconds are counted. TinyLibPlayground_test.sh draws a
 * model of it on the host; TinyKernel's check plays it in a window
 * (play.events), where it is the program square (user/square.ml). *)

open TinyLibPlayground

(* where the square is, the frames so far *)
type model = { x : int; y : int; frames : int }

let grey = 0xaa
let white = 255
let black = 0
let blue = 0x36
let yellow = 0xfc

let view m =
  [ Rect (grey, 320, 240); Rect (blue, 320, 20);
    Move (8, 2, Words (white, "square: the arrows move it, q quits"));
    Move (8, 216, Words (black, string_of_int (m.frames / 30) ^ " s"));
    Move (m.x, m.y,
          Group [ Rect (black, 16, 16);
                  Move (2, 2, Rect ((if m.frames / 15 mod 2 = 0 then yellow
                                     else white), 12, 12)) ]) ]

let key (k : key) m =
  let at x y =
    { x = max 0 (min 304 x); y = max 24 (min 196 y); frames = m.frames } in
  match k with
  | Up -> at m.x (m.y - 8)
  | Down -> at m.x (m.y + 8)
  | Left -> at (m.x - 8) m.y
  | Right -> at (m.x + 8) m.y
  | _ -> m

(* (a model at each frame; its shapes are others twice a second, when it
 * blinks, and the playground draws then) *)
let frame m = { x = m.x; y = m.y; frames = m.frames + 1 }

let game = {
  width = 320; height = 240; init = (fun _ -> { x = 152; y = 112; frames = 0 });
  view = view; key = key; frame = frame; sound = (fun _ _ -> []);
  music = (fun _ -> None);
}
