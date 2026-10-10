(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: a part of the author's playground's apps/office/TinyOffice.ml, its model's document and how one is saved; what changed there is said in Office (docs/plans/plan_office.md) *)

(* See Document.mli *)

(*****************************************************************************)
(* The document *)
(*****************************************************************************)

type kind = Document | Spreadsheet | Presentation | Picture | Drawing_doc

let kinds = [ Document; Spreadsheet; Presentation; Picture; Drawing_doc ]
let name = function Document -> "Document" | Spreadsheet -> "Spreadsheet" | Presentation -> "Presentation" | Picture -> "Picture" | Drawing_doc -> "Drawing"

(* where a chart takes its numbers from: the sheet that is the
   document, or a sheet object, by its id *)
type link = Main_sheet | Sheet_object of int

(* how the text goes round an object, Word's choices: on its wider side
   only, on both, above and below it only, or not at all *)
type wrap = Wider_side | Both_sides | Top_and_bottom | In_front

(* an object floating on the page: its part, the slide it is on, its
   top-left corner and size (the page's coordinates, y down), and
   whether a part with a size of its own is scaled to it. Its id stays
   the same as objects come and go, for a chart to find its sheet by.
   Tied to a paragraph ([anchor], the offset where the paragraph
   starts), its y is from the top of that paragraph's line, so that it
   moves with the text. The part is a parameter only for saving: a
   document saved is the same records with (kind, saved text) where
   each part was -- a part being functions (see [saved] below). *)
type 'p placed = {
  id : int;
  part : 'p;
  slide : int;
  x : float;
  y : float;
  w : float;
  h : float;
  scaled : bool;
  anchor : int option;
  link : link option;
  wrap : wrap;
}

type obj = Component.part placed

(* what the document is before anything floats on it: a text per slide
   (a document is one slide), or a part of its own kind *)
type 'p body_ = Texts of Rich.t list | Main of 'p

(* which text the keys go to: the body, or the header or footer of a
   document -- on the page it was clicked on, for its caret *)
type area = Body | Header of int | Footer of int

(* a page's two bands (ix: a type, where they were `Header and `Footer) *)
type band = Head | Foot

(* a document's header and footer, the same on every page, with fields
   in them -- {page} and {pages} -- that each page fills in; [scroll]:
   how far down the document's pages are scrolled *)
type 'p doc_ = { kind : kind; body : 'p body_; objects : 'p placed list; slide : int; header : Rich.t; footer : Rich.t; area : area; scroll : float }

type doc = Component.part doc_

(*****************************************************************************)
(* A chart and its sheet *)
(*****************************************************************************)

(* a chart made again from its sheet, if its sheet is still there *)
let refreshed (d : doc) (o : obj) =
  let source =
    match o.link with
    | Some Main_sheet -> ( match d.body with Main p when p.kind = Part_sheet.kind -> Some p | _ -> None)
    | Some (Sheet_object id) -> Option.map (fun s -> s.part) (List.find_opt (fun s -> s.id = id) d.objects)
    | None -> None
  in
  match source with Some p -> { o with part = Part_chart.make (Part_chart.of_sheet (Sheet.of_string (p.save ()))) } | None -> o

let refresh (d : doc) = { d with objects = List.map (refreshed d) d.objects }

(*****************************************************************************)
(* Saved *)
(*****************************************************************************)

(* A document is saved as the same records with each part replaced by
   its kind and what it saves -- whatever kind the document is, one
   file type, as the suite's own formats hold any kind of object. Open
   reads the parts back through the registry. *)
type saved = (string * string) doc_

(* what its files are: the line they start with, their names' end *)
let file_kind : File_menu.kind = { magic = "TinyOffice 1"; extension = ".office" }

let registry : Component.registry =
  [
    (Part_text.kind, Part_text.load);
    (Part_sheet.kind, Part_sheet.load);
    (Part_picture.kind, Part_picture.load);
    (Part_drawing.kind, Part_drawing.load);
    (Part_chart.kind, Part_chart.load);
    (Part_image.kind, Part_image.load);
  ]

(* ix: a record with a part of another type is written whole, where it
   was { d with body; objects } and { o with part }: mini-ml gives a
   record copied the type it had *)
let with_part (o : 'a placed) (part : 'b) : 'b placed =
  { id = o.id; part; slide = o.slide; x = o.x; y = o.y; w = o.w; h = o.h; scaled = o.scaled; anchor = o.anchor; link = o.link; wrap = o.wrap }

let with_parts (d : 'a doc_) (body : 'b body_) (objects : 'b placed list) : 'b doc_ =
  { kind = d.kind; body; objects; slide = d.slide; header = d.header; footer = d.footer; area = d.area; scroll = d.scroll }

let to_saved (d : doc) : saved =
  let data (p : Component.part) = (p.kind, p.save ()) in
  with_parts d
    (match d.body with Texts ts -> Texts ts | Main p -> Main (data p))
    (List.map (fun (o : obj) -> with_part o (data o.part)) (refresh d).objects)

let of_saved (d : saved) : doc =
  let part (kind, text) = Component.load registry ~kind text in
  with_parts d (match d.body with Texts ts -> Texts ts | Main p -> Main (part p)) (List.map (fun (o : (string * string) placed) -> with_part o (part o.part)) d.objects)
