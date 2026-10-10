(* mini-office's update: a frame's mouse and keys given to the start
 * screen, the File menu's dialog, the menus, the object edited in
 * place, the page. *)

(* where the start screen's five kinds and its Open... are (the view's too) *)
val tile : int -> Widget.box

val open_button : Widget.box

(* a frame: the computer's mouse and keys, the model after them. The
   capabilities are the File menu's: a document stored, fetched, the
   store listed. [exported]: the document as the bytes Export writes
   (Office_export.pdf: given, the view's shapes being what it writes
   and the view coming after this) *)
val update : File_menu.caps -> exported:(Office_model.model -> string) -> Playground.computer -> Office_model.model -> Office_model.model
