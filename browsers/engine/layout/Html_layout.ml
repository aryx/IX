(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/layout/Html_layout.ml, its first version (docs/plans/plan_browser.md) *)

(* See Html_layout.mli *)

type metrics = Looks.t -> string -> float
type picture = { src : string; height : float; middle : bool }
type control = { element : Dom.element; control_height : float }

type fragment = {
  text : string;
  look : Looks.t;
  x : float;
  width : float;
  baseline : float;
  picture : picture option;
  control : control option;
  element : Dom.element;
}

type line = { top : float; height : float; baseline : float; fragments : fragment list; anchors : string list }
type kind = Block of Dom.element | Anonymous | Rule of Dom.element
type marker = Bullet | Number of int

type box = {
  kind : kind;
  x : float;
  y : float;
  width : float;
  height : float;
  children : box list;
  lines : line list;
  floats : fragment list;
  marker : marker option;
  background : Looks.color option;
}

(* a form's control's size, in the look it is in, by its kind; none for
 * a hidden one, or what is not a control *)
let control_size (metrics : metrics) (l : Looks.t) (e : Dom.element) : (float * float) option =
  let number name default =
    match Option.bind (Dom.attribute name e) int_of_string_opt with Some n when n > 0 -> float_of_int n | _ -> default
  in
  (* a fixed-width character's cell: a field's text is set on one *)
  let cell = 0.6 *. l.size in
  let button label = Some (metrics l label +. (1.4 *. l.size), 1.7 *. l.size) in
  match Forms.control e with
  | None -> None
  | Some c -> (
      match c.kind with
      | Hidden -> None
      | Text | Password -> Some ((number "size" 20. *. cell) +. 8., 1.6 *. l.size)
      | Checkbox | Radio -> Some (0.9 *. l.size, 0.9 *. l.size)
      | Submit | Reset | Button -> button (Forms.label c)
      | Select opts ->
          let widest = List.fold_left (fun w (label, _) -> Float.max w (metrics l label)) 0. opts in
          Some (widest +. (2.2 *. l.size), 1.7 *. l.size)
      | Textarea -> Some ((number "cols" 20. *. cell) +. 8., (number "rows" 2. *. Looks.leading *. l.size) +. 8.))

let rec fragments (b : box) : fragment list =
  List.concat_map (fun (l : line) -> l.fragments) b.lines @ b.floats @ List.concat_map fragments b.children

let no_picture (_ : string) : (float * float) option = None
