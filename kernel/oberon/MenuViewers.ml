(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See MenuViewers.mli *)

exception Extend of int * int * int
exception Reduce of int * int * int

type viewer = Viewers.viewer

let menu (v : viewer) = List.nth v.frame.dsc 0
let main (v : viewer) = List.nth v.frame.dsc 1

(* the border: the four sides; and what of it changes when the bottom
 * goes down (extend) or up (reduce), the top up (grow) or down (shrink) *)
let line x y w h = Display.repl_const White x y w h Replace

let draw (v : viewer) =
  let f = v.frame in
  line f.x f.y 1 f.h; line (f.x + f.w - 1) f.y 1 f.h; line (f.x + 1) f.y (f.w - 2) 1; line (f.x + 1) (f.y + f.h - 1) (f.w - 2) 1

let extend (v : viewer) new_y =
  let f = v.frame in
  let dh = f.y - new_y in
  if dh > 0 then begin
    Display.repl_const Black (f.x + 1) (new_y + 1) (f.w - 2) dh Replace;
    line f.x new_y 1 dh; line (f.x + f.w - 1) new_y 1 dh; line (f.x + 1) new_y (f.w - 2) 1
  end

let reduce (v : viewer) new_y = line (v.frame.x + 1) new_y (v.frame.w - 2) 1

let grow (v : viewer) old_h =
  let f = v.frame in
  let dh = f.h - old_h in
  if dh > 0 then begin
    line f.x (f.y + old_h) 1 dh; line (f.x + f.w - 1) (f.y + old_h) 1 dh; line (f.x + 1) (f.y + f.h - 1) (f.w - 2) 1
  end

let shrink (v : viewer) new_h = line (v.frame.x + 1) (v.frame.y + new_h - 1) (v.frame.w - 2) 1

(* a frame told, then its rectangle changed *)
let adjust (f : Display.frame) m y h = Display.send f m; f.y <- y; f.h <- h
let extended f dy y h = adjust f (Extend (dy, y, h)) y h
let reduced f dy y h = adjust f (Reduce (dy, y, h)) y h

let restore (v : viewer) =
  let f = v.frame and menu = menu v and main = main v in
  Oberon.remove_marks f.x f.y f.w f.h;
  draw v;
  menu.x <- f.x + 1; menu.y <- f.y + f.h - 1; menu.w <- f.w - 2; menu.h <- 0;
  main.x <- f.x + 1; main.y <- f.y + f.h - v.menu_h; main.w <- f.w - 2; main.h <- 0;
  if f.h > v.menu_h + 1 then begin
    extended menu 0 (f.y + f.h - v.menu_h) (v.menu_h - 1);
    extended main 0 (f.y + 1) (f.h - v.menu_h - 1)
  end
  else extended menu 0 (f.y + 1) (f.h - 2)

(* the bottom moved to y, the height h (Viewers.Modify) *)
let modify (v : viewer) y h =
  let f = v.frame and menu = menu v and main = main v in
  if y < f.y then begin
    Oberon.remove_marks f.x y f.w (f.y - y);
    extend v y;
    if h > v.menu_h + 1 then begin
      extended menu 0 (y + h - v.menu_h) (v.menu_h - 1);
      extended main 0 (y + 1) (h - v.menu_h - 1)
    end
    else extended menu 0 (y + 1) (h - 2)
  end
  else if y > f.y then begin
    Oberon.remove_marks f.x f.y f.w f.h;
    if h > v.menu_h + 1 then begin
      reduced main 0 (y + 1) (h - v.menu_h - 1);
      reduced menu 0 (y + h - v.menu_h) (v.menu_h - 1)
    end
    else begin
      reduced main 0 (y + h - v.menu_h) 0;
      reduced menu 0 (y + 1) (h - 2)
    end;
    reduce v y
  end

(* The left key went down in the menu: the menu shown taken (inverted)
 * while the keys are held, then by the keys that were pressed
 * meanwhile: the right one, nothing; the middle one, the viewer closed
 * and opened where the mouse is; none, its top moved by as much as the
 * mouse went up or down. *)
