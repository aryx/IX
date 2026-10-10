(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: a part of the author's playground's apps/office/TinyOffice.ml, its section View; what changed there is said in Office (docs/plans/plan_office.md) *)

(* See Office_view.mli *)

open Playground
open Document
open Office_page
open Office_model
open Office_update

(*****************************************************************************)
(* View *)
(*****************************************************************************)

let kind_icon k (b : Widget.box) =
  let at dx dy s = s |> move (b.x +. dx) (b.y +. dy) in
  let ink = rgb 60 60 70 in
  match k with
  | Document -> List.init 6 (fun i -> at 0. (40. -. (float_of_int i *. 14.)) (rectangle ink (if i = 5 then 50. else 80.) 4.))
  | Spreadsheet ->
      List.init 5 (fun i -> at 0. (40. -. (float_of_int i *. 18.)) (rectangle ink 90. 2.))
      @ List.init 4 (fun i -> at (-45. +. (float_of_int i *. 30.)) 4. (rectangle ink 2. 74.))
  | Presentation -> [ at 0. 10. (rectangle ink 96. 66.); at 0. 10. (rectangle white 90. 60.); at 0. 30. (rectangle ink 60. 6.); at 0. 4. (rectangle ink 40. 4.) ]
  | Picture -> [ at 0. 10. (rectangle ink 90. 70.); at 0. 10. (rectangle white 84. 64.); at 20. 25. (circle (rgb 120 120 120) 10.); at 0. (-12.) (rectangle ink 84. 3.) ]
  | Drawing_doc -> [ at (-20.) 20. (rectangle ink 40. 30.); at 25. 0. (oval (rgb 150 150 150) 40. 30.); at 0. 10. (rectangle ink 30. 2. |> rotate 30.) ]

let start_view model =
  [ rectangle (rgb 235 236 240) 1000. 1000.; words (rgb 30 30 40) "TinyOffice" |> scale 2.5 |> move 0. 260.; words (rgb 100 100 110) "What would you like to make?" |> move 0. 190. ]
  @ List.concat
      (List.mapi
         (fun i k ->
           let b = tile i in
           [ rectangle (rgb 200 200 205) (b.w +. 4.) (b.h +. 4.) |> move (b.x +. 3.) (b.y -. 3.); rectangle white b.w b.h |> move b.x b.y ]
           @ kind_icon k b
           @ [ words (rgb 40 40 50) (name k) |> move b.x (b.y -. 70.) ])
         kinds)
  @ [ words (rgb 120 120 130) "each kind can hold the others: a sheet in a document, a drawing on a sheet, a picture on a slide" |> move 0. (-150.) ]
  @ [ words (rgb 60 60 70) (File_menu.said model.file) |> move 0. (-280.) ]
  @ File_menu.view model.file
  @ Gui.draw ()

let glyphs_at_simple ink page ~x ~y =
  List.concat_map
    (fun (g : Page.glyph) ->
      if g.text = "\n" || g.text = " " then [] else Stroke_text.glyph ink g.style g.text ~x:(x +. g.x) ~baseline:(y -. g.baseline))
    (Page.glyphs page)

