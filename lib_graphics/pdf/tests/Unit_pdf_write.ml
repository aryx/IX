(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* A file written is checked as a reader would start on it: the table
 * found from the end, and each of its lines leading to the object it
 * says. And a shape's operators, read by eye in a file not deflated. *)

let t = Testo.create

(* where [sub] starts in [s], from [from]; -1 if nowhere *)
let find (s : string) (from : int) (sub : string) : int =
  let n = String.length sub in
  let rec go i = if i + n > String.length s then -1 else if String.sub s i n = sub then i else go (i + 1) in
  go from

let has (s : string) (sub : string) : bool = find s 0 sub >= 0

(* the file's last "startxref": the table's place *)
let table (s : string) : int =
  let rec last i found = match find s i "startxref\n" with -1 -> found | j -> last (j + 1) j in
  let at = last 0 (-1) + String.length "startxref\n" in
  int_of_string (String.sub s at (String.index_from s at '\n' - at))

let one_page ~(compress : bool) (shapes : Playground.shape list) : string =
  let file = Pdf_write.create ~compress in
  Shape_render_pdf.page file ~width:200. ~height:100. shapes;
  Pdf_write.to_string file

let test_table () =
  let s = one_page ~compress:false [ Playground.rectangle Playground.red 20. 10. ] in
  Alcotest.(check string) "the first line" "%PDF-1.4\n" (String.sub s 0 9);
  Alcotest.(check bool) "the last" true (String.ends_with ~suffix:"%%EOF\n" s);
  let at = table s in
  Alcotest.(check string) "the table is where the end says" "xref\n0 6\n" (String.sub s at 9);
  (* five objects: the three every file has, a content, a page; each
   * line of the table is 20 bytes and leads to "n 0 obj" *)
  for n = 1 to 5 do
    let line = String.sub s (at + 9 + (20 * n)) 20 in
    let start = int_of_string (String.sub line 0 10) in
    let head = Printf.sprintf "%d 0 obj\n" n in
    Alcotest.(check string) (Printf.sprintf "object %d" n) head (String.sub s start (String.length head))
  done;
  Alcotest.(check bool) "one page" true (has s "/Kids [5 0 R] /Count 1");
  Alcotest.(check bool) "its size" true (has s "/MediaBox [0 0 200 100]")

let test_operators () =
  let s = one_page ~compress:false [ Playground.rectangle Playground.red 20. 10. |> Playground.move 10. 0. ] in
  (* the page's centre is (100, 50): the box from (100, 45) to (120, 55) *)
  Alcotest.(check bool) "a rectangle" true (has s "100 55 m 120 55 l 120 45 l 100 45 l h\nf\n");
  let s = one_page ~compress:false [ Playground.rectangle Playground.red 20. 10.; Playground.rectangle Playground.red 4. 4. |> Playground.fade 0.5 ] in
  (* a colour is said once; an opacity when it changes *)
  let first = find s 0 " rg\n" in
  Alcotest.(check int) "one colour for two shapes" (-1) (find s (first + 1) " rg\n");
  Alcotest.(check bool) "opaque, then half" true (find s 0 "/A100 gs\n" >= 0 && find s 0 "/A50 gs\n" > find s 0 "/A100 gs\n");
  Alcotest.(check bool) "said in the resources" true (has s "/A50 << /ca 0.5 /CA 0.5 >>");
  let s = one_page ~compress:false [ Playground.words Playground.black "l" ] in
  Alcotest.(check bool) "a letter is a stroke" true (has s " w 1 J 1 j\n" && has s "S\n");
  Alcotest.(check int) "and nothing filled" (-1) (find s 0 "\nf\n")

let test_deflated () =
  let shapes = List.init 50 (fun i -> Playground.circle Playground.blue 5. |> Playground.move (float i) 0.) in
  let plain = one_page ~compress:false shapes and small = one_page ~compress:true shapes in
  Alcotest.(check bool) "smaller" true (String.length small < String.length plain / 2);
  let at = find small 0 "stream\n" + String.length "stream\n" in
  let content, _ = Zlib.inflate (String.sub small at (String.length small - at)) in
  Alcotest.(check bool) "a stream inflated is the content" true (has plain content && has content " c h\nf\n")

let test_picture () =
  let img = Rgba_image.create ~width:2 ~height:1 in
  Bytes.blit_string "\255\000\000\255\000\255\000\128" 0 img.rgba 0 8;
  let s = one_page ~compress:false [ ({ x = 0.; y = 0.; angle = 0.; scale = 1.; alpha = 1.; form = Bitmap (20., 10., img) } : Playground.shape) ] in
  Alcotest.(check bool) "its colours, three bytes a pixel" true (has s "stream\n\255\000\000\000\255\000\nendstream");
  Alcotest.(check bool) "its opacities apart, a pixel being half there" true (has s "/ColorSpace /DeviceGray" && has s "stream\n\255\128\nendstream");
  Alcotest.(check bool) "its box" true (has s "20 0 0 10 90 45 cm\n")

(* what is written, read back by the reader, is what the screen
 * shows: every form but a picture's file, moved, turned, scaled,
 * faded and grouped; and a picture, turned *)
let test_read_back () =
  let width = 400. and height = 300. in
  let img = Rgba_image.create ~width:16 ~height:16 in
  for i = 0 to 255 do
    Bytes.blit_string (String.init 4 (fun (k : int) -> Char.chr (match k with 0 -> i mod 16 * 17 | 1 -> i / 16 * 17 | 2 -> 128 | _ -> 255))) 0 img.rgba (4 * i) 4
  done;
  let shapes : Playground.shape list =
    let open Playground in
    [
      rectangle lightYellow 400. 300.;
      rectangle red 100. 60. |> move (-130.) 100.;
      rectangle blue 80. 30. |> move 0. 100. |> rotate 30.;
      circle green 30. |> move 120. 100.;
      oval purple 90. 40. |> move (-130.) 20. |> rotate (-20.);
      triangle orange 30. |> move (-20.) 20.;
      polygon darkGray [ (0., 0.); (40., 10.); (30., 40.); (10., 25.); (-10., 35.) ] |> move 110. 0.;
      words black "Hello, PDF" |> move (-110.) (-50.) |> scale 2.;
      circle red 40. |> move (-120.) (-100.) |> fade 0.5;
      circle blue 40. |> move (-80.) (-100.) |> fade 0.5;
      group [ square green 30.; words black "a group" |> move 0. (-25.) ] |> move 60. (-100.) |> scale 1.5 |> rotate 10.;
      bitmap 64. 64. img |> move 150. (-100.) |> rotate 20.;
    ]
  in
  let fb = Framebuffer.create ~width:(int_of_float width) ~height:(int_of_float height) in
  Shape_render_software.render ~options:Shape_render_software.default_options ~scale:1. fb shapes;
  let read ~(compress : bool) (shapes : Playground.shape list) : Rgba_image.t =
    let file = Pdf_write.create ~compress in
    Shape_render_pdf.page file ~width ~height shapes;
    let pdf = Pdf.of_string (Pdf_write.to_string file) in
    Pdf_render.render ~options:Pdf_render.full ~stroke_glyph:Pdf_render.hershey pdf (Pdf_render.cache ()) (List.hd (Pdf.pages pdf)) ~scale:1.
  in
  let d = Testutil_pdf.away fb (read ~compress:true shapes) in
  if d > 1. then Alcotest.failf "read back: %.2f away from the screen's picture" d;
  Alcotest.(check bool) "deflated or not, the same page" true ((read ~compress:true shapes).rgba = (read ~compress:false shapes).rgba);
  (* and the test can tell: a shape less is further *)
  let less = Testutil_pdf.away fb (read ~compress:true (List.tl (List.rev shapes))) in
  if less < d +. 0.3 then Alcotest.failf "a shape less: %.2f, all of them %.2f" less d

(* (Zlib's, which a PNG is read with: here because the tests'
 * pictures are PNG files, and a CRC by halves is what arm reads them
 * by) *)
let test_crc_by_halves () =
  List.iter
    (fun (s : string) ->
      let hi, lo = Zlib.crc32_halves s ~pos:0 ~len:(String.length s) in
      Alcotest.(check int) (Printf.sprintf "%S" s) (Zlib.crc32 s) ((hi lsl 16) lor lo))
    [ ""; "a"; "abc"; "IHDR\000\000\001\144\000\000\001\044\008\002\000\000\000"; String.make 1000 '\255' ];
  Alcotest.(check (pair int int)) "abc is 352441c2" (0x3524, 0x41c2) (Zlib.crc32_halves "abc" ~pos:0 ~len:3);
  (* a picture written is read back: its chunks' CRCs are right *)
  let img = Rgba_image.create ~width:3 ~height:2 in
  Bytes.blit_string "\001\002\003\255\004\005\006\255\007\008\009\255\010\011\012\255\013\014\015\255\016\017\018\255" 0 img.rgba 0 24;
  Alcotest.(check bool) "a PNG written, then read" true ((Png.decode (Png.encode ~alpha:true ~filter:None img)).rgba = img.rgba)

let tests =
  [
    t "written, then read back: the screen's picture" test_read_back;
    t "a CRC by halves, and a PNG written" test_crc_by_halves;
    t "a file's table leads to its objects" test_table;
    t "shapes as operators" test_operators;
    t "a stream deflated" test_deflated;
    t "a picture and its transparency" test_picture;
  ]
