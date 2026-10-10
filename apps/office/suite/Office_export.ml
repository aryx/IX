(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* See Office_export.mli *)

(* A document's pages are one column on the screen, page k a pitch
 * under page k - 1 (Office_page), and the view draws them all at
 * once. So the column is written once, as a form, and each page of
 * the file is that form moved so that its own page is on the paper:
 * the paper's edges cut the rest.
 *
 *      the form (the screen's coordinates)        page 2 of the file
 *    t  +--------+
 *       | page 1 |
 *       +--------+                                  +--------+  ph
 *       +--------+  t - pitch          moved        | page 2 |
 *       | page 2 |                 ------------>    +--------+  0
 *       +--------+  t - pitch - ph                  0       pw
 *       l        l + pw
 *)
let pdf (model : Office_model.model) : string =
  (* as it is read, not as it is edited: from its top, the body's ink
   * not dimmed for a header being typed, the fields filled *)
  let d : Document.doc = { (Office_model.doc model) with scroll = 0.; area = Body } in
  let file = Pdf_write.create ~compress:true in
  let pw, ph = Office_page.page_size d.kind in
  let pitch = Office_page.pitch d.kind in
  let slides = match d.body with Texts ts -> List.length ts | Main _ -> 1 in
  for slide = 0 to slides - 1 do
    let d = { d with slide } in
    let l, t = Office_page.origin d in
    let n = Office_page.pages d in
    let column = Pdf_write.content () in
    Shape_render_pdf.shapes file column Affine.identity (Office_view.page_shapes ~chrome:false d model);
    let column = Pdf_write.form file (l, t -. (float n *. pitch), l +. pw, t) column in
    for k = 0 to n - 1 do
      let c = Pdf_write.content () in
      Pdf_write.transform c (Affine.translate (-.l) (-.(t -. (float k *. pitch) -. ph)));
      Pdf_write.draw c column;
      Pdf_write.page file ~width:pw ~height:ph c
    done
  done;
  Pdf_write.to_string file
