(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: a part of the author's playground's apps/office/TinyOffice.ml, its model; what changed there is said in Office (docs/plans/plan_office.md) *)

(* See Office_model.mli *)

open Document

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type drag =
  | Moving of float * float (* where on the object the mouse holds it *)
  | Resizing of int (* by that corner *)

type model = {
  (* the start screen, before a kind is chosen *)
  start : bool;
  history : doc Undo.t;
  (* the document while an object is dragged, one edit on release *)
  live : doc option;
  (* the document while an object is edited in place, one edit when it
     is put down *)
  editing : doc option;
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

let doc m = match (m.editing, m.live) with Some d, _ | None, Some d -> d | None, None -> Undo.now m.history

let opening = Office_templates.fresh Document

let initial =
  {
    start = true;
    history = Undo.start ~limit:100 opening;
    live = None;
    editing = None;
    selected = None;
    drag = None;
    pressed_at = (0., 0.);
    again = false;
    run = false;
    was = [];
    was_down = false;
    show = false;
    file = File_menu.start;
  }
