(* Delay: the echo, played live, made the way a tape echo makes it (see
 * notes_synth.md section 8.5).
 *
 * This takes the idea of Synth.echo, a delay line whose output is fed
 * back into it, and makes it a streaming effect, in stereo, with what
 * the hardware added:
 *
 *            .--------------- feedback x [low-pass] <------.
 *            v                                              |
 *     x --->( + )--> [ delay line, [time] seconds ] --------+--> wet
 *
 *  - The time is given in seconds, or in *beats* ([beats]). At 120 BPM
 *    a dotted eighth is 0.75 x 0.5 = 0.375 s, so the echoes fall
 *    between the notes (the Edge's guitar).
 *  - The feedback goes through a one-pole low-pass, so each repeat is
 *    darker than the last. A tape loses its highs at each pass over the
 *    heads, and a bucket-brigade chip at each of its thousand steps (the
 *    Roland Space Echo, 1974; the Boss DM-2, 1981). Only the feedback is
 *    filtered: the first echo comes back as it went in, the second is
 *    filtered once, the third twice, and so on.
 *  - In *ping-pong* mode, the dry sound (its two sides mixed) goes into
 *    the left line only, and each line's output is fed back into the
 *    other line, so the repeats alternate sides.
 *  - When the time is turned while the effect sounds, the read position
 *    moves a little each sample (a one-pole towards the new time, which
 *    takes about 50 ms), not at once. The line is then read *faster or
 *    slower* for a moment, and its echoes bend in pitch, as a tape
 *    echo's do when its motor speed changes. The read falls between
 *    samples, so the two neighbours are mixed (Resample's linear
 *    interpolation).
 *
 * Worked example (the playground's Unit_delay): 120 BPM, a dotted eighth (0.375
 * s), feedback 0.5, and the low-pass at 3 kHz. A burst of a 200 Hz sine
 * comes back at 0.375, 0.75 and 1.125 s, at 1, 0.499 and 0.249 of its
 * level (a one-pole at 3 kHz keeps nearly all of 200 Hz). A burst at
 * 8 kHz comes back at 0.842, 0.131 and 0.033 of its level. It is darker
 * at every pass, because the one-pole's gain at 8 kHz (0.37) multiplies
 * the feedback's 0.5. And the first echo's 0.842 is a lesson of its
 * own. 0.375 s is 16,537.5 samples, so the read falls half-way between
 * two samples, and averaging two neighbours is a low-pass, with a gain
 * of cos (pi 8000 / 44100) = 0.842 at 8 kHz. This is the price of the
 * linear read (Resample.mli), heard on every echo whose time falls
 * between samples.
 *
 * References: Will Pirkle, Designing Audio Effect Plugins in C++, 2nd
 * ed. 2019, chapter 14 (delay effects); Julius O. Smith III, Physical
 * Audio Signal Processing, "Delay Lines",
 * https://ccrma.stanford.edu/~jos/pasp/. *)

(* ix: copied from libs/audio/effects/Delay.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* [beats ~bpm b] is the length of [b] beats at [bpm], in seconds (0.75
 * is a dotted eighth when the beat is a quarter note) *)
val beats : bpm:float -> float -> float

(* the longest time, 2 s *)
val longest : float

type t

val create : unit -> t

type settings = {
  time : float; (* in seconds, up to [longest] *)
  feedback : float; (* 0 to 0.95 *)
  tone : float; (* the cutoff of the feedback's low-pass, in Hz *)
  ping_pong : bool;
  mix : float; (* the echoes' level, 0 to 1; the dry sound is kept *)
}

(* [process t settings s] processes [s] in place, both channels *)
val process : t -> settings -> Signal.stereo -> unit

(*****************************************************************************)
(* {1 As an effect} *)
(*****************************************************************************)

(* The knobs, with their ranges and their initial positions, are: time
 * (0.05 to 2 s, initially 0.375, a dotted eighth at 120 BPM), feedback
 * (0 to 0.95, initially 0.4), tone (300 Hz to 12 kHz, initially 3 kHz),
 * pingpong (initially off) and mix (0 to 1, initially 0.3). *)
val knobs : Effect.knob list

(* [fx ()] is the effect named "delay" *)
val fx : unit -> Effect.t
