(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: a part of the author's playground's apps/office/TinyOffice.ml, its section New documents, one of each kind; what changed there is said in Office (docs/plans/plan_office.md) *)

(* See Office_templates.mli *)

open Document

(*****************************************************************************)
(* New documents, one of each kind *)
(*****************************************************************************)

let styled ~bold size s = Rich.of_string ~style:{ Style.plain with size; bold } s

let with_title title body =
  let r = Rich.of_string ~style:Style.plain (title ^ "\n" ^ body) in
  Rich.at 0 (Rich.restyle (fun s -> { (Style.toggle_bold s) with size = 26. }) (Rich.select ~anchor:0 ~caret:(String.length title) r))

let budget =
  List.fold_left
    (fun s (cell, v) -> Sheet.set cell v s)
    Sheet.empty
    [ ((0, 0), "Paper"); ((1, 0), "12"); ((0, 1), "Ink"); ((1, 1), "30"); ((0, 2), "Stamps"); ((1, 2), "8"); ((0, 3), "Total"); ((1, 3), "=SUM(B1:B3)") ]

let shapes =
  let add f d = fst (Drawing.add f d) in
  let st = { Figure.fill = Some 1.; pen = 2. } in
  Drawing.empty
  |> add (Figure.Rect (Figure.box (30., 110.) (130., 170.), st))
  |> add (Figure.Rect (Figure.box (170., 110.) (270., 170.), st))
  |> add (Figure.Line ((130., 140.), (170., 140.), { st with fill = None }))
  |> add (Figure.Oval (Figure.box (100., 20.) (200., 80.), { Figure.fill = Some 0.7; pen = 2. }))

let obj ~slide ~link part x y w h = { id = 0; part; slide; x; y; w; h; scaled = part.Component.natural <> None; anchor = None; link; wrap = Wider_side }

(* a new document: its objects numbered *)
let new_doc kind body objects =
  refresh
    {
      kind;
      body;
      slide = 0;
      header = styled ~bold:false 12. "TinyOffice, a document";
      footer = styled ~bold:false 12. "page {page} of {pages}";
      area = Body;
      scroll = 0.;
      objects = List.mapi (fun i o -> { o with id = i + 1 }) objects;
    }

let fresh kind =
  match kind with
  | Document ->
      new_doc kind
          (Texts
            [
              with_title "TinyOffice"
                "A document, the first of the five kinds. The sheet on the right floats on the page: drag it, and \
                 this text runs round it as you do; drag one of its corners, and it is scaled to its new size. \
                 Click it again to edit it where it is -- the menu bar becomes the sheet's, the File menu stays, \
                 and Escape brings the document back.\n\n\
                 Insert puts a text box, a sheet, a picture or a drawing on the page, and every kind of document \
                 can hold every other: a drawing over a spreadsheet, a picture on a slide. Arrange brings an \
                 object to the front or sends it back, scales it or gives it its natural size, ties it to \
                 its paragraph so that it moves with the text, and chooses how the text goes round it. Click \
                 the top or the bottom margin to edit the header or the footer. \
                 With the sheet selected, Insert > Chart makes a chart of it -- linked, not copied: change \
                 a number in the sheet, and its bar follows.\n\n\
                 File > New goes back to the choice of the five kinds.";
            ])
        [ obj ~slide:0 ~link:None (Part_sheet.make ~cols:3 ~rows:5 budget) 360. 150. 220. 106. ]
  | Presentation ->
      new_doc kind
        (Texts
           [
             with_title "A presentation" "\nwith a drawing floating on its first slide, and a sheet on its second -- Slide > Next.";
             with_title "The figures" "\nThe same sheet as in a document, on a slide.";
           ])
        [ obj ~slide:0 ~link:None (Part_drawing.make ~max_height:220. shapes) 440. 200. 300. 200.; obj ~slide:1 ~link:None (Part_sheet.make ~cols:3 ~rows:5 budget) 400. 190. 330. 159. ]
  | Spreadsheet ->
      let sheet =
        List.fold_left
          (fun s (cell, v) -> Sheet.set cell v s)
          Sheet.empty
          [ ((0, 0), "Month"); ((1, 0), "Sales"); ((0, 1), "Jan"); ((1, 1), "120"); ((0, 2), "Feb"); ((1, 2), "150"); ((0, 3), "Mar"); ((1, 3), "90"); ((0, 5), "Total"); ((1, 5), "=SUM(B2:B4)") ]
      in
      (* and a chart of its sales, linked to it: typed in, a number
         changes its bar *)
      new_doc kind
        (Main (Part_sheet.make ~cols:7 ~rows:18 sheet))
        [ obj ~slide:0 ~link:None (Part_drawing.make ~max_height:220. shapes) 430. 60. 330. 220.; obj ~slide:0 ~link:(Some Main_sheet) (Part_chart.make []) 430. 330. 300. 200. ]
  | Picture ->
      let bits =
        Bitmap.change (Bitmap.create ~width:190 ~height:150) (fun b ->
            Paint.fill_oval b Pattern.grey (120, 20) (170, 70);
            Paint.frame_oval b Pattern.solid (120, 20) (170, 70);
            Paint.stroke b ~brush:Paint.pencil Pattern.solid (0, 120) (189, 120))
      in
      new_doc kind (Main (Part_picture.make bits)) [ obj ~slide:0 ~link:None (Part_text.make (styled ~bold:false 18. "A caption, in a text box floating on the picture.")) 40. 340. 300. 60. ]
  | Drawing_doc ->
      new_doc kind (Main (Part_drawing.make ~max_height:560. shapes)) [ obj ~slide:0 ~link:None (Part_sheet.make ~cols:3 ~rows:5 budget) 440. 380. 300. 144. ]
