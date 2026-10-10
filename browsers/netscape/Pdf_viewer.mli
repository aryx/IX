(* Pdf_viewer: a PDF file shown as a page of the browser's: its pages
 * one under the other, each an <img> whose picture is drawn when it
 * comes into view (Tab), by lib_graphics/pdf. The author's
 * mini-chrome's (docs/plans/plan_pdf.md, stage F). *)

type t

(* the bytes are a PDF file's (its first ones say so), whatever its
 * type was said to be *)
val sniff : string -> bool

(* the file read: its objects' places, its pages; or why not *)
val open_ : string -> (t, string) result

(* the document as HTML, [name] its title: an <img src=[src n]> a page,
 * of the page's size *)
val html : t -> name:string -> string

(* the address of page [n]'s picture (from 1), and back *)
val src : int -> string
val page_of_src : string -> int option

(* page [n] drawn; a picture of one pixel if it cannot be *)
val picture : t -> int -> Rgba_image.t
