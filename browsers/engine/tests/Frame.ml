(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A page as a picture, without a window and without the network: the
 * file read, its sheets cascaded and computed (the page's <style>,
 * then the files given), the boxes laid out with the letters' own
 * widths (Browser_text.metrics: Hershey's), drawn as the playground's
 * shapes (Browser_boxes) and those as pixels (Shape_render_software),
 * written as a PPM. What mini-netscape will show in its window, before
 * there is one. No picture is read yet (Browser_picture).
 *
 * usage: frame [-w width] [-h height] [-scroll y] page.html out.ppm [sheet.css...] *)

let () =
  let read (file : string) : string = let ic = open_in_bin file in let s = really_input_string ic (in_channel_length ic) in close_in ic; s in
  let rec options (w, h, scroll) args =
    match args with
    | "-w" :: v :: rest -> options (int_of_string v, h, scroll) rest
    | "-h" :: v :: rest -> options (w, int_of_string v, scroll) rest
    | "-scroll" :: v :: rest -> options (w, h, float_of_string v) rest
    | rest -> ((w, h, scroll), rest)
  in
  match options (1000, 800, 0.) (List.tl (Array.to_list Sys.argv)) with
  | (w, h, scroll), page :: out :: sheets ->
      let width = float_of_int w and height = float_of_int h in
      let root = Html_tree.of_string (Charset.decode None (read page)) in
      let media : Cascade.media = { width; height } in
      let author (text : string) : Cascade.sheet = { origin = Author; rules = Css_syntax.parse_stylesheet text } in
      let sheets = author (Css.page_sheet root) :: List.map (fun f -> author (read f)) sheets in
      let t0 = Sys.time () in
      let styles = Computed.styles media sheets root in
      let t1 = Sys.time () in
      let box = Box_layout.layout Browser_text.metrics Html_layout.no_picture ~viewport:(width, height) styles root in
      let t2 = Sys.time () in
      let drawn = Browser_boxes.draw ~visited:(fun _ -> false) ~picture_of:(fun _ -> None) box in
      (* what is in the window, the page's top left at the window's *)
      let seen = List.filter_map (fun (top, bottom, shape) -> if bottom > scroll && top < scroll +. height then Some shape else None) drawn in
      let shapes = [ Playground.move (-.width /. 2.) ((height /. 2.) +. scroll) (Playground.group seen) ] in
      let fb = Framebuffer.create ~width:w ~height:h in
      Framebuffer.clear fb ~rgb:0xffffff;
      Shape_render_software.render ~options:Shape_render_software.default_options ~scale:1. fb shapes;
      let t3 = Sys.time () in
      let oc = open_out_bin out in
      output_string oc (Session.ppm fb);
      close_out oc;
      prerr_endline (Printf.sprintf "styles %.2f s, boxes %.2f s, %d shapes of %d drawn in %.2f s, the page %.0f high" (t1 -. t0) (t2 -. t1) (List.length seen) (List.length drawn) (t3 -. t2) box.height)
  | _ -> prerr_endline "usage: frame [-w width] [-h height] [-scroll y] page.html out.ppm [sheet.css...]"; exit 2
