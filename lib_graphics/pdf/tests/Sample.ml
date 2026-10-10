(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* usage: Sample out.pdf out.ppm
 * Two pages of 400 by 300: every form but a picture, moved, turned,
 * scaled, faded and grouped; then a picture (which the software
 * renderer does not draw yet: the second page has no PPM). The PPM is
 * Shape_render_software's of the first page's shapes, a pixel a
 * point: what write.sh holds another program's reading of the file to. *)

let width = 400.
let height = 300.

let first : Playground.shape list =
  let open Playground in
  [
    rectangle lightYellow 400. 300.;
    rectangle red 100. 60. |> move (-130.) 100.;
    rectangle blue 80. 30. |> move 0. 100. |> rotate 30.;
    circle green 30. |> move 120. 100.;
    oval purple 90. 40. |> move (-130.) 20. |> rotate (-20.);
    triangle orange 30. |> move (-20.) 20.;
    pentagon brown 30. |> move 50. 20.;
    polygon darkGray [ (0., 0.); (40., 10.); (30., 40.); (10., 25.); (-10., 35.) ] |> move 110. 0.;
    words black "Hello, PDF" |> move (-110.) (-50.) |> scale 2.;
    words blue "turned and small" |> move 80. (-50.) |> rotate 15.;
    circle red 40. |> move (-120.) (-100.) |> fade 0.5;
    circle blue 40. |> move (-80.) (-100.) |> fade 0.5;
    group [ square green 30.; words black "a group" |> move 0. (-25.) ] |> move 60. (-100.) |> scale 1.5 |> rotate 10.;
  ]

let second : Playground.shape list =
  let img = Rgba_image.create ~width:16 ~height:16 in
  for y = 0 to 15 do
    for x = 0 to 15 do
      Bytes.blit_string (String.init 4 (fun i -> Char.chr (match i with 0 -> x * 17 | 1 -> y * 17 | 2 -> 128 | _ -> 255 - (x * 8)))) 0 img.rgba (4 * ((y * 16) + x)) 4
    done
  done;
  let open Playground in
  [ rectangle gray 120. 120.; { x = 0.; y = 0.; angle = 20.; scale = 1.; alpha = 1.; form = Bitmap (160., 160., img) }; words black "a picture, turned" |> move 0. (-120.) ]

let () =
  Cap.main (fun caps ->
      match CapSys.argv caps with
      | [| _; pdf; ppm |] ->
          let file = Pdf_write.create ~compress:true in
          Shape_render_pdf.page file ~width ~height first;
          Shape_render_pdf.page file ~width ~height second;
          FS.write caps (Fpath.v pdf) (Pdf_write.to_string file);
          let fb = Framebuffer.create ~width:(int_of_float width) ~height:(int_of_float height) in
          Shape_render_software.render ~options:Shape_render_software.default_options ~scale:1. fb first;
          FS.write caps (Fpath.v ppm) (Session.ppm fb)
      | _ -> failwith "usage: Sample out.pdf out.ppm")
