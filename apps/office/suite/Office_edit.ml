(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: a part of the author's playground's apps/office/TinyOffice.ml, its section Editing; what changed there is said in Office (docs/plans/plan_office.md) *)

(* See Office_edit.mli *)

open Document
open Office_page
open Office_templates
open Office_model

(*****************************************************************************)
(* Editing *)
(*****************************************************************************)

let record ~name d m = { m with history = Undo.record ~name:(Some name) d m.history; run = false }
let set_obj i (f : obj -> obj) (d : doc) = { d with objects = List.mapi (fun j o -> if j = i then f o else o) d.objects }

(* the end of an editing session in place: one edit, if it made one *)
let put_down m =
  match m.editing with
  | None -> m
  | Some d ->
      let before = Undo.now m.history in
      let saved (d : doc) = List.map (fun (o : obj) -> o.part.save ()) d.objects in
      let m = { m with editing = None } in
      if saved d = saved before then m else record ~name:"Edit Object" d m

(* a new object, in the middle of the page in view, selected *)
let insert ~link name part m =
  let m = put_down m in
  let d = doc m in
  let pw, ph = page_size d.kind in
  let w, h = match part.Component.natural with Some (w, h) -> (w, h) | None -> (300., 180.) in
  (* ix: one larger than the page inside its margins (a photograph, a
     unit a pixel) is put at the size that fits, its proportions kept *)
  let k = Float.min 1. (Float.min ((pw -. (2. *. margin)) /. w) ((ph -. (2. *. margin)) /. h)) in
  let w = w *. k and h = h *. k in
  let id = 1 + List.fold_left (fun n o -> max n o.id) 0 d.objects in
  let o = refreshed d { (obj ~slide:d.slide ~link part ((pw -. w) /. 2.) (d.scroll +. ((ph -. h) /. 2.)) w h) with id } in
  { (record ~name { d with objects = d.objects @ [ o ] } m) with selected = Some (List.length d.objects) }

let insert_image (bytes : string) m = insert ~link:None "Insert Image" (Part_image.make bytes) m

