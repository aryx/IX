(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* See Shape_render_pdf.mli *)

(* what the content's graphics state is, so that 8,000 strokes of one
 * ink say their colour once; -1: not said yet *)
type state = { mutable fill : int; mutable stroke : int; mutable alpha : int; mutable pen : int }

let hundredths (x : float) : int = int_of_float (Float.round (x *. 100.))

let set_alpha (file : Pdf_write.t) (c : Pdf_write.content) (st : state) (alpha : float) : unit =
  if st.alpha <> hundredths alpha then begin
    Pdf_write.opacity file c alpha;
    st.alpha <- hundredths alpha
  end

let filled (file : Pdf_write.t) (c : Pdf_write.content) (st : state) (rgb : int) (alpha : float) : unit =
  set_alpha file c st alpha;
  if st.fill <> rgb then begin
    Pdf_write.fill_color c rgb;
    st.fill <- rgb
  end

(* [m]: the form's own coordinates to the content's *)
let form (file : Pdf_write.t) (c : Pdf_write.content) (st : state) (m : Affine.t) (alpha : float) (form : Playground.form) : unit =
  let polygon (rgb : int) (corners : (float * float) list) =
    filled file c st rgb alpha;
    Pdf_write.polygon c (List.map (Affine.apply m) corners);
    Pdf_write.fill c
  in
  let oval (rgb : int) (rx : float) (ry : float) =
    filled file c st rgb alpha;
    Pdf_write.ellipse c m ~rx ~ry;
    Pdf_write.fill c
  in
  match form with
  | Rectangle (color, w, h) -> polygon (Shape_render_software.rgb_of_color color) (Shape_render_software.rectangle_corners w h)
  | Polygon (color, points) -> polygon (Shape_render_software.rgb_of_color color) points
  | Ngon (color, n, r) -> polygon (Shape_render_software.rgb_of_color color) (Shape_render_software.ngon_corners n r)
  | Circle (color, r) -> oval (Shape_render_software.rgb_of_color color) r r
  | Oval (color, w, h) -> oval (Shape_render_software.rgb_of_color color) (w /. 2.) (h /. 2.)
  | Image (w, h, _) -> polygon 0xc0c0c0 (Shape_render_software.rectangle_corners w h)
  | Bitmap (w, h, img) ->
      (* the picture's unit square made the form's box, about (0, 0);
       * its own state, so that the transform ends with it *)
      set_alpha file c st alpha;
      Pdf_write.save c;
      Pdf_write.transform c (Affine.compose m (Affine.compose (Affine.translate (-.w /. 2.) (-.h /. 2.)) (Affine.scale w h)));
      Pdf_write.draw c (Pdf_write.picture file img);
      Pdf_write.restore c
  | Words (color, str) ->
      let rgb = Shape_render_software.rgb_of_color color in
      let strokes, width = Hershey.layout str in
      let m = Affine.compose m (Shape_render_software.text_to_local ~width) in
      let pen = Shape_render_software.pen_width *. Shape_render_software.length_scale m in
      set_alpha file c st alpha;
      if st.stroke <> rgb then begin
        Pdf_write.stroke_color c rgb;
        st.stroke <- rgb
      end;
      if st.pen <> hundredths pen then begin
        Pdf_write.pen c pen;
        st.pen <- hundredths pen
      end;
      List.iter (fun (line : (float * float) list) -> Pdf_write.polyline c (List.map (Affine.apply m) line)) strokes;
      if strokes <> [] then Pdf_write.stroke c
  | Group _ -> ()

let rec shape (file : Pdf_write.t) (c : Pdf_write.content) (st : state) (m : Affine.t) (s : Playground.shape) : unit =
  let m = Affine.compose m (Shape_render_software.shape_transform s) in
  match s.form with
  | Group inside -> List.iter (shape file c st m) inside
  | f -> if s.alpha > 0. then form file c st m s.alpha f

let shapes (file : Pdf_write.t) (c : Pdf_write.content) (m : Affine.t) (all : Playground.shape list) : unit =
  let st = { fill = -1; stroke = -1; alpha = -1; pen = -1 } in
  Pdf_write.save c;
  List.iter (shape file c st m) all;
  Pdf_write.restore c

let page (file : Pdf_write.t) ~(width : float) ~(height : float) (all : Playground.shape list) : unit =
  let c = Pdf_write.content () in
  shapes file c (Affine.translate (width /. 2.) (height /. 2.)) all;
  Pdf_write.page file ~width ~height c
