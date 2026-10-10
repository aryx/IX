(* mini-office's model: the document's versions (Undo), the one being
 * dragged or edited in place, what is selected, the File menu.
 *
 * The model is the M of the program's three (Mvu.mli): one value,
 * made again by Office_update at each frame, shown by Office_view.
 * Everything the program remembers is in it; no module of the suite
 * has a variable of its own but what Office_page and Office_view
 * keep to go faster.
 *
 * Which document is the document, at any moment ([doc]):
 *
 *   history   the versions: what Undo and Redo walk
 *   live      a document being changed by a drag, each frame from
 *             the history's last; a version when the mouse is let go
 *   editing   a document one of whose objects is edited in place; a
 *             version when the object is put down
 *
 *   [doc] is editing, else live, else the history's last
 *
 * so what is shown follows the mouse and the keys at once, and the
 * history gets one version for a whole gesture, with a name.
 *
 * Three fields are the frame before: [was] (the keys that were
 * down), [was_down] (the mouse's button), [pressed_at]. Playground
 * gives an update the state of the keyboard and the mouse, not
 * events, so a key pressed is a key down now that was not down at
 * the last frame, and somebody has to keep the last frame. An
 * event queue would hand the press itself: the toolkits with
 * callbacks do, and keep that state for the program. *)

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
