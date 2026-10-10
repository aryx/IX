(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/viewers/Pdf_viewer.ml (docs/plans/plan_pdf.md, stage F); the letters of a font that is not in the file are Pdf_render.hershey's, no option of how much is drawn, a pixel a unit of the page shown *)

(* See Pdf_viewer.mli *)

type t = { pdf : Pdf.t; cache : Pdf_render.cache; pages : Pdf.page array }

(* a page's picture has this many dots for a unit of the page shown.
 * old: 1.5, sharp on a screen of two dots a pixel and when zoomed a
 * little; a page's picture is then 8 MB, and mini-netscape has no zoom *)
let density = 1.

let sniff = Pdf.sniff

let open_ (bytes : string) : (t, string) result =
  match Pdf.of_string bytes with
  | pdf -> ( match Pdf.pages pdf with [] -> Error "a PDF file with no page" | pages -> Ok { pdf; cache = Pdf_render.cache (); pages = Array.of_list pages })
  | exception Failure why -> Error why
  | exception _ -> Error "Pdf: a file that cannot be read"

let prefix = "pdf-page:"
let src (n : int) : string = prefix ^ string_of_int n

let page_of_src (s : string) : int option =
  let l = String.length prefix in
  if String.length s > l && String.sub s 0 l = prefix then int_of_string_opt (String.sub s l (String.length s - l)) else None

(* the document as a page of ours: its pages one under the other, each
 * a picture of its size (a point is 1/72 inch, a pixel 1/96), white
 * until it is drawn *)
let html (t : t) ~(name : string) : string =
  let b = Buffer.create 1024 in
  Buffer.add_string b
    (Printf.sprintf
       "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>%s</title><style>body { margin: 0; background: #525659; text-align: center } div { margin: 12px 0 } img { background: white; vertical-align: top }</style></head><body>"
       (Browser_text.escape_html name));
  Array.iteri
    (fun i p ->
      let w, h = Pdf_render.size p in
      Buffer.add_string b
        (Printf.sprintf "<div><img src=\"%s\" width=\"%d\" height=\"%d\" alt=\"page %d\"></div>" (src (i + 1))
           (int_of_float (Float.round (w *. 96. /. 72.)))
           (int_of_float (Float.round (h *. 96. /. 72.)))
           (i + 1)))
    t.pages;
  Buffer.add_string b "</body></html>";
  Buffer.contents b

let picture (t : t) (n : int) : Rgba_image.t =
  if n < 1 || n > Array.length t.pages then Rgba_image.create ~width:1 ~height:1
  else
    try Pdf_render.render ~options:Pdf_render.full ~stroke_glyph:Pdf_render.hershey t.pdf t.cache t.pages.(n - 1) ~scale:(density *. 96. /. 72.)
    with Failure _ | Not_found | Invalid_argument _ -> Rgba_image.create ~width:1 ~height:1
