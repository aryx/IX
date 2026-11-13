(* The state-variable filter: a filter whose cutoff can move at every
 * sample (see notes_synth.md section 7).
 *
 * The biquad of Filter.mli is designed for one cutoff, because its five
 * coefficients come from it. Recomputed at every sample for a cutoff
 * that moves, they describe a sequence of filters, not a moving one, and
 * the biquad's memory (the last inputs and outputs) belongs to the last
 * filter. Moved slowly, nobody hears it. Moved fast, by an envelope or
 * an LFO at audio rate, the biquad rings too loud, then blows up. And a
 * synthesizer moves its cutoff all the time.
 *
 * The state-variable filter (Hal Chamberlin, Musical Applications of
 * Microprocessors, 1980, after the analog state-variable circuit) is two
 * integrators in a loop, and its parameters are the cutoff and Q
 * themselves. Its states are the band-pass and low-pass outputs, which
 * are real signals and mean the same whatever the cutoff. And it gives
 * four filters at once, from the same two states:
 *
 *            .------------------- -1/Q ---------------.
 *            v                                        |
 *     x -->( + )--> high -->[ integrate ]--> band --+-'--[ integrate ]--> low
 *            ^                                                           |
 *            '------------------------- -1 -----------------------------'
 *
 *     notch = high + low (everything but the cutoff)
 *
 * [Chamberlin]: the integrators are running sums, low += f band and
 * band += f high, with f = 2 sin (pi fc / rate), each reading the
 * other's value from this sample or from the last. It is cheap, and
 * right at low cutoffs, but the delays make it unstable high up.
 * Measured, it is stable at Q = 0.707 up to 7,637 Hz (about a sixth of
 * the rate, the classic warning), at Q = 5 up to 15.9 kHz, and at Q = 20
 * up to 18.9 kHz; above that, it blows up.
 *
 * [Zero_delay]: the same loop is solved within the sample (Zavalishin's
 * topology-preserving transform, as in Moog_ladder.mli; this form is
 * Andrew Simper's, 2013). With g = tan (pi fc / rate) and r = 1/Q,
 *
 *     high = (x - (r + g) s1 - s2) / (1 + r g + g^2)
 *
 * and then two trapezoidal integrators give the band-pass and the
 * low-pass, and update their states. Measured at Q = 0.707, the
 * low-pass, the band-pass and the high-pass are all at -3.01 dB at the
 * cutoff, and the notch is deeper than -219 dB, at 1, 5, 8 and 12 kHz
 * alike (Chamberlin's gives the same up to 5 kHz, and is gone from 8).
 *
 * Worked example: the cutoff is swept at audio rate, as
 * 1000 x 2^(3 sin (2 pi fm t)) (125 Hz to 8 kHz), on a 110 Hz sawtooth
 * that is low-passed (the playground's Unit_moog_ladder), and we look at the
 * loudest output sample. At Q = 5, swept 500 times a second, it is 2.40 through
 * the zero-delay SVF and 6.66 through the biquad recomputed at every
 * sample. Swept 3,000 times a second, it is 2.33, and the biquad blows
 * up. The same sweep at 5 Hz gives 2.38 through both: swept slowly, the
 * biquad is fine.
 *
 * References: Hal Chamberlin, Musical Applications of Microprocessors,
 * Hayden, 1980 (2nd ed. 1985), chapter 14; Andrew Simper, "Linear
 * Trapezoidal Integrated State Variable Filter", Cytomic, 2013; Vadim
 * Zavalishin, The Art of VA Filter Design, 2012, chapter 4. *)

(* ix: copied from libs/audio/instruments/Svf.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type model = Chamberlin | Zero_delay
type mode = Low_pass | Band_pass | High_pass | Notch

val modes : mode list

(* the memories of the two integrators *)
type t

val create : unit -> t

(* [process t model mode ~cutoff ~q samples] filters [samples] in
 * place. [cutoff] is in Hz, one per sample (kept within 10 Hz and
 * 20 kHz). *)
val process :
  t -> model -> mode -> cutoff:Float.Array.t -> q:float -> Float.Array.t ->
  unit

(* [process_fixed] is the same, with one cutoff for every sample *)
val process_fixed :
  t -> model -> mode -> cutoff:float -> q:float -> Float.Array.t -> unit
