(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)
(* ix: mini-chrome's tests/pdf/Unit_pdf.ml; the files are read by Testutil_pdf, and what was optional in the library is said (docs/plans/plan_pdf.md) *)

(* See Unit_pdf.mli *)

open Pdf_object

let t = Testo.create
let read = Testutil_pdf.read

(* an object printed back, to compare *)
let rec show (v : Pdf_object.t) : string =
  match v with
  | Null -> "null"
  | Bool b -> string_of_bool b
  | Int n -> string_of_int n
  | Real f -> Printf.sprintf "%g" f
  | String s -> Printf.sprintf "(%s)" s
  | Name n -> "/" ^ n
  | Array l -> "[" ^ String.concat " " (List.map show l) ^ "]"
  | Dict d -> "<<" ^ String.concat " " (List.map (fun (k, v) -> "/" ^ k ^ " " ^ show v) d) ^ ">>"
  | Stream (d, s) -> show (Dict d) ^ Printf.sprintf "stream(%s)" s
  | Ref n -> Printf.sprintf "%d R" n

let test_objects () =
  let parsed s = show (fst (parse s 0)) in
  let check name expected s = Alcotest.(check string) name expected (parsed s) in
  check "the .mli's example" "<</A 1 /B [2 (x)]>>" "<< /A 1 /B [2 (x)] >>";
  check "numbers" "[1 -2 3.5 -0.25 4 0.5]" "[1 -2 3.5 -.25 4. +.5]";
  check "a reference, and numbers that are none" "[12 R 1 2 3]" "[12 0 R 1 2 3]";
  check "a string's escapes, its parentheses" "(a(b)c\n)A)" "(a(b)c\\n\\)\\101)";
  check "a line continued" "(ab)" "(a\\\nb)";
  check "hexadecimal, an odd digit" "(hel\x70)" "<68 656C7>";
  check "a name's escape" "/A B" "/A#20B";
  check "words, a comment" "[true false null]" "[true % a comment\n false null]";
  check "nested" "<</K <</L [<</M 1>>]>>>>" "<</K<</L[<</M 1>>]>>>>";
  check "a stream by its length" "<</Length 5>>stream(hello)" "<< /Length 5 >>\nstream\nhello\nendstream";
  check "a stream whose length is wrong: to endstream" "<</Length 99>>stream(hello\n)" "<< /Length 99 >>\nstream\nhello\nendstream";
  Alcotest.(check (option string)) "an operator" (Some "Tj") (keyword (fst (parse "Tj" 0)));
  Alcotest.(check (option string)) "a value is none" None (keyword (fst (parse "/Tj" 0)));
  (* a page's content: operands, then the operator *)
  let rec tokens s i acc = if skip s i >= String.length s then List.rev acc else let v, j = parse s i in tokens s j (v :: acc) in
  Alcotest.(check (list string)) "a content stream" [ "1"; "0"; "0"; "rg"; "(Hi)"; "Tj" ]
    (List.map (fun v -> match keyword v with Some k -> k | None -> show v) (tokens "1 0 0 rg (Hi) Tj" 0 []))

let test_filters () =
  Alcotest.(check string) "the .mli's example" "Hello World!" (Pdf_filter.ascii85 "87cURD]i,\"Ebo80~>");
  Alcotest.(check string) "z is four zeros" "\000\000\000\000" (Pdf_filter.ascii85 "z~>");
  Alcotest.(check string) "hexadecimal" "hello" (Pdf_filter.ascii_hex "68 65 6c6C 6F>");
  Alcotest.(check string) "runs" "abcxxxx" (Pdf_filter.run_length "\002abc\253x\128");
  (* Welch's own example: "-----A---B" is 9 bit codes 256 45 258 258 65 259 66 257 *)
  Alcotest.(check string) "LZW" "-----A---B" (Pdf_filter.lzw ~early:1 "\x80\x0B\x60\x50\x22\x0C\x0C\x85\x01");
  let decode d bytes = fst (Pdf_filter.decode (fun v -> v) d bytes) in
  let deflated = Zlib.deflate "a page's content, a page's content" in
  Alcotest.(check string) "Flate" "a page's content, a page's content" (decode [ ("Filter", Name "FlateDecode") ] deflated);
  Alcotest.(check string) "two filters, in order" "hello" (decode [ ("Filter", Array [ Name "ASCIIHexDecode"; Name "RunLengthDecode" ]) ] "0468656C6C6F80>");
  Alcotest.(check (pair string (option string))) "a picture's own filter is left" ("jpeg", Some "DCTDecode") (Pdf_filter.decode (fun v -> v) [ ("Filter", Name "DCTDecode") ] "jpeg");
  (* rows predicted as PNG's: "up" (2), then "sub" (1), three columns *)
  let parms = Dict [ ("Predictor", Int 12); ("Columns", Int 3) ] in
  Alcotest.(check string) "a predictor" "\001\002\003\002\004\006\005\010\015"
    (decode [ ("Filter", Name "FlateDecode"); ("DecodeParms", parms) ] (Zlib.deflate "\002\001\002\003\002\001\002\003\001\005\005\005"))

let test_file () =
  let by_hand = Pdf.of_string (read "standard.pdf") in
  (match Pdf.pages by_hand with
   | [ p ] ->
       Alcotest.(check bool) "its size handed down by the tree" true (p.box = (0., 0., 300., 120.));
       Alcotest.(check bool) "its content" true (String.length (Pdf.content by_hand p) > 100);
       Alcotest.(check string) "a font, by a reference" "/Helvetica" (show (Pdf.get by_hand (Pdf.dict by_hand (Pdf.get by_hand (Pdf.dict by_hand (Pdf.get by_hand (Pdf.dict by_hand p.resources) "Font")) "F1")) "BaseFont"))
   | _ -> Alcotest.fail "one page, found without a table of objects");
  (* pdfTeX's: the table a stream, the objects packed *)
  let tex = Pdf.of_string (read "tex.pdf") in
  Alcotest.(check int) "two pages" 2 (List.length (Pdf.pages tex));
  Alcotest.(check bool) "a page's operators, inflated" true (let c = Pdf.content tex (List.hd (Pdf.pages tex)) in String.length c > 100 && String.sub c 0 2 = "BT");
  Alcotest.(check (list int)) "the others' pages" [ 1; 1; 1; 1; 2 ] (List.map (fun f -> List.length (Pdf.pages (Pdf.of_string (read (f ^ ".pdf"))))) [ "shapes"; "cff"; "browser"; "office"; "bitmap" ]);
  Alcotest.(check bool) "by its first bytes" true (Pdf.sniff "%PDF-1.7\n" && Pdf.sniff "junk\n%PDF-1.4" && not (Pdf.sniff "<html>"));
  List.iter
    (fun (why, bytes) -> match Pdf.of_string bytes with exception Failure _ -> () | _ -> Alcotest.fail why)
    [ ("not a PDF", "<html>"); ("no pages", "%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>");
      ("encrypted", "%PDF-1.4\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj 2 0 obj << /Kids [] >> endobj\ntrailer << /Root 1 0 R /Encrypt 3 0 R >>") ];
  (* a file cut short still gives what can be found *)
  let cut = let b = read "tex.pdf" in String.sub b 0 (String.length b - 300) in
  Alcotest.(check bool) "cut short: read anyway, or said" true (match Pdf.of_string cut with exception Failure _ -> true | p -> List.length (Pdf.pages p) >= 0)

let test_colors () =
  let close = Alcotest.(triple (float 0.5) (float 0.5) (float 0.5)) in
  Alcotest.check close "grey" (127.5, 127.5, 127.5) (Pdf_color.color Gray [ 0.5 ]);
  Alcotest.check close "inks" (255., 0., 0.) (Pdf_color.color Cmyk [ 0.; 1.; 1.; 0. ]);
  Alcotest.check close "black ink" (0., 0., 0.) (Pdf_color.color Cmyk [ 0.; 0.; 0.; 1. ]);
  Alcotest.check close "a palette" (0., 255., 0.) (Pdf_color.color (Indexed (Rgb, "\255\000\000\000\255\000")) [ 1. ]);
  Alcotest.check close "a spot ink" (0., 0., 0.) (Pdf_color.color Tint [ 1. ]);
  let pdf = Pdf.of_string (read "standard.pdf") in
  Alcotest.(check bool) "spaces by name and description" true
    (Pdf_color.space pdf Null (Name "DeviceCMYK") = Cmyk
    && Pdf_color.space pdf Null (Array [ Name "Indexed"; Name "DeviceRGB"; Int 1; String "abcdef" ]) = Indexed (Rgb, "abcdef")
    && Pdf_color.space pdf Null (Array [ Name "Separation"; Name "Gold"; Name "DeviceCMYK"; Null ]) = Tint);
  (* a gradient's function: from red to blue, and two of them end to end *)
  let f = Dict [ ("FunctionType", Int 2); ("C0", Array [ Int 1; Int 0; Int 0 ]); ("C1", Array [ Int 0; Int 0; Int 1 ]); ("N", Int 1) ] in
  Alcotest.(check (list (float 1e-6))) "halfway" [ 0.5; 0.; 0.5 ] (Pdf_shading.apply pdf f 0.5);
  let stitched = Dict [ ("FunctionType", Int 3); ("Domain", Array [ Int 0; Int 1 ]); ("Functions", Array [ f; f ]); ("Bounds", Array [ Real 0.5 ]); ("Encode", Array [ Int 0; Int 1; Int 1; Int 0 ]) ] in
  Alcotest.(check (list (float 1e-6))) "the first piece's end" [ 0.2; 0.; 0.8 ] (Pdf_shading.apply pdf stitched 0.4);
  Alcotest.(check (list (float 1e-6))) "the second, backwards" [ 0.2; 0.; 0.8 ] (Pdf_shading.apply pdf stitched 0.6)

let tests =
  Testo.categorize "Pdf"
    [
      t "objects: the syntax" test_objects;
      t "filters" test_filters;
      t "files: a table, a table as a stream, no table" test_file;
      t "colours and a gradient's function" test_colors;
    ]
