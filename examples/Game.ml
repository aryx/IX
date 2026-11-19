(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* game: a ball that bounces in the window, the arrows turning it, on
 * lib_playground, which is Elm's Playground: a game is a memory, the
 * shapes of a memory (view) and the memory after a frame (update),
 * both given the computer, its screen and the keys held. The middle of
 * the screen is (0, 0) and y goes up. Playground_platform runs it: on
 * mini-9pi with the draw device, in a window under rio; on Linux
 * without a window, a frame written to a file. games/ has the real
 * ones. The mkfile beside it builds it, with lib_playground and the
 * platform:
 *
 *     cd /src/examples; mk; ../_mk/5-plan9/examples/game
 *     _mk/7/examples/game -dump-frame 60 frame.ppm     on Linux
 *)
module P = Playground

(* where the ball is, and where it goes at each frame *)
type ball = { x : float; y : float; dx : float; dy : float }

let size = 16.

let view (computer : P.computer) (ball : ball) : P.shape list =
  let screen = computer.screen in
  [ P.rectangle P.gray screen.width screen.height;
    P.words P.black "game: the arrows turn it" |> P.move_y (screen.top -. 20.);
    P.square P.red size |> P.move ball.x ball.y ]

let update (computer : P.computer) (ball : ball) : ball =
  let screen = computer.screen and keys = computer.keyboard in
  (* an arrow turns the ball that way, at the same speed *)
  let dx =
    if keys.kleft then -.abs_float ball.dx
    else if keys.kright then abs_float ball.dx
    else ball.dx in
  let dy =
    if keys.kdown then -.abs_float ball.dy
    else if keys.kup then abs_float ball.dy
    else ball.dy in
  (* a step; a wall sends it back *)
  let half = size /. 2. in
  let x = ball.x +. dx and y = ball.y +. dy in
  let dx = if x < screen.left +. half || x > screen.right -. half then -.dx else dx in
  let dy = if y < screen.bottom +. half || y > screen.top -. half then -.dy else dy in
  { x = ball.x +. dx; y = ball.y +. dy; dx; dy }

let app = P.game view update { x = -100.; y = 40.; dx = 3.; dy = 2. }

(* (flags: the command line's, -help among them, which ends the program) *)
let () =
  Cap.main (fun caps ->
      Exit.exit caps
        (Exit.catch (fun () ->
             Playground_platform.run_app caps (Playground_platform.flags caps) app;
             Exit.OK)))
