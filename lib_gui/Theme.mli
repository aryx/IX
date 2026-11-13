(* This module is where a toolkit's look lives. All its colors and
 * sizes are in one record, so changing what a button looks like means
 * changing one value and not thirty scattered constants.
 *
 * Every toolkit has this and gives it a different name: X11 and Motif
 * have *resources* (a ~/.Xdefaults file, in the 1980s), the web has
 * CSS (1996), Flutter has ThemeData, and today people speak of "design
 * tokens". It is also the only honest way to draw everything
 * yourself: since we refuse the system's widgets (notes_gui.md section
 * 3), the system's colors are not ours to read, so we must say what
 * grey we mean.
 *
 * A widget asks the theme for three faces, and that is the whole of
 * how a button feels alive under the mouse:
 *
 *   face          the mouse is elsewhere
 *   face_hot      the mouse is over it        ("hot", Dear ImGui's word)
 *   face_down     the mouse is pressed in it  ("active")
 *)

type t = {
  (* the page behind everything *)
  background : Color.t;
  (* the three faces of a button (above) *)
  face : Color.t;
  face_hot : Color.t;
  face_down : Color.t;
  (* the line around a widget, and how thick it is *)
  edge : Color.t;
  border : float;
  (* labels, and what a slider has filled in or a checkbox ticked *)
  text : Color.t;
  accent : Color.t;
  (* the size of a label, in playground units *)
  text_size : float;
  (* the height of a button, a checkbox or a slider: one row *)
  row : float;
  (* the space between a label and the edge of its widget *)
  padding : float;
  (* how wide a slider is, and how wide its knob *)
  slider_width : float;
  knob : float;
  (* A text field has its own face, paler than a button's because a
     field is a hole to type into rather than a thing to press, and a
     width for when nothing says otherwise. *)
  field_face : Color.t;
  field_width : float;
  (* the diameter of a knob or a rotary switch, its face, and the
     color of the line on it that says where it points *)
  dial : float;
  dial_face : Color.t;
  pointer : Color.t;
}

(* a light grey theme, readable on every backend *)
val default : t
