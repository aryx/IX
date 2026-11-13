(* Game sounds from a few numbers: sfxr's idea, made readable (see
 * notes_audio.md section 8).
 *
 * Tomas Pettersson ("DrPetter") wrote sfxr in 2007 for a 48-hour game
 * jam. Nobody there had time to record or find sounds, and most 8-bit
 * game sounds turn out to be the same recipe with different numbers:
 * one oscillator, an envelope, a slide, maybe a vibrato, a jump, a
 * filter. His window was a column of sliders, and buttons named after
 * what games need ("pickup/coin", "laser/shoot", "explosion",
 * "powerup", "hit/hurt", "jump", "blip/select"), each of which gives a
 * preset or a random pick within that category's ranges. bfxr, jsfxr,
 * ChipTone and PICO-8's sound editor all descend from it.
 *
 * A sound here is the record [t], each field being one of those
 * sliders, and [to_sound] turns it into a Synth tree:
 *
 *     wave, frequency, slide     the voice, its pitch moving (Synth)
 *     attack, sustain, decay     its envelope: up, held, down
 *                                (Envelope.mli; an attack of at least
 *                                5 ms, the ramp that avoids a click)
 *     vibrato, jump              pitch effects (Pitch_effect.mli)
 *     low_pass, high_pass        filters, the low-pass's cutoff moving
 *                                (Filter.mli): subtractive synthesis
 *     echo, reverb               a delay line, a room (Synth.mli)
 *
 *       level
 *         1 |   ________
 *           |  /        \          attack 0.01, sustain 0.1, decay 0.3:
 *           | /          \___      a sound of 0.41 s
 *         0 +---------------------> t
 *            a    s       d
 *
 * Example, the explosion: noise that starts at 1500 steps a second and
 * slides to 150 (from rough to dull), held for 0.1 s then dying away
 * over 0.6 s, through a low-pass whose cutoff falls from 4000 Hz to
 * 150 Hz. That gives the burst, then the rumble, and its eight numbers
 * are all there is to it.
 *
 * What these numbers buy over plain recipes (the first generation of
 * ready-made sounds), measured sound by sound, is in notes_audio.md
 * section 8, "The ready-made sounds, three generations".
 *
 * [vary] is sfxr's "mutate" button: the pitches and times are nudged at
 * random, from a seed, so that the same seed gives the same sound. It makes a
 * family of lasers from one, so that ten shots in a row do not sound
 * like a machine.
 *
 * References: Tomas Pettersson, sfxr, 2007,
 * https://www.drpetter.se/project_sfxr.html; Stephen Lavelle (increpare),
 * bfxr, 2011. *)

(* ix: copied from libs/audio/Sfx.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(*****************************************************************************)
(* {1 A sound as a few numbers} *)
(*****************************************************************************)

type wave = Square | Sawtooth | Triangle | Sine | Noise

type t = {
  wave : wave;
  frequency : float; (* Hz at the start; for noise, its steps a second *)
  slide : float; (* Hz at the end; the same as frequency for no slide *)
  attack : float; (* seconds *)
  sustain : float;
  decay : float;
  vibrato_rate : float; (* Hz *)
  vibrato_depth : float; (* semitones; 0 for no vibrato *)
  jump : float; (* semitones; 0 for no jump *)
  jump_at : float; (* seconds *)
  low_pass : float; (* cutoff, Hz; 0 for no low-pass *)
  low_pass_to : float; (* the cutoff at the end; 0 for a fixed one *)
  resonance : float; (* the low-pass's Q; 0.707 is no resonance *)
  high_pass : float; (* cutoff, Hz; 0 for no high-pass *)
  echo : float; (* the delay, seconds; 0 for no echo *)
  reverb : float; (* the room's reverberation time, seconds; 0: none *)
  volume : float; (* 0 to 1 *)
}

(* a plain beep: a square at 440 Hz, held 0.1 s, with a 0.1 s decay *)
val default : t

(* [to_sound s] is [s] as a Synth tree, [duration s] long with its
 * echo *)
val to_sound : t -> Synth.t

(* [duration s] is attack + sustain + decay (+ the echo's tail) *)
val duration : t -> float

(*****************************************************************************)
(* {1 Presets} *)
(*****************************************************************************)

(* the presets, after sfxr's categories, with our own numbers *)
val blip : t (* a menu, a ball on a paddle *)
val coin : t (* a pickup: a note, then a fifth up *)
val jump : t (* a quick rising square *)
val laser : t (* a sawtooth falling, darker as it falls *)
val hit : t (* a short burst of noise *)
val explosion : t (* noise, a burst then a rumble *)
val step : t (* a soft low tick: footsteps *)
val powerup : t (* a rising square, warbling *)

(* all of them, by name *)
val presets : (string * t) list

(*****************************************************************************)
(* {1 At random} *)
(*****************************************************************************)

(* [vary ~seed s] nudges some numbers of [s] at random: the durations,
 * vibrato rate, jump time and cutoffs are multiplied by 0.7 to 1.4, and
 * the pitches move up to 5 semitones up or down. The others, and the
 * wave, are kept. With [seed] 0, it is [s] itself *)
val vary : seed:int -> t -> t

(* [random category ~seed] is sfxr's buttons, "random laser", "random
 * explosion": every number is drawn afresh, within that category's
 * ranges. The ranges are what make it that kind of sound: a laser
 * always slides down and a jump up, an explosion is noise getting
 * duller, a coin jumps up an interval, a powerup rises and warbles, a
 * hit is short and falls, and a blip holds a note. The ranges are
 * ours, after sfxr's. [category] is one of [presets]'s names except
 * "step" (any other name gives a blip). The same seed gives the same
 * sound *)
val random : string -> seed:int -> t
