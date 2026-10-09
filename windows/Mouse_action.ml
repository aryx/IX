(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Mouse_action.mli *)

type t = {
  mouse : Mouse.t; display : Display.t; desk : Display.desktop;
  set : Cursor.t option -> unit;
  (* the cursor shown: the kernel is told only when it is another (the
   * mouse on a border says its cursor at each move) *)
  mutable shown : Cursor.t option;
}

let make caps mouse display desk = { mouse; display; desk; set = (fun c -> Cursor.set caps c); shown = None }

let cursor (a : t) (c : Cursor.t option) =
  let same = match c, a.shown with Some x, Some y -> x == y | None, None -> true | _ -> false in
  if not same then begin a.shown <- c; a.set c end

(* the mouse followed until the right button is as wanted: where *)
let rec button (a : t) down = let m : Mouse.state = Event.sync (Mouse.receive a.mouse) in if (m.buttons land 4 <> 0) = down then m.pos else button a down

(* a rectangle that follows the mouse while a button is down, shown as
 * it changes (made anew at each move): what it is when the button
 * comes up *)
let band (a : t) but (rect : Point.t -> Rectangle.t) : Rectangle.t =
  let red = Display.color a.display (Display.rgb 0xdd 0x00 0x00) in
  let rec drag shown =
    let m : Mouse.state = Event.sync (Mouse.receive a.mouse) in
    Option.iter Display.free shown;
    let r = rect m.pos in
    if m.buttons land but = 0 then r
    else begin
      let shown = if Rectangle.dx r > 8 && Rectangle.dy r > 8 then begin
          let i = Display.window a.desk r (Display.rgb 0xee 0xee 0xee) in
          Draw.border i r 4 red;
          Some i
        end else None in
      Display.flush a.display;
      drag shown
    end in
  let r = drag None in
  Display.free red;
  r

let sweep (a : t) : Rectangle.t =
  cursor a (Some Cursors.cross);
  let p0 = button a true in
  let r = band a 4 (fun (p : Point.t) -> Rectangle.v (min p0.x p.x) (min p0.y p.y) (max p0.x p.x) (max p0.y p.y)) in
  cursor a None;
  r

let point (a : t) =
  cursor a (Some Cursors.sight);
  let p = button a true in
  ignore (button a false);
  cursor a None;
  Wm.at p

let drag (a : t) : (Window.t * Rectangle.t) option =
  cursor a (Some Cursors.sight);
  let p0 = button a true in
  let result = match Wm.at p0 with
    | None -> ignore (button a false); None
    | Some w -> Some (w, band a 4 (fun p -> Rectangle.add w.image.r (Point.sub p p0))) in
  cursor a None;
  result

let grab (a : t) (w : Window.t) which (m : Mouse.state) =
  Wm.front w;
  let r0 = w.image.r in
  (* (a side's two ends: the one held is the mouse's, from where it was pressed) *)
  let side k p from lo hi = if k = 0 then (min (lo + p - from) hi, max (lo + p - from) hi) else if k = 2 then (min lo (hi + p - from), max lo (hi + p - from)) else (lo, hi) in
  let r : Rectangle.t =
    if m.buttons land 4 <> 0 then begin cursor a (Some Cursors.box); band a 4 (fun p -> Rectangle.add r0 (Point.sub p m.pos)) end
    else band a (m.buttons land 3) (fun (p : Point.t) ->
        let x0, x1 = side (which mod 3) p.x m.pos.x r0.min.x r0.max.x and y0, y1 = side (which / 3) p.y m.pos.y r0.min.y r0.max.y in
        Rectangle.v x0 y0 x1 y1) in
  cursor a None;
  if r <> r0 && Wm.fits r then Window.send w (Window.Reshape r)

let hover (a : t) (m : Mouse.state) =
  if m.buttons = 0 then
    cursor a (match Wm.border m.pos, Wm.at m.pos with
      | Some (_, k), _ -> Some Cursors.corners.(k)
      | None, Some w -> w.cursor
      | None, None -> None)
