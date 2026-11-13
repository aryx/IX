(* A control on a panel: what an instrument's or an effect's knob is,
 * so that a program can draw it, a patch can store it, and a text file
 * can name it.
 *
 * Every control's value is a float, whatever the control looks like:
 *
 *     Knob (from, to)   is turned between two values, in the control's
 *                       own units (0 to 1, dB, seconds, hertz)
 *     Switch            is off (0) or on (1), like a rocker
 *     Selector labels   is a position (0, 1, 2, ...) of a rotary switch,
 *                       each position named by its label
 *
 * So a panel is a list of named controls, and a patch is a list of
 * named numbers. The text form writes a switch as on or off, and a
 * selector by its label: "reverb.kind = plate", not "2". *)

(* ix: copied from libs/audio/Control.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type t = Knob of float * float (* from, to *) | Switch | Selector of string list

(* [on x] reads a switch's value: 0.5 and above is on *)
val on : float -> bool
val of_bool : bool -> float

(* [index x] reads a selector's value, rounded *)
val index : float -> int

(* [to_string c x] gives "0.375", "on" or "plate" *)
val to_string : t -> float -> string

(* [of_string c s] is the value that [s] says, a knob's value being
 * kept within its range; None if [s] is not a value of [c] *)
val of_string : t -> string -> float option
