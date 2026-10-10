(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)
(* ix: mini-chrome's tests/pdf/Unit_pdf_render.ml; the files are read by Testutil_pdf, and what was optional in the library is said (docs/plans/plan_pdf.md) *)

(* See Unit_pdf_render.mli *)

let t = Testo.create
let read = Testutil_pdf.read
let pdf (name : string) : Pdf.t = Pdf.of_string (read (name ^ ".pdf"))

(* how far two pictures are: the mean difference of their greys, 0 to
 * 255, each averaged over squares of 4 pixels (two renderers do not
 * smooth an edge alike) *)
let distance (a : Rgba_image.t) (b : Rgba_image.t) : float =
  let w = min a.width b.width / 4 and h = min a.height b.height / 4 in
  let grey (img : Rgba_image.t) bx by =
    let sum = ref 0 in
    for y = 4 * by to (4 * by) + 3 do
      for x = 4 * bx to (4 * bx) + 3 do
        let i = 4 * ((y * img.width) + x) in
        let part k = Char.code (Bytes.get img.rgba (i + k)) in
        sum := !sum + ((299 * part 0) + (587 * part 1) + (114 * part 2))
      done
    done;
    float_of_int !sum /. 16000.
  in
  let total = ref 0. in
  for by = 0 to h - 1 do for bx = 0 to w - 1 do total := !total +. Float.abs (grey a bx by -. grey b bx by) done done;
  !total /. float_of_int (max 1 (w * h))

(* a page drawn is poppler's picture of it, nearly *)
let check_page ~(within : float) (name : string) (page : int) () =
  let doc = pdf name in
  let ours = Pdf_render.render ~options:Pdf_render.full ~stroke_glyph:Pdf_render.hershey doc (Pdf_render.cache ()) (List.nth (Pdf.pages doc) (page - 1)) ~scale:1. in
  let theirs = Png.decode (read (Printf.sprintf "%s-%d.png" name page)) in
  Alcotest.(check bool) "the page's size" true (abs (ours.width - theirs.width) <= 1 && abs (ours.height - theirs.height) <= 1);
  let d = distance ours theirs in
  if d > within then Alcotest.failf "%s, page %d: %.2f away from poppler's picture (more than %.2f)" name page d within

(* and the test can tell: a page drawn plainly is further *)
let test_options () =
  let doc = pdf "shapes" in
  let page = List.hd (Pdf.pages doc) and theirs = Png.decode (read "shapes-1.png") in
  let away options = distance (Pdf_render.render ~options ~stroke_glyph:Pdf_render.hershey doc (Pdf_render.cache ()) page ~scale:1.) theirs in
  let full = away Pdf_render.full in
  List.iter
    (fun words ->
      let d = away (Pdf_render.options_of_string words) in
      if d < full +. 0.2 then Alcotest.failf "%s: %.2f, the full rendering %.2f" words d full)
    [ "plain"; "-clips"; "-gradients"; "-pictures"; "-transparency"; "strokes" ];
  Alcotest.(check bool) "words read" true
    (Pdf_render.options_of_string "strokes,-gradients" = { Pdf_render.full with letters = Strokes; gradients = false }
    && Pdf_render.options_of_string "plain,pictures" = { Pdf_render.plain with pictures = true }
    && Pdf_render.options_of_string "" = Pdf_render.full)

let test_text () =
  let words name page = let doc = pdf name in Pdf_render.text doc (Pdf_render.cache ()) (List.nth (Pdf.pages doc) (page - 1)) in
  let has text part = let n = String.length part in let rec go i = i + n <= String.length text && (String.sub text i n = part || go (i + 1)) in go 0 in
  let check name page part = let text = words name page in if not (has text part) then Alcotest.failf "%s, page %d: no %S in %S" name page part text in
  check "shapes" 1 "Hello, PDF";
  check "tex" 1 "Hello, PDF: italic and mathematics,";
  check "tex" 2 "Second page:";
  (* a ligature read as its letters, by the font's own table *)
  check "tex" 2 "fi fl ff.";
  check "browser" 1 "Printed by a browser: italic, bold.";
  check "browser" 1 "red words";
  check "office" 1 "Hello, PDF";
  check "cff" 1 "Bookman, a CFF font";
  check "standard" 1 "Helvetica, not embedded";
  (* a small step back between two strings is not a space *)
  check "standard" 1 "an office"

let test_size () =
  let doc = pdf "tex" in
  Alcotest.(check int) "two pages" 2 (List.length (Pdf.pages doc));
  let w, h = Pdf_render.size (List.hd (Pdf.pages doc)) in
  Alcotest.(check (pair (float 0.5) (float 0.5))) "10 cm by 5, in points" (283.5, 141.7) (w, h);
  let turned = { (List.hd (Pdf.pages doc)) with rotate = 90 } in
  Alcotest.(check (pair (float 0.5) (float 0.5))) "turned a quarter" (141.7, 283.5) (Pdf_render.size turned);
  let img = Pdf_render.render ~options:Pdf_render.full ~stroke_glyph:Pdf_render.hershey doc (Pdf_render.cache ()) turned ~scale:2. in
  Alcotest.(check (pair int int)) "its picture, at two dots a point" (284, 567) (img.width, img.height)

let tests =
  Testo.categorize "Pdf_render"
    [
      t "shapes: paths, a clip, transparency, a picture, gradients, TrueType" (check_page ~within:2. "shapes" 1);
      t "tex: Type 1 fonts, mathematics" (check_page ~within:2. "tex" 1);
      t "tex, page 2" (check_page ~within:2. "tex" 2);
      t "bitmap: Type 3 fonts" (check_page ~within:2. "bitmap" 1);
      t "cff: CFF fonts" (check_page ~within:2. "cff" 1);
      t "browser: TrueType by glyph number" (check_page ~within:2. "browser" 1);
      t "office: TrueType in Windows' encoding" (check_page ~within:2. "office" 1);
      t "standard: fonts not embedded, our letters at their widths" (check_page ~within:6. "standard" 1);
      t "each option off is further from the picture" test_options;
      t "a page's words" test_text;
      t "a page's size, turned" test_size;
    ]
