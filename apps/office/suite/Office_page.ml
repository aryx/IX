(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: a part of the author's playground's apps/office/TinyOffice.ml, its section The page; what changed there is said in Office (docs/plans/plan_office.md) *)

(* See Office_page.mli *)

open Document

(*****************************************************************************)
(* The page *)
(*****************************************************************************)

let page_size = function Presentation -> (800., 560.) | Document -> (620., 820.) | _ -> (820., 820.)
let margin = 40.

(* a document's pages stand one under the other, a gap between them:
   the page's coordinates go on down through them all, page k starting
   at k * pitch *)
let gap = 30.
let pitch k = snd (page_size k) +. gap

(* the first page's top-left corner on the screen *)
let origin (d : doc) =
  let w, h = page_size d.kind in
  (-.w /. 2., (if h > 700. then 430. else 400.) +. d.scroll)

let to_page (d : doc) (sx, sy) =
  let l, t = origin d in
  (sx -. l, t -. sy)

let box_on_screen (d : doc) x y w h : Widget.box =
  let l, t = origin d in
  { Widget.x = l +. x +. (w /. 2.); y = t -. y -. (h /. 2.); w; h }

let obj_box (d : doc) (o : obj) = box_on_screen d o.x o.y o.w o.h
let on_slide (d : doc) (o : obj) = o.slide = d.slide
let text_width k = fst (page_size k) -. (2. *. margin)

(* the main part of a sheet, picture or drawing: the page's width less
   a margin, as tall as it is at that width *)
let main_box (d : doc) (p : Component.part) =
  let w = fst (page_size d.kind) -. 40. in
  box_on_screen d 20. 20. w (p.height w)

(* A document's text is one tall layout over all its pages: between
   every two, a box across the whole width covers the bottom margin,
   the gap and the next top margin, and a line that would reach it goes
   on below it -- on the next page. The pages are the text-round-boxes
   of Page, with boxes nobody drew. (TinyFrameMaker pours its text
   through one column after another instead, appkits/richtext/Flow.) *)
let max_pages = 30

let between_pages (d : doc) =
  if d.kind <> Document then []
  else
    let p = pitch d.kind and text_h = snd (page_size d.kind) -. (2. *. margin) in
    List.init max_pages (fun k ->
        let y = float_of_int k *. p in
        (-1., y +. text_h, text_width d.kind +. 1., y +. p))

(* the text of the slide shown, laid out round [objs] (those on it) *)
let wrap_room = 12.

let text_around (d : doc) objs =
  match d.body with
  | Texts ts ->
      let r = List.nth ts d.slide in
      let width = text_width d.kind in
      (* Page fills every stretch a line is left (~both); an object that
         keeps the text to one side, or above and below it, is a box
         that reaches the edge of the text on the side the text must
         not go -- each object its own way of wrapping, with one rule in
         Page *)
      let box o =
        let x0 = o.x -. margin -. wrap_room and x1 = o.x +. o.w -. margin +. wrap_room in
        let y0 = o.y -. margin -. wrap_room and y1 = o.y +. o.h -. margin +. wrap_room in
        match o.wrap with
        | In_front -> None
        | Both_sides -> Some (x0, y0, x1, y1)
        | Top_and_bottom -> Some (-1., y0, width +. 1., y1)
        | Wider_side -> if x0 < width -. x1 then Some (-1., y0, x1, y1) else Some (x0, y0, width +. 1., y1)
      in
      let around = List.filter_map (fun o -> if on_slide d o then box o else None) objs @ between_pages d in
      Some (r, Page.layout { Page.plain with around; both = true } ~metrics:Stroke_text.metrics ~width r)
  | Main _ -> None

(* the top of the line the text's [offset] is on, in the page's
   coordinates *)
let line_top page offset =
  let lines = Page.lines page in
  match (List.find_opt (fun (l : Page.line) -> l.first <= offset && offset < l.stop) lines, List.rev lines) with
  | Some l, _ | None, l :: _ -> l.top +. margin
  | None, [] -> margin

(* Optimization (Opti.enabled; ix's, not the playground's text). A
   document is a value: the one of the last frame is the one of this
   frame, the same record, unless an edit made another. So what is
   computed from it alone -- where its objects are, its text laid out
   round them, its pages -- is kept with it and given again while it
   is asked of the same document. The playground's text computes them
   at each call, several an update and several a view: on Linux by
   OCaml's code 5 ms a frame of a page that does not change, by
   mini-ml's 17 on the same machine, and a Pi1 is far from that
   machine (2026-10-09; the author: "let's try to optimize the right
   thing"). *)
let kept (f : doc -> 'a) : doc -> 'a =
  let last : (doc * 'a) option ref = ref None in
  fun (d : doc) ->
    match !last with
    | Some (d', r) when d' == d && !Opti.enabled -> r
    | _ ->
        let r = f d in
        last := Some (d, r);
        r

(* The objects where they are on the page: the charts made again from
   their sheets, and those tied to a paragraph placed from its line. That
   line is found in a first layout, without them -- so an object tied
   to a paragraph does not push its own paragraph away, and a second
   layout, with them, is the one shown. (Word goes round until nothing
   moves; two passes are right unless tied objects push each other's
   paragraphs.) *)
let placed_simple (d : doc) =
  let objects = List.map (refreshed d) d.objects in
  if not (List.exists (fun o -> o.anchor <> None && on_slide d o) objects) then objects
  else
    match text_around d (List.filter (fun o -> o.anchor = None) objects) with
    | Some (_, page) -> List.map (fun o -> match o.anchor with Some a when on_slide d o -> { o with y = line_top page a +. o.y } | _ -> o) objects
    | None -> objects

let placed : doc -> obj list = kept placed_simple

(* old: let layout (d : doc) = text_around d (placed d) *)
let layout : doc -> (Rich.t * Page.t) option = kept (fun (d : doc) -> text_around d (placed d))

(* The header and the footer, in the top and bottom margins of every
   page: laid out as texts of their own, each page filling in its
   fields -- where Word keeps a field's code and shows its result. The
   one being edited is shown as it is typed, codes and all. *)
let band_top (d : doc) = function Head -> 12. | Foot -> snd (page_size d.kind) -. margin +. 10.

let band_layout (d : doc) which r =
  Page.layout { Page.plain with align = (if which = Head then Page.Left else Page.Center) } ~metrics:Stroke_text.metrics ~width:(text_width d.kind) r

let with_fields ~page ~pages r =
  let find sub s =
    let n = String.length sub in
    let rec go i = if i + n > String.length s then None else if String.sub s i n = sub then Some i else go (i + 1) in
    go 0
  in
  let rec fill r =
    let s = Rich.to_string r in
    (* over the field's code, its value -- taking the code's look *)
    match List.find_map (fun (code, v) -> Option.map (fun i -> (i, code, v)) (find code s)) [ ("{pages}", pages); ("{page}", page) ] with
    | Some (i, code, v) -> fill (Rich.insert (string_of_int v) (Rich.select ~anchor:i ~caret:(i + String.length code) r))
    | None -> r
  in
  fill r

(* how many pages the document has: enough for its text and its objects *)
let pages_simple (d : doc) =
  match (d.kind, layout d) with
  | Document, Some (_, page) ->
      let bottom = List.fold_left (fun b o -> Float.max b (o.y +. o.h)) (Page.height page +. margin) (placed d) in
      max 1 (int_of_float (Float.ceil (bottom /. pitch d.kind)))
  | _ -> 1

let pages : doc -> int = kept pages_simple

(* the index of the object on top at a point of the screen *)
let object_at (d : doc) (mx, my) =
  let hits = List.filter (fun (_, o) -> on_slide d o && Widget.contains (obj_box d o) mx my) (List.mapi (fun i o -> (i, o)) (placed d)) in
  match List.rev hits with (i, _) :: _ -> Some i | [] -> None

(* the four corners of an object on the screen: top-left, top-right,
   bottom-right, bottom-left *)
let corners (b : Widget.box) = [ (Widget.left b, Widget.top b); (Widget.right b, Widget.top b); (Widget.right b, Widget.bottom b); (Widget.left b, Widget.bottom b) ]

let corner_at (d : doc) i (mx, my) =
  match List.nth_opt (placed d) i with
  | Some o ->
      let cs = List.mapi (fun c p -> (c, p)) (corners (obj_box d o)) in
      Option.map fst (List.find_opt (fun (_, (x, y)) -> Float.abs (x -. mx) <= 8. && Float.abs (y -. my) <= 8.) cs)
  | None -> None
