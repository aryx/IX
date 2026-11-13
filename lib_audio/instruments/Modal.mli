(* A mode: a struck resonator, which rings as a decaying sine (see
 * notes_synth.md section 10; plan_synth_teaching.md, TinyRhodes, R1).
 *
 * Anything struck (a tine, a bar, a bell, a drum) vibrates in its
 * *modes*. Each mode is a sine at its own frequency, dying at its own
 * rate, and the sound is their sum. Modal synthesis builds a struck
 * object from its modes, as additive synthesis (TinyHammond) builds an
 * organ from sines. But each mode is a *resonator* rather than an
 * oscillator: it rings only when struck, it keeps ringing on its own,
 * and it can be damped while it rings, as when a Rhodes' felt comes back
 * on the tine, or a hand on a cymbal.
 *
 * The resonator has two poles; it is the smallest filter that rings:
 *
 *     y[n] = 2 r cos w  y[n-1]  -  r^2  y[n-2]  +  x[n]
 *
 * Here w is the frequency (2 pi f / rate), and r is how much of its
 * amplitude a sample keeps. r^n is the decay, which reaches -60 dB after
 * t60 seconds when r = 10^(-3 / (t60 rate)). Struck by an impulse of
 * [a sin w], the resonator answers
 *
 *     y[n] = a r^n sin (w (n + 1))
 *
 * which is a sine starting from rest (a hammer gives the tine a
 * velocity, not a displacement), dying exactly as r^n. It costs two
 * multiplies a sample, and no sine is computed, which is why modal
 * synthesis ran on the chips of the 1990s. When it is damped, r changes
 * and the ringing goes on from where it is, faster to silence. The
 * TR-808's drums are the same idea in analogue: a bridged-T filter on
 * the edge of oscillation, struck by a pulse.
 *
 * Worked example (the playground's Unit_modal): 440 Hz, t60 1 s, struck at 0.5.
 * The peak is 0.498 in the first period (the crest falls between two samples),
 * the spectrum shows 440 Hz, and the level is -60 dB after 44,100
 * samples, to 0.1 dB. Damped to a t60 of 0.1 s a quarter second in, it
 * reaches -60 dB 0.1 s later. Struck again while ringing, it gives the
 * two ringings added, to 1e-12 (it is a linear system). *)

(* ix: copied from libs/audio/instruments/Modal.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type t

(* [create ~frequency ~t60] makes a mode at rest *)
val create : frequency:float -> t60:float -> t

(* [strike t a] strikes it, adding [a] to its amplitude; the ringing so
 * far is kept *)
val strike : t -> float -> unit

(* [damp t ~t60] sets its decay from now on; its motion is kept *)
val damp : t -> t60:float -> unit

(* [next t] is the next sample *)
val next : t -> float

(* [level t] is a bound on its amplitude now: at most the sum of a r^n
 * over its strikes. Below a threshold, the mode is silent. *)
val level : t -> float
