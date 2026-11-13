(* Resampling: a recorded sound played faster or slower, or at another
 * rate (see notes_audio.md section 9, "Samples").
 *
 * A synthesized voice changes pitch by changing a number, its frequency.
 * A recording has no such number. To play it an octave up, you read it
 * twice as fast, at samples 0, 2, 4, ...; to play it a fifth up, you
 * read it 1.5 times as fast, at samples 0, 1.5, 3, 4.5, ... But there is
 * no sample 1.5. How to make one up is the audio twin of scaling an
 * image (the image filtering of graphics/2d), with the same three
 * answers:
 *
 *   nearest   the sample at round(position). It is cheap, but it makes
 *             a staircase, and the jumps are new frequencies, which is
 *             distortion. (The Amiga's Paula chip read its samples this
 *             way, and a tracker's high notes had that grit.)
 *   linear    a straight line between the two neighbours. The
 *             staircase's corners are gone, and much of its distortion
 *             too.
 *   cubic     a curve through four neighbours (Catmull-Rom). It is
 *             smoother, and closer again.
 *
 *       samples   *     *           nearest   *--*  *--*
 *                    *     *                     *--*  *--*
 *       read at 1.5: between them   linear    *-._   _.-*
 *                                                 *-*
 *
 * Example (the playground's Unit_resample): a sine read a fifth faster
 * (2^(7/12)) is a sine a fifth higher, and whatever else is in the result is
 * the method's error. The loudest error, in dB below the sine, is, when
 * the sine is read up to 689 Hz: nearest -39.6 dB, linear -79.2, cubic
 * -112.5; and up to 2756 Hz: -27.3, -54.6 and -75.3. The higher the
 * note, the fewer samples there are in a period to guess between, and
 * the worse the error, as a finer pattern is for image filtering. (At
 * exactly 1.5 the reads fall only on whole and half samples, and the
 * cubic looks better than it is, at -133 dB; a real pitch visits every
 * fraction.) Reading
 * faster has a price, whatever the method. The recording is shorter by
 * as much (a voice sped up sounds like a chipmunk, and lasts less: pitch
 * and time go together, on tape and here). And when it is read faster,
 * its highs can pass the Nyquist frequency and fold. (An exercise:
 * low-pass first, the way a good sampler does.)
 *
 * References: Julius O. Smith III, "Digital Audio Resampling Home
 * Page", https://ccrma.stanford.edu/~jos/resample/; Edwin Catmull,
 * Raphael Rom, "A Class of Local Interpolating Splines", 1974. *)

(* ix: copied from libs/audio/signal/Resample.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type kind = Nearest | Linear | Cubic

val kinds : kind list
val name : kind -> string

(* the kind Synth uses to play a recording at another pitch; it is
 * Linear, and nothing in ix changes it *)
val kind : kind ref

(* [read kind s position] is [s] at a position between two samples (0
 * past either end) *)
val read : kind -> Signal.t -> float -> float

(* [faster kind k s] is [s] read [k] times as fast: its pitch is
 * multiplied by [k], and its length divided by [k] *)
val faster : kind -> float -> Signal.t -> Signal.t

(* [to_rate kind rate s] takes [s], sampled [rate] times a second, to
 * Signal.rate instead (a file recorded at 22,050 and played at 44,100
 * is read at half speed) *)
val to_rate : kind -> int -> Signal.t -> Signal.t