(* Optimization (Opti.enabled; ix's): a page's letters as shapes, kept
   while the same page is asked for in the same ink at the same place
   (Office_page says why). They are 8,000 shapes of a page of text,
   and they are one shape, a group, the same one given again: a
   platform that asks whether a frame is the last one does not look
   into it, and the view does not copy 8,000 places of a list to put
   the rest after them (on mini-9pi under QEMU a frame of a page
   nobody touches, the mouse moving over it, was 11 ms of view and 30
   of the platform's comparison, the processor never idle, and the
   mouse's own process waited for it: the author, 2026-10-09, "it is
   still very slow; just moving the cursor is slow"). *)
let glyphs_at : Playground.color -> Page.t -> x:float -> y:float -> Playground.shape list =
  let last : (Playground.color * Page.t * float * float * Playground.shape list) option ref = ref None in
  fun (ink : Playground.color) (page : Page.t) ~(x : float) ~(y : float) ->
    match !last with
    | Some (ink', page', x', y', shapes) when page' == page && ink' = ink && x' = x && y' = y && !Opti.enabled -> shapes
    | _ ->
        let shapes = glyphs_at_simple ink page ~x ~y in
        (* (the bands' few letters do not take the body's place)
         * old: the letters themselves, not their group:
         *   if List.length shapes > 200 then last := Some (ink, page, x, y, shapes); shapes *)
        if List.length shapes > 200 && !Opti.enabled then begin
          let shapes = [ Playground.group shapes ] in
          last := Some (ink, page, x, y, shapes);
          shapes
        end
        else shapes

let caret_at ink page offset ~x ~y =
  let cx, baseline, h = Page.caret_at page offset in
  [ rectangle ink 2. (h *. 0.8) |> move (x +. cx) (y -. baseline +. (h *. 0.25)) ]

(* what is on the pages: the main part, the text, the header and
   footer of every page, and the objects -- with [~chrome] the caret and
   the selection too, without them for the show *)
let page_shapes ~chrome (d : doc) model =
  let pw, _ = page_size d.kind in
  let l, t = origin d in
  let ink = rgb 20 20 20 and dim = rgb 150 150 150 in
  let text =
    match layout d with
    | Some (r, page) ->
        (* the body dimmed while the header or footer is edited, as
           Word does *)
        glyphs_at (if d.area = Body then ink else dim) page ~x:(l +. margin) ~y:(t -. margin)
        @ if chrome && model.selected = None && d.area = Body then caret_at ink page (Rich.caret r) ~x:(l +. margin) ~y:(t -. margin) else []
    | None -> []
  in
  let n = pages d in
  let bands =
    if d.kind <> Document then []
    else
      List.concat
        (List.init n (fun k ->
             let top = t -. (float_of_int k *. pitch d.kind) in
             List.concat_map
               (fun (which, r, here) ->
                 let shown = if here then r else with_fields ~page:(k + 1) ~pages:n r in
                 let page = band_layout d which shown in
                 let y = top -. band_top d which in
                 let edge = if which = Head then top -. margin +. 4. else top -. snd (page_size d.kind) +. margin -. 4. in
                 glyphs_at (if here then ink else rgb 110 110 110) page ~x:(l +. margin) ~y
                 @
                 if here && chrome then
                   (* where the header ends, or the footer starts *)
                   [ rectangle (rgb 40 90 200) (pw -. (2. *. margin)) 1. |> move (l +. (pw /. 2.)) edge ]
                   @ caret_at ink page (Rich.caret r) ~x:(l +. margin) ~y
                 else [])
               [ (Head, d.header, d.area = Header k); (Foot, d.footer, d.area = Footer k) ]))
  in
  let main = match d.body with Main p -> Component.draw_in ~scaled:false p (main_box d p) ~active:(chrome && model.selected = None) | Texts _ -> [] in
  let objects =
    List.concat
      (List.mapi
         (fun i o ->
           if not (on_slide d o) then []
           else
             let b = obj_box d o in
             let selected = chrome && model.selected = Some i in
             let active = selected && model.editing <> None in
             let frame =
               if active then Gui.shapes (Widget.frame (rgb 90 90 90) 4. { b with w = b.w +. 10.; h = b.h +. 10. })
               else if selected then
                 Gui.shapes (Widget.frame (rgb 40 90 200) 1. b) @ List.map (fun (x, y) -> rectangle (rgb 40 90 200) 9. 9. |> move x y) (corners b)
               else []
             in
             (* an object in front of the text keeps its page's white
                from hiding the lines under it *)
             (if o.wrap = In_front then [] else [ rectangle white b.w b.h |> move b.x b.y ])
             @ Component.draw_in ~scaled:o.scaled o.part b ~active @ frame)
         (placed d))
  in
  main @ text @ bands @ objects

(* the show: the slide scaled to fill the screen's width, on black *)
let show_view (d : doc) model =
  let pw, ph = page_size d.kind in
  let l, t = origin d in
  let k = 1000. /. pw in
  let slide = (rectangle white pw ph |> move (l +. (pw /. 2.)) (t -. (ph /. 2.))) :: page_shapes ~chrome:false d model in
  [ rectangle black 1000. 1000.; group [ group slide |> move (-.(l +. (pw /. 2.))) (-.(t -. (ph /. 2.))) ] |> scale k ]

let view _computer model =
  if model.start then start_view model
  else
    let d = doc model in
    if model.show then show_view d model
    else
    let pw, ph = page_size d.kind in
    let l, t = origin d in
    let n = pages d in
    let slides =
      match d.body with
      | Texts ts when d.kind = Presentation -> Printf.sprintf "     slide %d of %d" (d.slide + 1) (List.length ts)
      | _ when d.kind = Document -> Printf.sprintf "     %d page%s" n (if n > 1 then "s" else "")
      | _ -> ""
    in
    let status =
      Printf.sprintf "%s     %s%s     %s"
        (if File_menu.said model.file <> "" then File_menu.said model.file else File_menu.title model.file)
        (name d.kind) slides
        (match (model.editing, model.selected, d.area, Undo.undo_name model.history) with
        | Some _, _, _, _ -> "editing the object in place -- Escape to go back to the " ^ String.lowercase_ascii (name d.kind)
        | None, Some _, _, _ -> "selected: drag it, drag a corner, or click it again to edit it"
        | None, None, Header _, _ -> "editing the header, the same on every page -- click the page to go back"
        | None, None, Footer _, _ -> "editing the footer: {page} and {pages} are filled in by each page"
        | None, None, Body, Some u -> "Undo " ^ u
        | None, None, Body, None -> "")
    in
    let sheet k =
      let t = t -. (float_of_int k *. pitch d.kind) in
      [ rectangle (rgb 120 120 128) pw ph |> move (l +. (pw /. 2.) +. 5.) (t -. (ph /. 2.) -. 5.); rectangle white pw ph |> move (l +. (pw /. 2.)) (t -. (ph /. 2.)) ]
    in
    (rectangle (rgb 165 168 175) 1000. 1000. :: List.concat (List.init n sheet))
    @ page_shapes ~chrome:true d model
    (* the menu bar and the status line over the pages scrolled under them *)
    @ [
        rectangle (Gui.theme ()).face 1000. 48. |> move 0. 476.;
        rectangle (rgb 165 168 175) 1000. 60. |> move 0. (-470.);
        words (rgb 40 40 40) status |> move 0. (-455.);
      ]
    @ File_menu.view model.file
    @ Gui.draw ()
