(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Stars.mli *)

exception Step

(* a star's width; the task's period, in turns of the loop (10 ms each
 * when nothing happens: Oberon's 200 ms) *)
let w = 16
let interval = 20

type star = { mutable x : int; mutable y : int; mutable dx : int; mutable dy : int }

let draw x y = Display.copy_pattern White Display.star x y Invert

(* the six, at the frame's centre, each with its speed *)
let restore (f : Display.frame) (stars : star array) =
  Oberon.remove_marks f.x f.y f.w f.h;
  Display.repl_const Black (f.x + 1) f.y (f.w - 1) f.h Replace;
  let x0 = (f.w / 2) + f.x and y0 = (f.h / 2) + f.y in
  List.iteri (fun i (dx, dy) ->
    let s = stars.(i) in
    s.x <- x0; s.y <- y0; s.dx <- dx; s.dy <- dy;
    draw s.x s.y) [ 2, 4; 3, 9; -5, -2; -10, 8; -7, -4; 8, -10 ]

(* a star a step further, turned back at the frame's edges *)
let move (f : Display.frame) (p : star) =
  let x1 = f.x + f.w - w and y1 = f.y + f.h - w in
  draw p.x p.y;
  p.x <- p.x + p.dx; p.y <- p.y + p.dy;
  if p.x < f.x then begin p.x <- (2 * f.x) - p.x; p.dx <- - p.dx end
  else if p.x >= x1 then begin p.x <- (2 * x1) - p.x; p.dx <- - p.dx end;
  if p.y < f.y then begin p.y <- (2 * f.y) - p.y; p.dy <- - p.dy end
  else if p.y >= y1 then begin p.y <- (2 * y1) - p.y; p.dy <- - p.dy end;
  draw p.x p.y

let task = Oberon.new_task (fun () -> Viewers.broadcast Step) interval

(* a Stars frame: its stars are what its handler holds *)
let rec new_frame (stars : star array) : Display.frame =
  Display.frame (fun (f : Display.frame) m ->
    match m with
    | Oberon.Track (_, x, y) -> Oberon.draw_mouse_arrow x y
    | Step -> if f.h > w then Array.iter (move f) stars
    | Oberon.Copy c ->
        Oberon.remove task;
        let f1 : Display.frame = new_frame (Array.map (fun (s : star) -> { x = s.x; y = s.y; dx = s.dx; dy = s.dy }) stars) in
        f1.x <- f.x; f1.y <- f.y; f1.w <- f.w; f1.h <- f.h;
        c.copied <- Some f1
    | MenuViewers.Extend (_, y, h) | MenuViewers.Reduce (_, y, h) ->
        if y <> f.y || h <> f.h then begin f.y <- y; f.h <- h; restore f stars end
    | _ -> ())

(* whether the command was called in a viewer's menu: the viewer *)
let menu_viewer () =
  match Oberon.par.vwr, Oberon.par.frame with
  | Some v, Some f -> (match v.frame.dsc with menu :: _ when menu == f -> Some v | _ -> None)
  | _ -> None

let open_ () =
  let x, y = Oberon.allocate_user_viewer () in
  let stars = Array.init 6 (fun _ -> { x = 0; y = 0; dx = 0; dy = 0 }) in
  ignore (MenuViewers.new_ (TextFrames.new_menu "Stars" "Stars.Close  System.Grow  System.Copy  Stars.Step  Stars.Run  Stars.Stop")
            (new_frame stars) TextFrames.menu_h x y)

let run () = Oberon.install task
let stop () = Oberon.remove task

(* this viewer's stars (in its menu), or all *)
let step () =
  match menu_viewer () with
  | Some { frame = { dsc = [ _; main ]; _ }; _ } -> Display.send main Step
  | _ -> Viewers.broadcast Step

let close () = Option.iter (fun v -> stop (); Viewers.close v) (menu_viewer ())

let set_period () =
  let s = Texts.open_scanner Oberon.par.text Oberon.par.pos in
  Texts.scan s;
  match s.sym with Int n -> Oberon.set_period task n | _ -> ()

let () =
  List.iter (fun (name, p) -> Modules.command ("Stars." ^ name) p)
    [ "Open", open_; "Run", run; "Stop", stop; "Step", step; "Close", close; "SetPeriod", set_period ]
