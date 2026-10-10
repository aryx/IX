(* mini-office's edits: each a new version of the document (one that
 * Undo takes back), and the menus that ask for them. *)

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
