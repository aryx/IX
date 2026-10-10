(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's playground/apis/Gui.ml; a button's and a field's enabled is said, where it was optional (true) (docs/plans/plan_gui.md) *)
open Playground

(* See Gui.mli. The adapter between gui/ (rectangles and paint) and
 * the playground (a computer and shapes). *)

(* The frame being built: the widgets update asks for, until view
 * takes them with [draw]. Dear ImGui calls this the context, and has
 * exactly one too. *)
(*****************************************************************************)
(* The frame being built *)
(*****************************************************************************)

let ui = ref Immediate.empty

(* whether [draw] has taken the last frame, so the next widget starts
 * a new one *)
let closed = ref true

(* the time of the update the frame was opened by *)
let time = ref (Time (Time.millis_to_posix 0))

let input_of (computer : computer) : Widget.input =
  let m = computer.mouse and k = computer.keyboard in
  {
    Widget.mx = m.mx;
    my = m.my;
    mdown = m.mdown;
    mclick = m.mclick;
    mrdown = m.mrdown;
    typed = k.typed;
    wheel = m.mwheel;
    keys = Set_.elements k.keys;
  }

(* every widget goes through here: open the frame if it is the first
 * of this update, ask gui/, keep the new state, return the answer *)
let widget computer f =
  (* ix: or of another update than the last widget's, known by its time:
   * a platform with a window gives a program the ticks due since its
   * last frame, several updates and then one view (Plan9_loop, the
   * SDL platform), where the playground's give one. The frame left
   * open kept the first update's mouse for the others: its click was
   * every update's, and a menu that the first opened the second
   * closed (the author, 2026-10-09: "the menu disappear almost
   * immediately").
   * old: if !closed then ( *)
  if !closed || computer.time <> !time then (
    ui := Immediate.frame (input_of computer) !ui;
    time := computer.time;
    closed := false);
  let state, answer = f !ui in
  ui := state;
  answer

let theme () = Immediate.theme !ui
let modal () = Immediate.modal !ui
let box ~at:(x, y) (w, h) : Widget.box = { Widget.x; y; w; h }

let area (computer : computer) : Widget.box =
  let s = computer.screen in
  { Widget.x = 0.; y = 0.; w = s.width; h = s.height }

(* the widgets, in a rectangle somebody else decided (a layout) *)
(*****************************************************************************)
(* The widgets *)
(*****************************************************************************)

let button_in ~(enabled : bool) computer b s = widget computer (fun u -> Immediate.button ~enabled u b s)

let checkbox_in computer b s checked =
  widget computer (fun u -> Immediate.checkbox u b s checked)

let slider_in computer b ~from ~to_ v =
  widget computer (fun u -> Immediate.slider u b ~from ~to_ v)

let knob_in computer b ~from ~to_ v = widget computer (fun u -> Immediate.knob u b ~from ~to_ v)
let rocker_in computer b on = widget computer (fun u -> Immediate.rocker u b on)
let selector_in computer b labels i = widget computer (fun u -> Immediate.selector u b labels i)
let label_in computer b s = widget computer (fun u -> (Immediate.label u b s, ()))
let field_in ~(enabled : bool) computer b text = widget computer (fun u -> Immediate.field ~enabled u b text)
let text_area_in computer b edit = widget computer (fun u -> Immediate.text_area u b edit)
let progress_in computer b f = widget computer (fun u -> (Immediate.progress u b f, ()))
let menu_in computer b items chosen = widget computer (fun u -> Immediate.menu u b items chosen)
let list_in computer b items selected = widget computer (fun u -> Immediate.list u b items selected)

(* how big each one wants to be, for a layout to place *)
let button_size s = Immediate.button_size (theme ()) s
let checkbox_size s = Immediate.checkbox_size (theme ()) s
let slider_size () = Immediate.slider_size (theme ())
let knob_size () = Immediate.knob_size (theme ())
let rocker_size () = Immediate.rocker_size (theme ())
let selector_size labels = Immediate.selector_size (theme ()) labels
let field_size () = Immediate.field_size (theme ())
let text_area_size () = Immediate.text_area_size (theme ())
let progress_size () = Immediate.progress_size (theme ())
let menu_size items = Immediate.menu_size (theme ()) items
let list_size () = Immediate.list_size (theme ())

let label_size s =
  let th = theme () in
  (Widget.text_width ~size:th.text_size s, th.row)

(* and the same, placed by hand at a point: the simple way, which
 * needs no layout at all *)
let button ~(enabled : bool) computer ~at s = button_in ~enabled computer (box ~at (button_size s)) s

let checkbox computer ~at s checked =
  checkbox_in computer (box ~at (checkbox_size s)) s checked

let slider computer ~at ~from ~to_ v =
  slider_in computer (box ~at (slider_size ())) ~from ~to_ v

let knob computer ~at ~from ~to_ v = knob_in computer (box ~at (knob_size ())) ~from ~to_ v
let rocker computer ~at on = rocker_in computer (box ~at (rocker_size ())) on
let selector computer ~at labels i = selector_in computer (box ~at (selector_size labels)) labels i

let label computer ~at s = label_in computer (box ~at (label_size s)) s
let field ~(enabled : bool) computer ~at text = field_in ~enabled computer (box ~at (field_size ())) text
let text_area computer ~at edit = text_area_in computer (box ~at (text_area_size ())) edit
let progress computer ~at f = progress_in computer (box ~at (progress_size ())) f
let menu computer ~at items chosen = menu_in computer (box ~at (menu_size items)) items chosen

(*****************************************************************************)
(* Paint into shapes *)
(*****************************************************************************)

let shape_of_paint = function
  | Widget.Fill (color, (b : Widget.box)) -> rectangle color b.w b.h |> move b.x b.y
  | Widget.Text (color, (b : Widget.box), s) ->
      words color s |> scale (b.h /. words_font_size) |> move b.x b.y
  | Widget.Disc (color, x, y, r) -> circle color r |> move x y
  (* a thin rectangle along the segment, turned to its angle *)
  | Widget.Segment (color, width, x1, y1, x2, y2) ->
      let dx = x2 -. x1 and dy = y2 -. y1 in
      rectangle color (Float.hypot dx dy) width
      |> rotate (atan2 dy dx *. 180. /. Float.pi)
      |> move ((x1 +. x2) /. 2.) ((y1 +. y2) /. 2.)

let draw () =
  closed := true;
  Immediate.paint !ui |> List.map shape_of_paint

let shapes paint = List.map shape_of_paint paint
let input computer = input_of computer

let set_theme th = ui := Immediate.set_theme th !ui
