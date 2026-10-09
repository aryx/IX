(* mini-office's update: a frame's mouse and keys given to the start
 * screen, the File menu's dialog, the menus, the object edited in
 * place, the page. *)

(* where the start screen's five kinds and its Open... are (the view's too) *)
val tile : int -> Widget.box

val open_button : Widget.box

(* a frame: the computer's mouse and keys, the model after them. The
   capabilities are the File menu's: a document stored, fetched, the
   store listed *)
val update : File_menu.caps -> Playground.computer -> Office_model.model -> Office_model.model
