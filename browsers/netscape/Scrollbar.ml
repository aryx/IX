(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's libs/gui/Gui_scrollbar.ml (its 8af888e) *)

(* See Scrollbar.mli *)

module P = Playground

type t = {
  right : float;
  top : float;
  height : float;
  total : float;
  shown : float;
  offset : float;
}

type hit = Thumb of float | Before | After

let width = 14.

(* what the page can be scrolled by, and the thumb's length *)
let range (b : t) : float = b.total -. b.shown

let length (b : t) : float =
  Float.min b.height (Float.max 24. (b.height *. b.shown /. b.total))

let thumb (b : t) : (float * float) option =
  if b.total <= b.shown || b.height <= 0. then None
  else
    let l = length b in
    let down = Float.max 0. (Float.min 1. (b.offset /. range b)) in
    Some (b.top +. ((b.height -. l) *. down), l)

let at (b : t) ((x, y) : float * float) : hit option =
  match thumb b with
  | Some (top, l)
    when x <= b.right && x >= b.right -. width && y >= b.top
         && y <= b.top +. b.height ->
      Some (if y < top then Before else if y > top +. l then After
            else Thumb (y -. top))
  | _ -> None

let dragged (b : t) ~(grab : float) (y : float) : float =
  let travel = b.height -. length b in
  if travel <= 0. then 0.
  else
    let offset = (y -. grab -. b.top) /. travel *. range b in
    Float.max 0. (Float.min (range b) offset)

let shapes (b : t) : P.shape list =
  match thumb b with
  | None -> []
  | Some (top, l) ->
      let x = b.right -. width in
      let track = P.rectangle (P.rgb 176 176 176) width b.height in
      P.move (x +. (width /. 2.)) (-.(b.top +. (b.height /. 2.))) track
      :: Browser_draw.raised (x +. 1.) top (width -. 2.) l
