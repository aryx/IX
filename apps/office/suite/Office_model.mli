(* mini-office's model: the document's versions (Undo), the one being
 * dragged or edited in place, what is selected, the File menu. *)

type drag =
  | Moving of float * float (* where on the object the mouse holds it *)
  | Resizing of int (* by that corner *)

type model = {
  (* the start screen, before a kind is chosen *)
  start : bool;
  history : Document.doc Undo.t;
  (* the document while an object is dragged, one edit on release *)
  live : Document.doc option;
  (* the document while an object is edited in place, one edit when it
     is put down *)
  editing : Document.doc option;
  selected : int option;
  drag : drag option;
  (* where the press began, and whether it was on the object already
     selected: a click there, without a drag, edits it in place *)
  pressed_at : float * float;
  again : bool;
  (* a run of typing, or of edits to the main part, is one edit *)
  run : bool;
  was : string list;
  was_down : bool;
  (* the presentation's show: the slides one at a time, the whole
     screen *)
  show : bool;
  (* the document's name, and the File menu's dialog *)
  file : File_menu.t;
}

val doc : model -> Document.doc

val initial : model
