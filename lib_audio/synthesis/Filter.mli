(* Filters: shaping the spectrum (see notes_audio.md section 7).
 *
 * A filter lets some frequencies through and weakens others. Its memory
 * is what does it. A filter's output depends on the last few samples,
 * and a slow wave looks the same from one sample to the next, whereas a
 * fast one does not.
 *
 * The simplest filter is the one-pole low-pass, a running average that
 * follows the input slowly. It is one line:
 *
 *     y := y + a (x - y)          a = 1 - exp (-2 pi cutoff / rate)
 *
 * At each sample it goes a fraction [a] of the way towards the input, so
 * a slow wave is followed and a fast one is averaged away. For a 1000 Hz
 * cutoff at 44,100, a = 0.133. Its gain falls by half (-6 dB) for each
 * octave above the cutoff (-3 dB at the cutoff itself), which is gentle.
 * The input minus the low-pass is the high-pass, the fast part.
 *
 * The biquad has two samples of memory of the input and two of the
 * output, and five coefficients (b0 b1 b2 over a1 a2, the numerator and
 * the denominator of its transfer function, hence "bi-quadratic"):
 *
 *     y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2]
 *
 * It falls twice as fast (-12 dB an octave), and it has a resonance, Q,
 * which is a boost at the cutoff. Q goes from no boost (Q = 0.707,
 * "Butterworth", the flattest) to a whistle (Q = 10 gives +20 dB, and
 * the filter rings at its own frequency). Robert Bristow-Johnson's
 * cookbook gives the five numbers for every classic filter from the
 * cutoff and Q. For the low-pass, with w = 2 pi cutoff / rate and
 * alpha = sin w / (2 Q):
 *
 *     b0 = b2 = (1 - cos w) / 2,  b1 = 1 - cos w,
 *     a0 = 1 + alpha,  a1 = -2 cos w,  a2 = 1 - alpha   (all over a0)
 *
 *     a low-pass at 1 kHz, its gain (dB) at     1 kHz   2 kHz   4 kHz
 *     the one-pole                               -3.0    -7.0   -12.2
 *     the biquad, Q = 0.707 (Butterworth)        -3.0   -12.4   -24.6
 *     the biquad, Q = 10                        +20.0    -9.7   -24.0
 *
 * (the playground's Unit_filter checks them, on sines actually filtered.)
 *
 * [response] computes the gain at a frequency from the coefficients (the
 * transfer function on the unit circle, H(e^iw)), which the tests
 * compare with a sine actually filtered.
 *
 * What filters are for is subtractive synthesis, the way of the analog
 * synthesizers (Moog, 1964): you start from a wave rich in harmonics (a
 * sawtooth, a square, noise) and take some of them away. A low-pass on
 * noise is a rumble, an engine, an explosion; a high-pass on noise is a
 * hiss, a cymbal. A resonant low-pass whose cutoff moves ([sweep]) is
 * the "wah" of every synthesizer since: the resonance's boost sweeps
 * through the harmonics.
 *
 * References: Julius O. Smith III, Introduction to Digital Filters,
 * 2007, https://ccrma.stanford.edu/~jos/filters/; Robert
 * Bristow-Johnson, "Cookbook formulae for audio EQ biquad filter
 * coefficients" (the Audio EQ Cookbook), 1998; Robert Moog, "Voltage-
 * Controlled Electronic Music Modules", Journal of the Audio
 * Engineering Society, 1965. *)

(* ix: copied from libs/audio/synthesis/Filter.mli
 * in the author's playground (docs/plans/plan_audio.md). The optional
 * rate of biquad and response is given to biquad_at and response_at
 * instead. *)

(*****************************************************************************)
(* {1 The one-pole} *)
(*****************************************************************************)

(* [one_pole_coefficient cutoff] is the a above, 0.133 for 1000 Hz *)
val one_pole_coefficient : float -> float

(* [low_pass ~cutoff s] and [high_pass ~cutoff s] are the one-pole
 * filters *)
