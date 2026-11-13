(* An effect as a rack sees it: a sound that goes through it block after
 * block, and knobs that are turned by their names (see notes_synth.md
 * section 8).
 *
 * Each effect here has its own typed interface, which its .mli explains
 * and its tests use (Delay.process t settings takes a record of the
 * delay's numbers). A rack wants something else. It holds effects of
 * every kind in a list, in an order it can change, and it turns their
 * knobs from a patch, which stores numbers by name. So each module also
 * makes an [Effect.t], with its settings kept inside:
 *
 *     Delay.fx () : Effect.t
 *
 *        knobs    time, feedback, tone, pingpong, mix: what a panel
 *                 draws and a patch stores (Control.mli)
 *        set      "time" 0.5: a knob is turned, and it is heard from
 *                 the next block
 *        process  a stereo block, processed in place
 *        meters   what it shows back, such as a compressor's gain
 *                 reduction, the needle on its front panel
 *
 * This is the same shape as Instrument.t, for the same reason. It is a
 * record of functions (an object in all but name) over a state that the
 * closures share, so the rack can hold it without knowing what is
 * inside. It is the plug-in's interface (VST's, 1996: parameters by
 * index, and a processReplacing of blocks) made small.
 *
 * A knob turned between two blocks is *ramped* over the next block, as
 * Instrument.mli's knobs are, wherever it multiplies the sound (a gain,
 * a mix). A jump there would be a step in the wave, which is a click,
 * and a knob turned slowly would click at every block, which is zipper
 * noise. [ramp] computes the ramp. *)

(* ix: copied from libs/audio/effects/Effect.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* a knob: its name, its control, and its initial position *)
type knob = { name : string; control : Control.t; initial : float }

type t = {
  name : string; (* "delay" *)
  knobs : knob list;
  (* turns a knob, by its name; names it does not have are ignored *)
  set : string -> float -> unit;
  (* sends a block through the effect, in place, both channels *)
  process : Signal.stereo -> unit;
  (* its meters, by name, as of the last block ([] for most effects) *)
  meters : unit -> (string * float) list;
}

(* [ramp last now i n] is the value at sample [i] of a block of [n] of a
 * knob going from [last] (the last block's value) to [now]. It is
 * last + (now - last) (i + 1) / n, so it reaches [now] at the block's
 * end. *)
val ramp : float -> float -> int -> int -> float