(* an object put at a place on the page, and given a size: tied to a
   paragraph, it keeps its distance from the paragraph's line *)
let place (d : doc) i ~x ~y ~w ~h =
  let p = List.nth (placed d) i in
  set_obj i (fun o -> { o with x; y = o.y +. (y -. p.y); w; h }) d

(* an object tied to the paragraph beside its top, or untied: either
   way it stays where it is *)
let tie (d : doc) i =
  let p = List.nth (placed d) i in
  match text_around d (List.filteri (fun j o -> j <> i && o.anchor = None) (placed d)) with
  | Some (r, page) ->
      let offset = Page.offset_at page (0., p.y -. margin) in
      let a = match String.rindex_from_opt (Rich.to_string r) (offset - 1) '\n' with Some j -> j + 1 | None -> 0 in
      set_obj i (fun o -> { o with anchor = Some a; y = p.y -. line_top page a }) d
  | None -> d

let untie (d : doc) i =
  let p = List.nth (placed d) i in
  set_obj i (fun o -> { o with anchor = None; y = p.y }) d

(* the text the keys go to *)
let current_text (d : doc) =
  match (d.area, d.body) with
  | Header _, _ -> Some d.header
  | Footer _, _ -> Some d.footer
  | Body, Texts ts -> Some (List.nth ts d.slide)
  | Body, Main _ -> None

let edit_text f m =
  let d = doc m in
  match (d.area, d.body) with
  | Header _, _ -> { d with header = f d.header }
  | Footer _, _ -> { d with footer = f d.footer }
  | Body, Texts ts ->
      let r = List.nth ts d.slide in
      let r' = f r in
      (* the paragraphs after the caret move along with what was typed
         or deleted there, and the objects tied to them *)
      let c = Rich.caret r and delta = String.length (Rich.to_string r') - String.length (Rich.to_string r) in
      let shift a = if a >= c then a + delta else if a > c + delta then c + delta else a in
      let objects = List.map (fun o -> if on_slide d o then { o with anchor = Option.map shift o.anchor } else o) d.objects in
      { d with body = Texts (List.mapi (fun i r -> if i = d.slide then r' else r) ts); objects }
  | Body, Main _ -> d

let a_run ~name d m = if m.run then { m with history = Undo.amend d m.history } else { (record ~name d m) with run = true }

let host_menus (d : doc) =
  [ File_menu.items; [ "Edit"; "Undo"; "Redo"; "Delete" ]; [ "Insert"; "Text Box"; "Sheet"; "Picture"; "Drawing"; "Chart"; "Image..." ];
    [ "Arrange"; "Scale to Fit"; "Natural Size"; "Bring to Front"; "Send to Back"; "Move with Text"; "Fix on Page"; "Wrap Wider Side"; "Wrap Both Sides"; "Top and Bottom"; "In Front of Text" ];
  ]
  @
  match (d.kind, d.body) with
  | Document, _ -> [ [ "Format"; "Bold"; "Italic"; "Bigger"; "Smaller" ] ]
  | Presentation, _ -> [ [ "Format"; "Bold"; "Italic"; "Bigger"; "Smaller" ]; [ "Slide"; "New Slide"; "Next"; "Previous"; "Show" ] ]
  | _, Main p -> [ p.menu ]
  | _, Texts _ -> []

(* the menu bar: the host's -- or, while an object is edited in place,
   File and the object's own, OLE 2's menu merging *)
let menus m =
  let d = doc m in
  match (m.editing, m.selected) with
  | Some _, Some i -> ( match List.nth_opt d.objects i with Some o when o.part.menu <> [] -> [ File_menu.items; o.part.menu ] | _ -> [ File_menu.items ])
  | _ -> host_menus d

let menu_box i : Widget.box = { Widget.x = -410. +. (float_of_int i *. 102.); y = 472.; w = 98.; h = 30. }

(* an object after a command of its own menu. ix: one whose natural
   size the command changed (a picture turned) keeps its scale, its
   frame taking the new shape *)
let commanded (c : string) (o : obj) : obj =
  let part = o.part.command c in
  match (o.part.natural, part.natural) with
  | Some (w, h), Some (w', h') when o.scaled && (w, h) <> (w', h') && w > 0. && h > 0. ->
      let k = Float.min (o.w /. w) (o.h /. h) in
      { o with part; w = w' *. k; h = h' *. k }
  | _ -> { o with part }

let command ~menu c m =
  let d = doc m in
  let on_selected f = match m.selected with Some i -> f i | None -> m in
  match (menu, c, m.editing, m.selected) with
  (* the object's own menu, while it is edited in place *)
  | _, c, Some e, Some i -> { m with editing = Some (set_obj i (commanded c) e) }
  | _ -> (
  match (menu, c) with
  | _, "Undo" -> let m = put_down m in { m with history = Undo.undo m.history; selected = None; run = false }
  | _, "Redo" -> let m = put_down m in { m with history = Undo.redo m.history; selected = None; run = false }
  | _, "Delete" ->
      (* the charts keep the numbers their sheet gave them last *)
      let d = refresh d in
      on_selected (fun i -> { (record ~name:"Delete" { d with objects = List.filteri (fun j _ -> j <> i) d.objects } m) with selected = None })
  | _, "Text Box" -> insert ~link:None "Insert Text Box" (Part_text.make (styled ~bold:false 18. "A text box: type in it.")) m
  | _, "Sheet" -> insert ~link:None "Insert Sheet" (Part_sheet.make ~cols:3 ~rows:5 budget) m
  | _, "Picture" -> insert ~link:None "Insert Picture" (Part_picture.make (Bitmap.create ~width:120 ~height:80)) m
  | _, "Drawing" -> insert ~link:None "Insert Drawing" (Part_drawing.make ~max_height:220. shapes) m
  | _, "Chart" -> (
      (* a chart of the sheet object selected, or of the sheet that is
         the document: linked to it, not a copy *)
      let link =
        match (Option.bind m.selected (List.nth_opt d.objects), d.body) with
        | Some o, _ when o.part.kind = Part_sheet.kind -> Some (Sheet_object o.id)
        | _, Main p when p.kind = Part_sheet.kind -> Some Main_sheet
        | _ -> None
      in
      match link with Some link -> insert ~link:(Some link) "Insert Chart" (Part_chart.make []) m | None -> m)
  | _, ("Move with Text" | "Fix on Page") -> (
      match d.body with
      | Texts _ -> on_selected (fun i -> record ~name:c ((if c = "Move with Text" then tie else untie) d i) m)
      | Main _ -> m)
  | _, ("Wrap Wider Side" | "Wrap Both Sides" | "Top and Bottom" | "In Front of Text") ->
      let wrap = match c with "Wrap Wider Side" -> Wider_side | "Wrap Both Sides" -> Both_sides | "Top and Bottom" -> Top_and_bottom | _ -> In_front in
      on_selected (fun i -> record ~name:c (set_obj i (fun o -> { o with wrap }) d) m)
  | "Slide", "Show" -> { (put_down m) with show = true; selected = None }
  | _, ("Scale to Fit" | "Natural Size") ->
      on_selected (fun i ->
          let scaled = c = "Scale to Fit" in
          record ~name:c
            (set_obj i
               (fun o ->
                 match (scaled, o.part.natural) with
                 (* its natural size: the frame made that size again *)
                 | false, Some (w, h) -> { o with scaled; w; h }
                 | _ -> { o with scaled })
               d)
            m)
  | _, "Bring to Front" ->
      on_selected (fun i ->
          let o = List.nth d.objects i in
          { (record ~name:c { d with objects = List.filteri (fun j _ -> j <> i) d.objects @ [ o ] } m) with selected = Some (List.length d.objects - 1) })
  | _, "Send to Back" ->
      on_selected (fun i ->
          let o = List.nth d.objects i in
          { (record ~name:c { d with objects = o :: List.filteri (fun j _ -> j <> i) d.objects } m) with selected = Some 0 })
  | "Format", ("Bold" | "Italic" | "Bigger" | "Smaller") ->
      (* the look of what is typed next, as TinyWord's with nothing
         selected *)
      let f =
        match c with
        | "Bold" -> Style.toggle_bold
        | "Italic" -> Style.toggle_italic
        | "Bigger" -> fun s -> { s with size = s.size *. 1.25 }
        | _ -> fun s -> { s with size = s.size /. 1.25 }
      in
      { (record ~name:c (edit_text (Rich.restyle f) m) m) with selected = None }
  | "Slide", "New Slide" -> (
      match d.body with
      | Texts ts ->
          let at = d.slide + 1 in
          let ts = List.concat (List.mapi (fun i r -> if i = d.slide then [ r; with_title "A new slide" "" ] else [ r ]) ts) in
          let objects = List.map (fun (o : obj) -> if o.slide >= at then { o with slide = o.slide + 1 } else o) d.objects in
          { (record ~name:c { d with body = Texts ts; slide = at; objects } m) with selected = None }
      | Main _ -> m)
  | "Slide", ("Next" | "Previous") -> (
      match d.body with
      | Texts ts ->
          let slide = max 0 (min (List.length ts - 1) (d.slide + if c = "Next" then 1 else -1)) in
          { m with history = Undo.amend { d with slide } m.history; selected = None }
      | Main _ -> m)
  | _, c -> (
      (* a command of the main part's own menu *)
      match d.body with
      | Main p when List.mem c p.menu -> record ~name:c { d with body = Main (p.command c) } m
      | _ -> m))
