(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: a part of the author's playground's apps/office/TinyOffice.ml, its section Update; what changed there is said in Office (docs/plans/plan_office.md) *)

(* See Office_update.mli *)

open Playground
open Document
open Office_page
open Office_templates
open Office_model
open Office_edit

(*****************************************************************************)
(* Update *)
(*****************************************************************************)

let tile i : Widget.box = { Widget.x = -360. +. (float_of_int i *. 180.); y = 30.; w = 150.; h = 180. }

let text_keys computer m =
  let k = computer.keyboard in
  let now = Set_.elements k.keys in
  let pressed key = List.mem key now && not (List.mem key m.was) in
  let d = doc m in
  match current_text d with
  | None -> m
  | Some r ->
      let text = Rich.to_string r and c = Rich.caret r in
      let move to_ = { m with history = Undo.amend (edit_text (Rich.at to_) m) m.history; run = false } in
      if k.typed <> "" then a_run ~name:"Typing" (edit_text (Rich.insert k.typed) m) m
      else if pressed "Enter" then a_run ~name:"Typing" (edit_text (Rich.insert "\n") m) m
      else if pressed "Backspace" then a_run ~name:"Typing" (edit_text Rich.delete_backward m) m
      else if pressed "ArrowLeft" then move (Text.prev_char text c)
      else if pressed "ArrowRight" then move (Text.next_char text c)
      else m

(* the mouse went down on the page, not on the object being edited *)
let press m (mx, my) =
  let d = doc m in
  let m = { m with pressed_at = (mx, my); again = false; run = false } in
  match Option.bind m.selected (fun i -> Option.map (fun c -> (i, c)) (corner_at d i (mx, my))) with
  | Some (_, c) when m.editing = None -> { m with drag = Some (Resizing c); live = Some d }
  | _ -> (
      match object_at d (mx, my) with
      | Some i ->
          let m = put_down m in
          let d = doc m in
          let o = List.nth (placed d) i in
          let b = obj_box d o in
          {
            m with
            again = m.selected = Some i;
            selected = Some i;
            drag = Some (Moving (mx -. Widget.left b, Widget.top b -. my));
            live = Some d;
          }
      | None -> (
          let m = { (put_down m) with selected = None } in
          let d = doc m in
          (* in a text, the caret goes where the click was *)
          match layout d with
          | Some (_, page) ->
              let px, py = to_page d (mx, my) in
              (* in a document's top or bottom margin: its header or its
                 footer, on the page clicked *)
              let k = int_of_float (Float.max 0. (py /. pitch d.kind)) in
              let y = py -. (float_of_int k *. pitch d.kind) in
              let area =
                if d.kind <> Document then Body
                else if y < margin then Header k
                else if y > snd (page_size d.kind) -. margin then Footer k
                else Body
              in
              let d = { d with area } in
              let o =
                match area with
                | Body -> Page.offset_at page (px -. margin, py -. margin)
                | Header _ -> Page.offset_at (band_layout d Head d.header) (px -. margin, y -. band_top d Head)
                | Footer _ -> Page.offset_at (band_layout d Foot d.footer) (px -. margin, y -. band_top d Foot)
              in
              let m = { m with history = Undo.amend d m.history } in
              { m with history = Undo.amend (edit_text (Rich.at o) m) m.history }
          | None -> m))

let dragging m (mx, my) =
  let base = Undo.now m.history in
  match (m.drag, m.selected) with
  | Some (Moving (gx, gy)), Some i ->
      let x, y = to_page base (mx -. gx, my +. gy) in
      let o = List.nth base.objects i in
      { m with live = Some (place base i ~x ~y ~w:o.w ~h:o.h) }
  | Some (Resizing c), Some i ->
      let o = List.nth (placed base) i in
      let px, py = to_page base (mx, my) in
      (* the opposite corner stays where it is *)
      let ax = if c = 0 || c = 3 then o.x +. o.w else o.x and ay = if c = 0 || c = 1 then o.y +. o.h else o.y in
      let x = Float.min ax px and y = Float.min ay py in
      let w = Float.max 30. (Float.abs (px -. ax)) and h = Float.max 30. (Float.abs (py -. ay)) in
      { m with live = Some (place base i ~x ~y ~w ~h) }
  | _ -> m