val low_pass : cutoff:float -> Signal.t -> Signal.t
val high_pass : cutoff:float -> Signal.t -> Signal.t

(*****************************************************************************)
(* {1 The biquad} *)
(*****************************************************************************)

type kind = Low_pass | High_pass | Band_pass

(* the five coefficients, with a0 divided out *)
type biquad = { b0 : float; b1 : float; b2 : float; a1 : float; a2 : float }

(* [biquad kind ~cutoff ~q] gives the cookbook's coefficients (the
 * band-pass has its peak at 0 dB) *)
val biquad : kind -> cutoff:float -> q:float -> biquad

(* the same at another rate than Signal's (for an effect that runs
 * several times a sample) *)
val biquad_at : rate:float -> kind -> cutoff:float -> q:float -> biquad

(* [response f frequency] is the gain of [f] at [frequency], where 1
 * means unchanged *)
val response : biquad -> float -> float
val response_at : rate:float -> biquad -> float -> float

(*****************************************************************************)
(* {1 The EQ} *)
(*****************************************************************************)

(* The rest of the cookbook gives the filters of a mixing desk's EQ.
 * They do not take frequencies away; they raise or lower a region by
 * [gain] dB and leave the rest alone (see notes_synth.md section 8.2):
 *
 *     dB   peaking, +6 at 1 kHz        low shelf, +6 from 200 Hz down
 *     +6 |        _                    +6 |___
 *        |       / \                      |    \
 *      0 |______/   \______             0 |     \__________
 *        +------------------> Hz          +------------------> Hz
 *                1k                            200
 *
 * The bell's width is its Q (Q = 1 gives 1.4 octaves between the points
 * where the bell is at half its gain in dB). A shelf is at half its gain
 * (in dB) at its frequency, and at all of it far past that frequency. A
 * three-band EQ (the bass, the middle and the treble of a hi-fi) is a
 * low shelf, a peaking and a high shelf one after the other, and the
 * playground's Rack builds its EQ that way.
 *
 * Worked example (the playground's Unit_filter, on sines actually filtered):
 *
 *     gain (dB) at          50 Hz  200 Hz  500 Hz  1 kHz  2 kHz  8 kHz
 *     peaking +6 at 1 kHz,
 *       Q = 1                0.02    0.27    1.88   6.00   1.86   0.08
 *     low shelf +6, 200 Hz   5.97    3.00    0.16   0.01   0.00   0.00
 *     high shelf -6, 4 kHz   0.00    0.00    0.00  -0.02  -0.35  -5.73
 *
 * (The high shelf's -6 is reached only well above 8 kHz, because at
 * 4 kHz it is -3, and 8 kHz is only one octave further.) *)

(* [peaking ~frequency ~q ~gain], with [gain] in dB *)
val peaking : frequency:float -> q:float -> gain:float -> biquad

(* [low_shelf ~frequency ~gain] and [high_shelf ~frequency ~gain] *)
val low_shelf : frequency:float -> gain:float -> biquad
val high_shelf : frequency:float -> gain:float -> biquad

(* [run f s] sends [s] through [f], starting from silence *)
val run : biquad -> Signal.t -> Signal.t

(* A biquad's memory is its last two inputs and outputs. It is what lets
 * a continuous sound go through a filter a block at a time, as the
 * mixer pulls it, without a click where the blocks meet. *)
type memory

val silence : unit -> memory

(* [step f m x] sends one sample through [f] and updates [m] *)
val step : biquad -> memory -> float -> float

(* [chain fs ms x] sends x through each of [fs] in turn, with [ms] their
 * memories: it is [step] on each, one after the other *)
val chain : biquad array -> memory array -> float -> float

(* [process f m s] sends a block through [f], in place *)
val process : biquad -> memory -> Signal.t -> unit

(* [sweep kind ~q ~from ~to_ s] sends [s] through a biquad whose cutoff
 * moves from [from] to [to_] over [s], evenly in octaves (as the ear
 * hears it); its coefficients are recomputed at each sample *)
val sweep : kind -> q:float -> from:float -> to_:float -> Signal.t -> Signal.t
