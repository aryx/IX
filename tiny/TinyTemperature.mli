(* A tiny temperature converter, a program of TinyKernel.ml's on
 * TinyGUI.ml: two fields, each the other's answer. The second of the
 * 7GUIs (examples/Gui7Temperature.ml is m-ix's), in whole numbers, in
 * tiny-ml's ML and OCaml's:
 *
 *     ./tiny-machine -window tiny-kernel
 *     $ temp
 *     a click in a field, then the keys: digits, a sign, the backspace;
 *     the Escape quits (or q, before a field is clicked)
 *
 * What the task asks, and why it is the second: a change goes both
 * ways, and half of what is typed is not a number.
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
 * - {b The model is the two texts}, not a temperature: a field must
 *   show "10x" or "-" while they are typed, which no number is. The
 *   field typed in keeps its text whatever it is; the other one is
 *   computed when that text is a number.
 * - {b No loop between the fields}: the message says which field was
 *   typed in, so the other is set without being "changed". With
 *   widgets that keep their text and tell of each change, setting one
 *   from the other calls back, and the program must stop the echo.
 *
 * Dropped: fractions (tiny-ml has no floats: the nearest whole
 * number, so 34 Fahrenheit is 1 Celsius and 1 Celsius 34), a field
 * shown red when its text is no number, numbers past six digits.
 *
 * Exercises:
 * - the field that is no number shown another colour (a widget more,
 *   or a colour in Input);
 * - tenths: a number kept as ten times itself;
 * - Kelvin: a third field, each the two others' answer.
 *
 * References: E. Kiss, "7GUIs: A GUI Programming Benchmark" (2014),
 * task 2. *)

(* the two fields' texts, as typed; a field's new text *)
type model = { c : string; f : string }
type msg = Celsius of string | Fahrenheit of string

(* The converter, for TinyGUI's run *)
val temperature : (model, msg) TinyGUI.gui

(* a text's whole number, and whether it is one *)
val number : string -> int * bool
