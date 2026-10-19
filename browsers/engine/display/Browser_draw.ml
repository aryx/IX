(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/display/Browser_draw.ml, its first version (docs/plans/plan_browser.md) *)

(* See Browser_draw.mli *)
open Playground

(* things whose shapes are made: Html_layout's boxes' (Mosaic's way) *)
type made = (float * float * shape) list

(* a shape built when first asked for, and kept (no Lazy.t: mini-ml has
 * none) *)
type later = { mutable shape : shape option; make : unit -> shape }

(* opti: is a line's shape built when it is first shown? (draw=all: at once) *)
let lazily : bool ref = ref true
let later (make : unit -> shape) : later = if !lazily then { shape = None; make } else { shape = Some (make ()); make }

let shape_of (l : later) : shape =
  match l.shape with
  | Some s -> s
  | None ->
      let s = l.make () in
      l.shape <- Some s;
      s

type drawn = (float * float * later) list

let ready (l : made) : drawn = List.map (fun (top, bottom, (s : shape)) -> (top, bottom, { shape = Some s; make = (fun () -> s) })) l

let characters = Browser_text.characters
let metrics = Browser_text.metrics

let frame_thick (t : float) (color : color) (x : float) (y : float) (w : float) (h : float) : shape =
  group
    [ rectangle color w t |> move (x +. (w /. 2.)) (-.(y +. (t /. 2.)));
      rectangle color w t |> move (x +. (w /. 2.)) (-.(y +. h -. (t /. 2.)));
      rectangle color t h |> move (x +. (t /. 2.)) (-.(y +. (h /. 2.)));
      rectangle color t h |> move (x +. w -. (t /. 2.)) (-.(y +. (h /. 2.))) ]

let frame (color : color) (x : float) (y : float) (w : float) (h : float) : shape = frame_thick 1. color x y w h

let raised (x : float) (top : float) (w : float) (h : float) : shape list =
  [ rectangle (rgb 205 205 205) w h |> move (x +. (w /. 2.)) (-.(top +. (h /. 2.)));
    frame (rgb 120 120 120) x top w h;
    frame (rgb 240 240 240) x top (w -. 1.) (h -. 1.) ]

let sunken (x : float) (top : float) (w : float) (h : float) : shape list =
  [ rectangle (rgb 255 255 255) w h |> move (x +. (w /. 2.)) (-.(top +. (h /. 2.)));
    frame (rgb 240 240 240) x top w h;
    frame (rgb 120 120 120) x top (w -. 1.) (h -. 1.) ]

(*****************************************************************************)
(* Words and pictures *)
(*****************************************************************************)

(* a picture in its place: its pixels, once arrived; the room kept for
 * it (its width= and height=) until then; NCSA's broken image when it
 * could not be had; in a link, a border of the link's colour, as
 * Mosaic drew it (the one way to tell a picture that is a link) *)
let picture_shapes (state : Browser_picture.t option) (color : color) (f : Html_layout.fragment) (pic : Html_layout.picture)
    : shape list =
  let w = f.width and h = pic.height in
  let top = if pic.middle then f.baseline -. (h /. 2.) else f.baseline -. h in
  let center = (f.x +. (w /. 2.), -.(top +. (h /. 2.))) in
  let body =
    match state with
    | Some (Arrived img) -> [ bitmap w h img |> move (fst center) (snd center) ]
    | Some Broken ->
        (* a torn picture: a white card, a red slash across *)
        [ rectangle (rgb 245 245 245) w h |> move (fst center) (snd center);
          frame (rgb 90 90 90) f.x top w h;
          rectangle (rgb 200 30 30) (w *. 1.2) 2. |> rotate 45. |> move (fst center) (snd center) ]
    | Some Waiting | None ->
        (* the room kept: a sunken, empty frame *)
        [ frame (rgb 130 130 130) f.x top w h; frame (rgb 235 235 235) (f.x +. 1.) (top +. 1.) (w -. 2.) (h -. 2.) ]
  in
  body @ match f.look.link with Some _ -> [ frame_thick 2. color (f.x -. 2.) (top -. 2.) (w +. 4.) (h +. 4.) ] | None -> []

let glyphs ~(visited : string -> bool) ~(picture_of : string -> Browser_picture.t option) (f : Html_layout.fragment) :
    shape list =
  let style = Browser_text.style_of f.look in
  (* a visited link's colour: Mosaic's purple, and every browser's
   * since (or the page's vlink=) *)
  let (r, g, b) = match f.look.link with Some href when visited href -> f.look.visited_color | _ -> f.look.color in
  let color = rgb r g b in
  let baseline = -.f.baseline in
  match (f.picture, f.control) with
  | Some pic, _ -> picture_shapes (picture_of pic.src) color f pic
  (* a form's control: drawn with its value every frame (control_shapes) *)
  | None, Some _ -> []
  | None, None ->
      if f.look.monospace then
        let cell = Browser_text.cell_of f.look in
        characters f.text
        |> List.mapi (fun i c ->
               if c = " " then []
               else
                 let w = Stroke_text.metrics style c in
                 Stroke_text.glyph color style c ~x:(f.x +. (cell *. float_of_int i) +. ((cell -. w) /. 2.)) ~baseline)
        |> List.concat
      else
        let _, shapes =
          List.fold_left
            (fun (x, shapes) c -> (x +. Stroke_text.metrics style c, Stroke_text.glyph color style c ~x ~baseline :: shapes))
            (f.x, []) (characters f.text)
        in
        List.concat (List.rev shapes)


let plain_glyphs (f : Html_layout.fragment) : shape list = glyphs ~visited:(fun _ -> false) ~picture_of:(fun _ -> None) f

(* text in a control: black, plain, fixed-width if [cells] *)
let text_shapes ~(cells : bool) (look : Looks.t) (text : string) ~(x : float) ~(baseline : float) : shape list =
  let look = { look with color = (0, 0, 0); underline = false; link = None; bold = false; italic = false; monospace = cells } in
  plain_glyphs { text; look; x; width = metrics look text; baseline; picture = None; control = None; element = Dom.element "span" [] }

let control_shapes ~(value : Dom.element -> Forms.value) ~(focused : bool) (f : Html_layout.fragment) (c : Html_layout.control)
    : shape list =
  match Forms.control c.element with
  | None -> []
  | Some control -> (
      let v = value c.element in
      let w = f.width and h = c.control_height and size = f.look.size in
      let top = f.baseline -. (0.75 *. h) and cell = Browser_text.cell_of f.look in
      let tail = Browser_text.tail in
      let caret x baseline = if focused then [ rectangle (rgb 0 0 0) 1.5 size |> move x (-.(baseline -. (0.35 *. size))) ] else [] in
      match control.kind with
      | Text | Password ->
          let shown = if control.kind = Password then String.make (List.length (characters v.text)) '*' else v.text in
          let shown = tail (int_of_float ((w -. 8.) /. cell) - 1) shown in
          sunken f.x top w h
          @ text_shapes ~cells:true f.look shown ~x:(f.x +. 4.) ~baseline:f.baseline
          @ caret (f.x +. 4. +. (cell *. float_of_int (List.length (characters shown)))) f.baseline
      | Checkbox ->
          (* Motif's toggle: a square, sunken and filled when on *)
          if v.checked then
            sunken f.x top w h
            @ [ rectangle (rgb 60 60 60) (w *. 0.5) (h *. 0.5) |> move (f.x +. (w /. 2.)) (-.(top +. (h /. 2.))) ]
          else raised f.x top w h
      | Radio ->
          (* Motif's radio button: a diamond, filled when on *)
          let center = (f.x +. (w /. 2.), -.(top +. (h /. 2.))) in
          let diamond color side = rectangle color side side |> rotate 45. |> move (fst center) (snd center) in
          [ diamond (rgb 120 120 120) (w *. 0.72); diamond (if v.checked then rgb 60 60 60 else rgb 225 225 225) (w *. 0.5) ]
      | Submit | Reset | Button ->
          let label = Forms.label control in
          raised f.x top w h @ text_shapes ~cells:false f.look label ~x:(f.x +. ((w -. metrics f.look label) /. 2.)) ~baseline:f.baseline
      | Select opts ->
          (* Motif's option menu: the choice, and its little bar *)
          let label = match List.nth_opt opts v.selected with Some (l, _) -> l | None -> "" in
          raised f.x top w h
          @ text_shapes ~cells:false f.look label ~x:(f.x +. (0.4 *. size)) ~baseline:f.baseline
          @ raised (f.x +. w -. (1.3 *. size)) (top +. (h /. 2.) -. (0.2 *. size)) (0.9 *. size) (0.4 *. size)
      | Textarea ->
          let rows = max 1 (int_of_float ((h -. 8.) /. (Looks.leading *. size))) in
          let lines = String.split_on_char '\n' v.text in
          let n = List.length lines in
          (* the last rows when typing into it, else the first *)
          let shown = List.filteri (fun i _ -> if focused then i >= n - rows else i < rows) lines in
          let baseline i = top +. 4. +. (0.95 *. size) +. (float_of_int i *. Looks.leading *. size) in
          let columns = int_of_float ((w -. 8.) /. cell) in
          sunken f.x top w h
          @ List.concat
              (List.mapi (fun i line -> text_shapes ~cells:true f.look (tail columns line) ~x:(f.x +. 4.) ~baseline:(baseline i)) shown)
          @ (match List.rev shown with
            | last :: _ ->
                caret (f.x +. 4. +. (cell *. float_of_int (List.length (characters (tail columns last))))) (baseline (List.length shown - 1))
            | [] -> [])
      | Hidden -> [])

let controls_drawn ~(value : Dom.element -> Forms.value) ~(focus : Dom.element option) (layout : Html_layout.box) : drawn =
  ready
  @@ (Html_layout.fragments layout
  |> List.filter_map (fun (f : Html_layout.fragment) ->
         match f.control with
         | Some c ->
             let focused = match focus with Some e -> e == c.element | None -> false in
             Some (f.baseline -. c.control_height, f.baseline +. c.control_height, group (control_shapes ~value ~focused f c))
         | None -> None))

(*****************************************************************************)
(* The inspector *)
(*****************************************************************************)

let rec outlines_made (b : Html_layout.box) : made =
  let color = match b.kind with Anonymous -> rgb 0 150 0 | _ -> rgb 0 0 220 in
  ((b.y, b.y +. b.height, frame color b.x b.y b.width b.height)
  :: List.map (fun (l : Html_layout.line) -> (l.top, l.top +. l.height, frame (rgb 150 150 150) b.x l.top b.width l.height)) b.lines)
  @ List.concat_map outlines_made b.children

let outlines (b : Html_layout.box) : drawn = ready (outlines_made b)
