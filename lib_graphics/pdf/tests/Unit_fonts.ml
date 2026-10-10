(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)
(* ix: mini-chrome's tests/pdf/Unit_fonts.ml; the files are read by Testutil_pdf, and what was optional in the library is said (docs/plans/plan_pdf.md) *)

(* See Unit_fonts.mli *)

let t = Testo.create
let read = Testutil_pdf.read

(* the fonts of a test file's first page, by the kind of their glyphs *)
let fonts (name : string) : Pdf_font.t list =
  let pdf = Pdf.of_string (read (name ^ ".pdf")) in
  let page = List.hd (Pdf.pages pdf) in
  List.map (fun (_, v) -> Pdf_font.load pdf v) (Pdf.dict pdf (Pdf.get pdf (Pdf.dict pdf page.resources) "Font"))

(* a capital H (or F) in any font: stems and a bar -- one contour,
 * about 0.7 em high, standing on the baseline *)
let check_h (name : string) (code : int) () =
  let found =
    List.exists
      (fun (f : Pdf_font.t) ->
        match f.glyph code with
        | Shape o -> (
            match Outline.bounds o with
            | Some (x0, y0, x1, y1) -> List.length o = 1 && Float.abs y0 < 0.02 && y1 > 0.6 && y1 < 0.8 && x1 -. x0 > 0.4 && x1 -. x0 < 0.9 && f.width code > 0.5 && f.width code < 1.
            | None -> false)
        | _ -> false)
      (fonts name)
  in
  if not found then Alcotest.failf "%s: no font whose code %d is an H" name code

let test_outline () =
  let square : Outline.t = [ { start = (0., 0.); segments = [ Line (10., 0.); Line (10., 10.); Line (0., 10.); Line (0., 0.) ] } ] in
  Alcotest.(check (list (list (pair (float 0.) (float 0.))))) "a polygon, its points through a transform"
    [ [ (1., 1.); (21., 1.); (21., 21.); (1., 21.); (1., 1.) ] ]
    (Outline.polygons ~tolerance:0.1 (fun (x, y) -> ((2. *. x) +. 1., (2. *. y) +. 1.)) square);
  Alcotest.(check bool) "bounds" true (Outline.bounds square = Some (0., 0., 10., 10.) && Outline.bounds [] = None);
  (* a quadratic curve is the cubic with its control points two thirds of the way: the same points *)
  let quadratic : Outline.t = [ { start = (0., 0.); segments = [ Quadratic ((50., 100.), (100., 0.)) ] } ] in
  let cubic : Outline.t = [ { start = (0., 0.); segments = [ Cubic ((100. /. 3., 200. /. 3.), (200. /. 3., 200. /. 3.), (100., 0.)) ] } ] in
  let points o = List.hd (Outline.polygons ~tolerance:0.1 (fun p -> p) o) in
  Alcotest.(check int) "as many points" (List.length (points cubic)) (List.length (points quadratic));
  Alcotest.(check bool) "its top halfway up the control point" true (List.exists (fun (x, y) -> Float.abs (x -. 50.) < 3. && Float.abs (y -. 50.) < 1.) (points quadratic));
  (* the pen: steps from where it is; a move ends a contour *)
  let pen = Outline.pen () in
  Outline.move pen 10. 0.;
  Outline.line pen 0. 5.;
  Outline.curve pen 1. 0. 1. 1. 0. 1.;
  Outline.move pen 100. 0.;
  Outline.line pen 1. 1.;
  match Outline.drawn pen with
  | [ a; b ] ->
      Alcotest.(check bool) "the first contour" true (a = { start = (10., 0.); segments = [ Line (10., 5.); Cubic ((11., 5.), (12., 6.), (12., 7.)) ] });
      Alcotest.(check bool) "the second, from where the pen was moved to" true (b.start = (112., 7.))
  | _ -> Alcotest.fail "two contours"

let test_names () =
  Alcotest.(check (list (option int))) "names to characters" [ Some 0x41; Some 0xe9; Some 0xfb01; Some 0x41; Some 0x1f600; Some 0x41; None ]
    (List.map Glyph_names.unicode [ "A"; "eacute"; "fi"; "uni0041"; "u1F600"; "A.swash"; "nosuchglyph" ]);
  Alcotest.(check (list (option string))) "and back" [ Some "A"; Some "eacute"; Some "quotedblleft" ] (List.map Glyph_names.name [ 0x41; 0xe9; 0x201c ]);
  Alcotest.(check (list string)) "the standard encoding" [ "A"; "quoteright"; "" ] [ Glyph_names.standard_encoding.(65); Glyph_names.standard_encoding.(39); Glyph_names.standard_encoding.(128) ];
  Alcotest.(check (list int)) "Windows' and the Macintosh's" [ 0x20ac; 0xe9; 0xe9 ] [ Glyph_names.win_ansi.(0x80); Glyph_names.win_ansi.(0xe9); Glyph_names.mac_roman.(0x8e) ];
  Alcotest.(check (list string)) "CFF's strings (the first is the glyph for none)" [ ""; "space"; "A"; "Semibold" ] [ Glyph_names.cff_strings.(0); Glyph_names.cff_strings.(1); Glyph_names.cff_strings.(34); Glyph_names.cff_strings.(390) ]
  [@ocamlformat "disable"]

let test_widths () =
  Alcotest.(check (list (option int))) "Adobe's metrics"
    [ Some 667; Some 278; Some 722; Some 444; Some 500; Some 600; Some 667; Some 722; None ]
    [ Standard_widths.width "Helvetica" "A"; Standard_widths.width "Helvetica" "space"; Standard_widths.width "Times-Roman" "A"; Standard_widths.width "Times-Roman" "a";
      Standard_widths.width "Times-Italic" "a"; Standard_widths.width "ABCDEF+Courier-Bold" "i"; Standard_widths.width "ArialMT" "A"; Standard_widths.width "Helvetica-Bold" "A";
      Standard_widths.width "Helvetica" "nosuchglyph" ]

let test_cipher () =
  (* ciphered here the way the format says, then undone *)
  let encrypt key s = let r = ref key in String.map (fun c -> let e = Char.code c lxor (!r lsr 8) in r := ((e + !r) * 52845 + 22719) land 0xffff; Char.chr e) s in
  Alcotest.(check string) "the file's cipher, four bytes of noise" "/CharStrings 2 dict" (Type1.decrypt 55665 4 (encrypt 55665 "xxxx/CharStrings 2 dict"));
  Alcotest.(check string) "a glyph's" "\139\014" (Type1.decrypt 4330 4 (encrypt 4330 "abcd\139\014"));
  (* a font of one glyph: a square, its left edge at 50, its width 600 *)
  let program = "\189\248\236\013" ^ "\239\239\021" ^ "\247\200\006" ^ "\247\200\007" ^ "\251\200\006" ^ "\009\014" in
  let glyph name p = Printf.sprintf "/%s %d RD %s ND\n" name (String.length p + 4) (encrypt 4330 ("abcd" ^ p)) in
  let font = "%!PS-AdobeFont-1.0: Test\n/FontMatrix [0.001 0 0 0.001 0 0] readonly def\n/Encoding 256 array\ndup 65 /A put\nreadonly def\ncurrentfile eexec\n" ^ encrypt 55665 ("xxxx/lenIV 4 def\n/CharStrings 1 dict dup begin\n" ^ glyph "A" program ^ "end\n") in
  let f = Type1.of_string ~clear:0 font in
  Alcotest.(check bool) "its glyph, by name" true (Type1.has f "A" && not (Type1.has f "B"));
  Alcotest.(check string) "its encoding" "A" (Type1.encoding f).(65);
  let outline, width = Type1.glyph f "A" in
  Alcotest.(check (float 0.)) "its width" 600. width;
  Alcotest.(check bool) "a square of 308, from (150, 100)" true (Outline.bounds outline = Some (150., 100., 458., 408.))

let test_to_unicode () =
  let table = Pdf_font.to_unicode "1 beginbfchar <0041> <00660069> endbfchar 2 beginbfrange <10> <12> <0061> <20> <21> [<0058> <D83DDE00>] endbfrange" in
  let get code = Option.value ~default:[] (Hashtbl.find_opt table code) in
  Alcotest.(check (list (list int))) "the .mli's example; a range; a list; a character of two halves" [ [ 0x66; 0x69 ]; [ 0x61 ]; [ 0x63 ]; [ 0x58 ]; [ 0x1f600 ]; [] ]
    (List.map get [ 0x41; 0x10; 0x12; 0x20; 0x21; 0x99 ])

let tests =
  Testo.categorize "Fonts"
    [
      t "an outline: polygons, curves, the pen" test_outline;
      t "glyphs' names and the encodings" test_names;
      t "the standard fonts' widths" test_widths;
      t "Type 1: the cipher, a font of one glyph" test_cipher;
      t "what a code reads as" test_to_unicode;
      t "an H in a TrueType font (cairo's subset)" (check_h "shapes" 72);
      t "an H in a Type 1 font (Computer Modern)" (check_h "tex" 72);
      t "an F in a CFF font: as an H, a contour" (check_h "cff" 70);
    ]