let change (v : viewer) x y keys =
  let f = v.frame and menu = menu v and main = main v in
  let invert () = Display.repl_const White (f.x + 1) (f.y + f.h - 1 - menu.h) (f.w - 2) menu.h Invert in
  Oberon.draw_mouse_arrow x y;
  invert ();
  let rec held keysum x y =
    let keys, x1, y1 = Input.mouse () in
    if keys = 0 then keysum, x, y else begin Oberon.draw_mouse_arrow x1 y1; held (keysum lor keys) x1 y1 end
  in
  let y0 = y in
  let keysum, x, y = held keys x y in
  invert ();
  if keysum land Input.right = 0 then
    if keysum land Input.middle <> 0 then begin
      (match Viewers.this x y with
       | Some v1 ->
           let f1 = v1.frame in
           let y = if v1.menu_h > 0 && y > f1.y + f1.h - v1.menu_h - 2 then f1.y + f1.h else y in
           let y = max y (f1.y + v.menu_h + 2) in
           Viewers.close v; Viewers.open_ v x y; restore v
       | None -> ())
    end
    else if y > y0 then begin
      (* up: from the viewer above, as much as it can give *)
      let v1 = Viewers.next v in
      let h1 = v1.frame.h in
      let dy = y - y0 in
      let dy =
        if v1.state > 1 then
          if v1.menu_h > 0 then (if h1 < v1.menu_h + 2 then 0 else min dy (h1 - v1.menu_h - 2)) else min dy (h1 - 1)
        else min dy h1
      in
      Viewers.change v (f.y + f.h + dy);
      Oberon.remove_marks f.x f.y f.w f.h;
      grow v (f.h - dy);
      if f.h > v.menu_h + 1 then begin
        extended menu dy (f.y + f.h - v.menu_h) (v.menu_h - 1);
        extended main dy (f.y + 1) (f.h - v.menu_h - 1)
      end
      else begin
        extended menu dy (f.y + 1) (f.h - 2);
        extended main dy (f.y + f.h - v.menu_h) 0
      end
    end
    else if y < y0 && f.h >= v.menu_h + 2 then begin
      let dy = min (y0 - y) (f.h - v.menu_h - 2) in
      Oberon.remove_marks f.x f.y f.w f.h;
      let h = f.h - dy in
      reduced main dy (f.y + 1) (h - v.menu_h - 1);
      reduced menu dy (f.y + h - v.menu_h) (v.menu_h - 1);
      shrink v h;
      Viewers.change v (f.y + h)
    end

let suspend (v : viewer) =
  let f = v.frame in
  reduced (main v) 0 (f.y + f.h - v.menu_h) 0;
  reduced (menu v) 0 (f.y + f.h - 1) 0

let handle (v : viewer) (m : Display.msg) =
  let f = v.frame and menu = menu v and main = main v in
  match m with
  | Oberon.Track (keys, x, y) ->
      (* by where the mouse is: the border, the main frame, the menu *)
      if y < f.y + 1 then Oberon.draw_mouse_arrow x y
      else if y < f.y + f.h - v.menu_h then Display.send main m
      else if y < f.y + f.h - v.menu_h + 2 then Display.send menu m
      else if y < f.y + f.h - 1 then (if keys land Input.left <> 0 then change v x y keys else Display.send menu m)
      else Oberon.draw_mouse_arrow x y
  | Oberon.Mark (x, y) -> Oberon.draw_mouse_arrow x y; Oberon.draw_pointer x y
  | Viewers.Restore -> restore v
  | Viewers.Modify (y, h) -> modify v y h
  | Viewers.Suspend -> suspend v
  | _ -> Display.send menu m; Display.send main m

let new_ menu main menu_h x y : viewer =
  let v : viewer = { frame = Display.frame (fun _ _ -> ()); state = 0; menu_h } in
  v.frame.dsc <- [ menu; main ];
  v.frame.handle <- (fun _ m -> handle v m);
  Viewers.open_ v x y;
  restore v;
  v