let release m (mx, my) =
  let before = Undo.now m.history in
  let boxes d = List.map (fun o -> (o.x, o.y, o.w, o.h)) d.objects in
  let moved = Float.abs (mx -. fst m.pressed_at) +. Float.abs (my -. snd m.pressed_at) > 3. in
  let m =
    match (m.drag, m.live) with
    (* a click on the object already selected, with no drag: edit it
       where it is *)
    | Some (Moving _), _ when m.again && not moved -> { m with editing = Some before; live = None }
    | Some drag, Some l when boxes l <> boxes before ->
        (* an object tied to a paragraph and moved is tied to the one
           it now stands beside *)
        let l = match (drag, m.selected) with Moving _, Some i when (List.nth l.objects i).anchor <> None -> tie l i | _ -> l in
        { (record ~name:(match drag with Moving _ -> "Move" | Resizing _ -> "Resize") l m) with live = None }
    | _ -> { m with live = None }
  in
  { m with drag = None }

(* the pages scrolled by dy, no further than the first page's top and
   the last page's *)
let scrolled dy m =
  let d = doc m in
  let scroll = Float.max 0. (Float.min (float_of_int (pages d - 1) *. pitch d.kind) (d.scroll +. dy)) in
  if d.kind <> Document || scroll = d.scroll then m else { m with history = Undo.amend { d with scroll } m.history }

(* after typing, the pages scrolled for the caret to stay in view *)
let follow m =
  let d = doc m in
  match (d.kind, layout d) with
  | Document, Some (r, page) when d.area = Body ->
      let _, baseline, h = Page.caret_at page (Rich.caret r) in
      let y = snd (origin d) -. margin -. baseline in
      if y < -420. then scrolled (-420. -. y) m else if y +. h > 440. then scrolled (440. -. y -. h) m else m
  | _ -> m

let reopened (r : saved File_menu.result) model =
  match r with
  | File_menu.Nothing -> model
  | File_menu.New -> { initial with start = true; file = model.file }
  | File_menu.Opened d -> { initial with start = false; history = Undo.start ~limit:100 (of_saved d); file = model.file }
  (* ix: Insert > Image...'s file *)
  | File_menu.Chosen (name, bytes) -> (
      try insert_image bytes model with Failure why -> { model with file = File_menu.say (name ^ ": " ^ why) model.file })

(* where the start screen's Open... is *)
let open_button : Widget.box = { Widget.x = 0.; y = -220.; w = 140.; h = 36. }

let update caps ~(exported : model -> string) computer model =
  let mouse = computer.mouse in
  let now = Set_.elements computer.keyboard.keys in
  let current () = to_saved (doc (put_down model)) in
  if File_menu.busy model.file then
    let file, r = File_menu.dialog caps Document.file_kind computer ~current model.file in
    reopened r { model with file; was = now; was_down = mouse.mdown }
  else
  let pressed key = List.mem key now && not (List.mem key model.was) in
  let press_edge = mouse.mdown && not model.was_down in
  let model =
    if model.start then
      (* the start screen: the kinds, as tiles -- or a document saved
         before *)
      if Gui.button_in ~enabled:true computer open_button "Open..." then
        let file, r = File_menu.command caps Document.file_kind ~current "Open..." model.file in
        reopened r { model with file }
      else
      match List.find_opt (fun (i, _) -> press_edge && Widget.contains (tile i) mouse.mx mouse.my) (List.mapi (fun i k -> (i, k)) kinds) with
      | Some (_, k) -> { initial with start = false; history = Undo.start ~limit:100 (fresh k); file = File_menu.start }
      | None -> model
    else if model.show then
      (* the show: a click or the keys on to the next slide, past the
         last back to editing *)
      let d = doc model in
      let go dir =
        let slide = d.slide + dir in
        match d.body with
        | Texts ts when slide >= 0 && slide < List.length ts -> { model with history = Undo.amend { d with slide } model.history }
        | _ when dir > 0 -> { model with show = false }
        | _ -> model
      in
      if pressed "Escape" then { model with show = false }
      else if mouse.mclick || pressed "ArrowRight" || pressed " " || pressed "PageDown" then go 1
      else if pressed "ArrowLeft" || pressed "PageUp" then go (-1)
      else model
    else
      let model =
        List.fold_left
          (fun model (i, items) ->
            if i = 0 then
              (* ix: Export is a PDF of the pages (docs/plans/plan_pdf.md),
                 where the playground's menu writes the document as
                 Save does; the menu's other items are File_menu's *)
              let item = List.nth File_menu.items (Gui.menu_in computer (menu_box i) File_menu.items 0) in
              if item = "Export" then { model with file = File_menu.export caps ~extension:".pdf" (exported (put_down model)) model.file }
              else if item = "File" then model
              else
              let file, r = File_menu.command caps Document.file_kind ~current item model.file in
              reopened r { model with file }
            else
            match List.nth_opt items (Gui.menu_in computer (menu_box i) items 0) with
            (* ix: a file to choose: the File menu's dialog, and its
               capabilities, which a command has not *)
            | Some "Image..." -> { model with file = File_menu.choose caps ~extensions:Image_file.extensions model.file }
            | Some c when c <> List.hd items -> command ~menu:(List.hd items) c model
            | _ -> model)
          model
          (List.mapi (fun i items -> (i, items)) (menus model))
      in
      if Gui.modal () then model
      else
        let d = doc model in
        let p = (mouse.mx, mouse.my) in
        let in_active =
          match (model.editing, model.selected) with
          | Some _, Some i -> ( match List.nth_opt (placed d) i with Some o -> Widget.contains (obj_box d o) mouse.mx mouse.my | None -> false)
          | _ -> false
        in
        let model =
          match model.drag with
          | Some _ when mouse.mdown -> dragging model p
          | Some _ -> release model p
          (* a press on the menu bar is the menu's, not the page's under it *)
          | None when press_edge && (not in_active) && mouse.my < Widget.bottom (menu_box 0) -> press model p
          | None -> model
        in
        let d = doc model in
        (* who gets the mouse and the keys: the object edited in place,
           or else -- no object selected -- the document's own content *)
        let model =
          match (model.editing, model.selected, d.body) with
          | Some d, Some i, _ -> (
              match List.nth_opt (placed d) i with
              | Some o ->
                  let part = Component.input_in ~scaled:o.scaled o.part computer (obj_box d o) in
                  let model = { model with editing = Some (set_obj i (fun o -> { o with part }) d) } in
                  if pressed "Escape" then put_down model else model
              | None -> model)
          | None, Some _, _ ->
              if pressed "Backspace" || pressed "Delete" then command ~menu:"Edit" "Delete" model
              else if pressed "Escape" then { model with selected = None }
              else model
          | None, None, Main p when model.drag = None ->
              let p' = p.input computer (main_box d p) in
              if p'.save () <> p.save () then a_run ~name:"Edit" { d with body = Main p' } model
              else { model with history = Undo.amend { d with body = Main p' } model.history }
          | None, None, Texts _ ->
              let model' = text_keys computer model in
              if model' != model then follow model' else model
          | _ -> model
        in
        (* the wheel, and the page keys, scroll a document's pages *)
        if model.editing <> None || model.drag <> None then model
        else if mouse.mwheel <> 0. then scrolled (-.mouse.mwheel *. 60.) model
        else if pressed "PageDown" then scrolled 700. model
        else if pressed "PageUp" then scrolled (-700.) model
        else model
  in
  { model with was = now; was_down = mouse.mdown }
