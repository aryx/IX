(* Drive: a sound pushed into a curve that flattens its loud parts. This
 * is the distortion of an overdriven amplifier (see notes_synth.md
 * section 8.1).
 *
 * Every sample goes through a *waveshaper*, a curve y = f (g x), where
 * [g] is the drive (the gain before the curve, in dB). Quiet samples
 * fall on the curve's straight middle and come out as they went in;
 * loud ones are flattened.
 *
 *     y                     hard   corners: a sine becomes a square
 *     1 |       ______      tanh   a smooth knee, the classic curve
 *       |     /             cubic  1.5 (x - x^3 / 3), smoother
 *       |    /                     still, and flat from 1 on
 *     --+---/-------> g x   asym   tanh with a bias, which flattens one
 *       |  /                       side before the other, as a tube or
 *    -1 |_/                        a diode does: even harmonics
 *
 * A flattened sine is a sine plus its harmonics. A symmetric curve adds
 * the odd ones (3, 5, 7, ...), and the asymmetric one adds the even ones
 * too (2, 4, ...; the 2nd is an octave above, and sounds "warmer").
 * Adding harmonics is the point, and also the trouble, because they do
 * not stop at Nyquist. A 5 kHz sine through tanh gets its 3rd harmonic
 * at 15 kHz, its 5th at 25 kHz (folded to 19.1 kHz), its 7th at 35 kHz
 * (folded to 9.1 kHz), and its 9th at 45 kHz, folded to 0.9 kHz. That is
 * a tone *under* the note, a harmonic of nothing, the fizz of cheap
 * distortion (the aliasing of notes_audio.md section 2, made here by the
 * effect itself).
 *
 * The cure is *oversampling*: do the shaping at a higher rate, where the
 * new harmonics fit, then filter them out before coming back down:
 *
 *     44.1 kHz --> x L (zeros in between) --> low-pass --> shape
 *              --> low-pass --> every L-th sample --> 44.1 kHz
 *
 * The first low-pass fills the zeros in: it removes the images of the
 * spectrum that the zeros make, which is an interpolation. The second
 * removes what the shaping put above 20 kHz, before it can fold. Both
 * are 8th-order Butterworths (four biquads) at 18 kHz, run at
 * L x 44,100.
 *
 * Worked example (the playground's Unit_drive): a 5 kHz sine goes through tanh
 * at +12 dB, and we measure the loudest thing below 4 kHz, under the note.
 * Only aliases can be there, since the first harmonic is the note
 * itself, at 5 kHz:
 *
 *     L = 1 (none)   -32.6 dB, at 904 Hz: the 9th, folded
 *     L = 2          -58.6 dB, at 3198 Hz
 *     L = 4          -81.7 dB (at 904 Hz, the 9th's remains)
 *
 * x2 already stops the 5th to the 9th harmonics, because 25 to 45 kHz
 * fit under 44.1 kHz, the new Nyquist. The 17th, at 85 kHz, still folds
 * there, to 3.2 kHz, and that is what x2 leaves. (This is measured on
 * 4096 samples, Hann-windowed, with Spectrum.of_signal.) The price is L
 * times the work, and the filters' delay (a few samples).
 *
 * The asymmetric curve leaves a constant offset (its bias), which a
 * one-pole high-pass at 10 Hz takes away, as the capacitor after a tube
 * stage does.
 *
 * References: Udo Zolzer (ed.), DAFX: Digital Audio Effects, 2nd ed.
 * 2011, chapter 4 (nonlinear processing); Will Pirkle, Designing Audio
 * Effect Plugins in C++, 2nd ed. 2019, chapter 19 (waveshapers and
 * oversampling). *)

(* ix: copied from libs/audio/effects/Drive.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type shape = Hard | Tanh | Cubic | Asymmetric

val shapes : shape list
val name : shape -> string

(* [curve shape x] is the curve, between -1 and 1 (the asymmetric one
 * is tanh (x + 0.3) - tanh 0.3, which goes from -1.29 to 0.71) *)
val curve : shape -> float -> float

(* the state of the oversampling filters and of the DC blocker *)
type t

(* [create ~oversampling ()], where [oversampling] is 1, 2 or 4 *)
val create : oversampling:int -> unit -> t

(* [process t shape ~drive ~mix s] processes [s] in place. [drive] is
 * the gain in dB before the curve, and [mix] is the share of the shaped
 * sound (0 is dry, 1 is all driven). *)
val process : t -> shape -> drive:float -> mix:float -> Signal.t -> unit

(*****************************************************************************)
(* {1 As an effect} *)
(*****************************************************************************)

(* The knobs are: shape (hard, tanh, cubic or asymmetric, initially
 * tanh), gain (the drive, 0 to 36 dB, initially 12) and oversampling (a
 * switch between x4 and none, initially on). *)
val knobs : Effect.knob list

(* [fx ()] is the effect named "drive". It processes both channels, and
 * the dry sound is gone (mix 1). *)
val fx : unit -> Effect.t
