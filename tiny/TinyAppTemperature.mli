(* A tiny temperature converter with two fields where each one shows the
 * conversion of the other.
 *
 * It is the second of the 7GUIs tasks (m-ix's
 * version is examples/Gui7Temperature.ml), here with whole numbers
 * only. A click in a field, then the keys: digits, a sign, the
 * backspace; the Escape quits (or q, before a field is clicked).
 *
 * What the task asks for, and why it comes second: a change must
 * propagate in both directions, and half of what the user types is not
 * yet a number.
 *
 *     typed in Celsius     Celsius    Fahrenheit
 *     1                    1          34
 *     10                   10         50
 *     10x                  10x        50       not a number: the other
 *     10 (a backspace)     10         50       field is left alone
 *     then, in Fahrenheit:
 *     -40 (after three     -40        -40
 *     backspaces)
 *
 * - {b The model is the two texts}, not a temperature. A field must be
 *   able to show "10x" or "-" while they are being typed, and no number
 *   can represent those. The field being typed in keeps its text,
 *   whatever it is; the other field is recomputed only when that text
 *   is a number.
 * - {b There is no loop between the fields}. The message says which
 *   field was typed in, so the program can set the other one without
 *   it counting as a "change". With widgets that store their own text
 *   and report every change, setting one field from the other would
 *   trigger a callback, and the program would have to stop that echo
 *   itself.
 *
 * Its twin, examples/Gui7Temperature.ml (from the author's
 * playground), keeps the same model, the two texts, but is written in
 * lib_gui's immediate way: both fields are asked for at every frame,
 * and the one typed in is the one whose text came back changed, with
 * no message type; its numbers are floats, shown with one decimal.
 * Here it is TinyLibGUI's model, view and update: the field typed in
 * is said by its message (above).
 *
 * What is left out: fractions (tiny-ml has no floats, so we round to
 * the nearest whole number: 34 Fahrenheit gives 1 Celsius, and 1
 * Celsius gives 34), showing a field in red when its text is not a
 * number, and numbers longer than six digits.
 *
 * Exercises:
 * - show a field whose text is not a number in another colour (with
 *   one more widget, or a colour in Input);
 * - tenths: store each number as ten times its value;
 * - Kelvin: add a third field, computed from either of the two others.
 *
 * References: E. Kiss, "7GUIs: A GUI Programming Benchmark" (2014),
 * task 2. *)

(* the two fields' texts, as typed; a field's new text *)
type model = { c : string; f : string }
type msg = Celsius of string | Fahrenheit of string

(* The converter, for TinyLibGUI's run *)
val temperature : (model, msg) TinyLibGUI.gui

(* a text's whole number, and whether it is one *)
val number : string -> int * bool
