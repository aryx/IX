(* This module says how a widget is drawn, and nothing about who keeps
 * its state.
 *
 * This module exists for the comparison that this whole corner of the
 * repository is for (notes_gui.md section 4). The same widgets are
 * wired in four ways: immediate mode (Immediate), callbacks
 * (Retained), model-view-controller (Mvc) and model-view-update
 * (Mvu). If each drew its own buttons, the comparison would be
 * measuring paint rather than architecture. So the paint lives here,
 * once, and each architecture is only its wiring.
 *
 * Every function takes what to draw and the *state to draw it in*
 * (hot, held, checked, where the caret is), and answers with paint.
 * It knows nothing of mice, frames or callbacks; the question "is it
 * hot?" belongs to whoever owns the state, and that is exactly what
 * the four disagree about.
 *
 *     Immediate   hot is computed now, from the mouse, and forgotten
 *     Retained    hot is a mutable field of the button object
 *     Mvc         the view asks the model, the controller sets it
 *     Mvu         hot comes from the model, by way of a message
 *)

(*****************************************************************************)
(* {1 Buttons and labels} *)
(*****************************************************************************)

(* the face a button shows: alive under the mouse, sunk while pressed *)
val face : Theme.t -> hot:bool -> held:bool -> Color.t

(* text centered in a box, at the theme's size *)
val text_at : Theme.t -> Widget.box -> string -> Widget.paint

val label : Theme.t -> Widget.box -> string -> Widget.paint list
val button : Theme.t -> Widget.box -> string -> hot:bool -> held:bool -> enabled:bool -> Widget.paint list

val checkbox :
  Theme.t -> Widget.box -> string -> checked:bool -> hot:bool -> held:bool -> Widget.paint list

(*****************************************************************************)
(* {1 Values: sliders, dials and bars} *)
(*****************************************************************************)

(* [fraction] is where the knob sits, 0 at the left end, 1 at the right *)
val slider : Theme.t -> Widget.box -> fraction:float -> hot:bool -> held:bool -> Widget.paint list

(* [knob theme box ~fraction] draws a dial at the box's center,
 * [theme.dial] wide. Its pointer turns clockwise from 225 degrees (at
 * 0, lower left: seven o'clock) through the top to -45 (at 1, lower
 * right: five o'clock), 270 degrees in all. Around it are the eleven
 * ticks of a synthesizer's 0 to 10. The pointer is in the accent
 * color while the knob is turned. *)
val knob : Theme.t -> Widget.box -> fraction:float -> hot:bool -> held:bool -> Widget.paint list

(* [knob_angle fraction] is where the pointer points, in degrees
 * (counterclockwise from the right, as the playground counts them) *)
val knob_angle : float -> float

(* [rocker theme box ~on] draws a rocker switch standing in [box]. The
 * lit half (in the accent color) is the top one when [on], and the
 * bottom one otherwise. *)
val rocker : Theme.t -> Widget.box -> on:bool -> hot:bool -> held:bool -> Widget.paint list

(* [selector theme box labels ~index] draws a rotary switch: a dial
 * whose pointer stops at one of the [labels]. The labels are written
 * around it over the top (40 degrees apart, at most 270 in all), and
 * the chosen one is in the accent color. *)
val selector : Theme.t -> Widget.box -> string list -> index:int -> hot:bool -> held:bool -> Widget.paint list

(* [selector_angle n i] is where the [i]th of [n] positions is, in
 * degrees. *)
val selector_angle : int -> int -> float

(* [slider_value theme box ~from ~to_ mx] is the value of a slider
 * whose knob is dragged to [mx], with the knob's center under the
 * mouse but kept in the track. It is None when the box is too narrow
 * to have a track.
 *
 * It is written here once, for the three toolkits, rather than in
 * each, because the same formula written twice can come out a last
 * bit apart. On arm64,
 * OCaml's native code fuses a multiplication and an addition into one
 * instruction (fmadd, one rounding instead of two) where the pattern
 * of the code allows it, and one toolkit's copy was fused and another's
 * was not. examples/gui4/tests/Unit_gui4 found it, when a circle drawn
 * from each version's value was not the same picture. *)
val slider_value : Theme.t -> Widget.box -> from:float -> to_:float -> float -> float option

val progress : Theme.t -> Widget.box -> float -> Widget.paint list

(*****************************************************************************)
(* {1 Text: fields and areas} *)
(*****************************************************************************)

(* [caret] is the byte index the caret sits at, or [None] when the
 * field does not have the keys. The text scrolls sideways to keep the
 * caret in view. *)
val field :
  Theme.t -> Widget.box -> string -> caret:int option -> enabled:bool -> Widget.paint list

(* [field_column_at theme box text ~caret x] is the character of
 * [text] that the point [x] falls on, given where the caret is (which
 * says how far the text has scrolled). This is how a click becomes a
 * caret position. *)
val field_column_at : Theme.t -> Widget.box -> string -> caret:int -> float -> int

(* [text_area theme box lines ~range ~caret ~first] draws several
 * lines of text in a box, from line [first] down. The selection
 * [range] (in offsets into the whole text) is highlighted, and the
 * caret is drawn where it belongs. The caret is given as (line,
 * column), or [None] when the area does not have the keys.
 *
 * The text is laid out one character to a cell, like the field's and
 * for the same reason (Text.mli): a click lands exactly where it
 * looks. *)
val text_area :
  Theme.t ->
  Widget.box ->
  (int * string) list ->
  range:int * int ->
  caret:(int * int) option ->
  first:int ->
  Widget.paint list

(* how many characters across, and how many lines down, fit in a box;
 * the caller needs them to wrap its text and to scroll *)
val columns : Theme.t -> Widget.box -> int
val rows : Theme.t -> Widget.box -> int

(* [text_area_place theme box ~first x y] is the (line, column) that a
 * point falls on. This is how a click becomes a caret. *)
val text_area_place : Theme.t -> Widget.box -> first:int -> float -> float -> int * int

(*****************************************************************************)
(* {1 Lists and menus} *)
(*****************************************************************************)

(* a list box, and where its row [i] is *)
val list : Theme.t -> Widget.box -> string list -> selected:int option -> Widget.paint list
val list_row : Theme.t -> Widget.box -> int -> Widget.box

(* a dropdown, closed (with its arrow) and open (its items, with the
 * one under the mouse lit) *)
val menu_closed : Theme.t -> Widget.box -> string -> hot:bool -> held:bool -> Widget.paint list
val menu_item : Theme.t -> Widget.box -> int -> Widget.box
val menu_items : Theme.t -> Widget.box -> string list -> under:int option -> Widget.paint list

(* For a context menu opened at a point, this is the box its items
 * hang from (with [menu_item] and [menu_items]). The first item's
 * top-left corner is just off the point, and the box is as wide as
 * the widest item. *)
val context_box : Theme.t -> float * float -> string list -> Widget.box
