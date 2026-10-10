(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* Office_export: the file has the document's pages, each of the
 * document's size; what the pages look like is export.sh's, which
 * has another program read them. *)

let t = Testo.create

let model (d : Document.doc) : Office_model.model = { Office_model.initial with start = false; history = Undo.start ~limit:100 d }

let has (s : string) (sub : string) : bool =
  let n = String.length sub in
  let rec go i = i + n <= String.length s && (String.sub s i n = sub || go (i + 1)) in
  go 0

(* a document whose text is that many paragraphs *)
let long (paragraphs : int) : Document.doc =
  let d = Office_templates.fresh Document.Document in
  { d with body = Texts [ Rich.of_string ~style:Style.plain (String.concat "\n\n" (List.init paragraphs (fun i -> Printf.sprintf "Paragraph %d, a line of it and no more." i))) ] }

let test_pages () =
  let pages (d : Document.doc) (n : int) (box : string) =
    let s = Office_export.pdf (model d) in
    Alcotest.(check bool) (Printf.sprintf "%d page(s)" n) true (has s (Printf.sprintf "/Count %d >>" n));
    Alcotest.(check bool) box true (has s ("/MediaBox [0 0 " ^ box ^ "]"))
  in
  pages (Office_templates.fresh Document.Document) 1 "620 820";
  pages (Office_templates.fresh Document.Spreadsheet) 1 "820 820";
  (* a slide a page *)
  pages (Office_templates.fresh Document.Presentation) 2 "800 560";
  pages (Office_templates.fresh Document.Picture) 1 "820 820";
  pages (Office_templates.fresh Document.Drawing_doc) 1 "820 820";
  let d = long 60 in
  Alcotest.(check bool) "sixty paragraphs are more than a page" true (Office_page.pages d > 1);
  pages d (Office_page.pages d) "620 820"

(* scrolled, or its header being typed, a document is exported the same *)
let test_as_read () =
  let d = long 60 in
  let s = Office_export.pdf (model d) in
  Alcotest.(check bool) "scrolled" true (s = Office_export.pdf (model { d with scroll = 300. }));
  Alcotest.(check bool) "its header being edited" true (s = Office_export.pdf (model { d with area = Header 0 }))

(* the file read back by the reader (lib_graphics/pdf's Pdf_render),
 * each page against the screen's pixels of it *)
let test_read_back () =
  List.iter
    (fun ((name, d) : string * Document.doc) ->
      let m = model d in
      let pdf = Pdf.of_string (Office_export.pdf m) in
      let cache = Pdf_render.cache () in
      let pw, ph = Office_page.page_size d.kind in
      let l, top = Office_page.origin { d with scroll = 0. } in
      List.iteri
        (fun (k : int) (p : Pdf.page) ->
          (* (a presentation's pages are its slides, each from the top) *)
          let d = if d.kind = Presentation then { d with slide = k; scroll = 0. } else { d with scroll = 0. } in
          let top = if d.kind = Presentation then top else top -. (float k *. Office_page.pitch d.kind) in
          let fb = Framebuffer.create ~width:(int_of_float pw) ~height:(int_of_float ph) in
          Shape_render_software.render ~options:Shape_render_software.default_options ~scale:1. fb
            [ Playground.rectangle Playground.white pw ph; Playground.group (Office_view.page_shapes ~chrome:false d m) |> Playground.move (-.(l +. (pw /. 2.))) (-.(top -. (ph /. 2.))) ];
          let ours = Pdf_render.render ~options:Pdf_render.full ~stroke_glyph:Pdf_render.hershey pdf cache p ~scale:1. in
          let away = Testutil_pdf.away fb ours in
          if away > 1.5 then Alcotest.failf "%s, page %d: %.2f away from the screen's picture" name (k + 1) away)
        (Pdf.pages pdf))
    [
      ("a document", Office_templates.fresh Document.Document); ("a spreadsheet", Office_templates.fresh Spreadsheet);
      ("a presentation", Office_templates.fresh Presentation); ("a drawing", Office_templates.fresh Drawing_doc); ("three pages", long 30);
    ]

let tests = [
    t "the file read back is the screen's pages" test_read_back; t "a page of the file for each of the document's" test_pages; t "exported as it is read, not as it is edited" test_as_read ]
