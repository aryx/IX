(* mini-office's edits: each a new version of the document (one that
 * Undo takes back), and the menus that ask for them.
 *
 * An edit is a function from a document to a document, given to
 * [record] with the name the status line shows after "Undo". None
 * changes anything in place, so none has an inverse to write
 * (Undo.mli): Bring to Front is the list of objects with one moved
 * to its end, Delete the list without one.
 *
 * The menu bar is computed from the model at each frame ([menus]),
 * so it cannot be out of date:
 *
 *   nothing edited in place     File  Edit  Insert  Arrange, then
 *                               Format (a document), Format and Slide
 *                               (a presentation), or the main part's
 *                               own menu (a sheet, a picture, a drawing)
 *   an object edited in place   File, and the object's own menu
 *
 * and [command] is the other half: a menu's title and an item to an
 * edit. An item of an object's own menu is not understood here at
 * all: it is handed to the part ([command] of Component), which
 * answers with the part it has become. That is how a kind of part
 * added later brings its commands with it.
 *
 * An object and the text. An object tied to a paragraph ([tie])
 * keeps the offset where its paragraph starts and its distance below
 * that paragraph's line, so every edit of the text must move the
 * offsets after the caret by what was typed or deleted
 * ([edit_text]): the same bookkeeping as a text's runs (Rich.mli),
 * for a list of anchors.
 *
 * cs-history:
 * Menu merging is OLE 2's (1993) answer to whose menu bar it is when
 * a sheet is edited inside a letter. The bar was cut in six groups,
 * three the container's (File, Container, Window) and three the
 * object's (Edit, Object, Help), interleaved: File stays the
 * letter's because saving saves the letter, Edit becomes the sheet's
 * because what is cut is cells. Here the rule is the same with fewer
 * groups: File, and the part's menu. *)

val record : name:string -> Document.doc -> Office_model.model -> Office_model.model

val set_obj : int -> (Document.obj -> Document.obj) -> Document.doc -> Document.doc

(* the end of an editing session in place: one edit, if it made one *)
val put_down : Office_model.model -> Office_model.model

(* ix: a picture's file (PNG, JPEG) put on the page as an object
   (Part_image), selected; Failure if its bytes are no such picture *)
val insert_image : string -> Office_model.model -> Office_model.model

(* an object put at a place on the page, and given a size: tied to a
   paragraph, it keeps its distance from the paragraph's line *)
val place : Document.doc -> int -> x:float -> y:float -> w:float -> h:float -> Document.doc

(* an object tied to the paragraph beside its top, or untied: either
   way it stays where it is *)
val tie : Document.doc -> int -> Document.doc

(* the text the keys go to *)
val current_text : Document.doc -> Rich.t option

val edit_text : (Rich.t -> Rich.t) -> Office_model.model -> Document.doc

val a_run : name:string -> Document.doc -> Office_model.model -> Office_model.model

(* the menu bar: the host's -- or, while an object is edited in place,
   File and the object's own, OLE 2's menu merging *)
val menus : Office_model.model -> string list list

val menu_box : int -> Widget.box

val command : menu:string -> string -> Office_model.model -> Office_model.model
