(* The diode ladder: the TB-303's filter, and why it squelches (see
 * notes_synth.md; plan_synth_teaching.md, TinyTB303, B1).
 *
 * Moog's ladder (Moog_ladder.mli) is four one-pole filters in a row,
 * each one *buffered* by its transistors. A pole does not feel the next
 * one, and the four together are exactly the product of four equal
 * one-poles. Roland's TB-303 (1981) builds its ladder of diodes instead,
 * and the stages of a diode ladder load each other: each capacitor is
 * charged from the one before and drained by the one after,
 *
 *         u --[2w]-- v1 --[w]-- v2 --[w]-- v3 --[w]-- v4 --> out
 *                     |          |          |          |
 *                    C/2         C          C          C
 *
 *     v1' = 2w ((u - v1) - (v1 - v2))       u = x - k v4 (the feedback)
 *     v2' =  w ((v1 - v2) - (v2 - v3))
 *     v3' =  w ((v2 - v3) - (v3 - v4))
 *     v4' =  w  (v3 - v4)
 *
 * (w = 2 pi fc. As in the 303, the first capacitor is half the size of
 * the others, so its pole is an octave up.) The coupling spreads the
 * four poles apart instead of stacking them. So the slope just above the
 * cutoff is gentler than the Moog's 24 dB an octave, and it reaches that
 * slope only far above; this is the "18 dB an octave" that the 303 is
 * said to have, measured here. And the resonance, the feedback k, peaks
 * less sharply and needs more feedback to sing. That gives the rubbery,
 * vocal squelch of acid, where the Moog whistles.
 *
 * The filter is solved as the Moog ladder's zero-delay model is
 * (Zavalishin), but written out. The four equations are integrated by
 * the trapezoidal rule, with the cutoff prewarped (w comes from
 * tan (pi fc / rate), so that the digital filter's frequencies are the
 * analog one's at fc). This makes each sample a 4 x 4 linear system in
 * the new v1..v4, which is solved exactly, so there is no delay in the
 * loop and the resonance is where it belongs. A tanh on the input (the
 * diodes bend loud signals) keeps the sound gritty and bounded.
 *
 * Worked example (the playground's Unit_diode_ladder), measured on sines
 * against the zero-delay model of Moog_ladder at the same fc = 500 Hz, with no
 * feedback:
 *
 *                     at fc     1 -> 2 kHz   2 -> 4 kHz   4 -> 8 kHz
 *     diode ladder   -21.3 dB   -15.8 dB     -20.7 dB     -25.8 dB
 *     Moog ladder    -12.0      -21.4        -24.0        -27.0
 *
 * This shows the spread poles. The gain at fc is far lower (the 303's
 * cutoff knob sets the scale of the poles, not a -3 dB point). Then the
 * slope just above is about 16 dB an octave (the "18 dB"), and it
 * reaches the Moog's slope only far above (both get steeper near
 * Nyquist, where the trapezoid puts its zero). A constant goes through
 * it at 1 / (1 + k), as through the Moog's. The feedback at which it
 * starts to ring on its own is 22.1, where the Moog's is 4, because the
 * coupling spends the loop's gain. At 80% of that feedback, its peak is
 * at 667 Hz, above the cutoff, where the Moog's peak sits at the cutoff.
 *
 * References: Tim Stinchcombe, "Analysis of the Moog Transistor Ladder
 * and Derivative Filters", 2008, and his TB-303 diode ladder model,
 * https://www.timstinchcombe.co.uk/index.php?pge=diode2; Vadim
 * Zavalishin, The Art of VA Filter Design, 2012 (rev. 2018), chapter 5
 * (the diode ladder); Robin Whittle's "303 unique" page. *)

(* ix: copied from libs/audio/instruments/Diode_ladder.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* the voltages of the four capacitors *)
type t

val create : unit -> t
val reset : t -> unit

(* [process t ~cutoff ~resonance samples] filters [samples] in place.
 * [cutoff] is in Hz, one per sample (kept within 10 Hz and 20 kHz), and
 * [resonance] is the feedback k. *)
val process :
  t -> cutoff:Float.Array.t -> resonance:float -> Float.Array.t -> unit
