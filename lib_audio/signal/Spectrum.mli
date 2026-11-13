(* The spectrum: which frequencies a sound contains (see notes_audio.md
 * section 6).
 *
 * Joseph Fourier (1822) showed that every periodic signal is a sum of
 * sines. The discrete Fourier transform (DFT) finds them in N samples.
 * For each frequency bin k (k cycles over the N samples, which is
 * k rate / N Hz), it finds how much of that frequency there is, by
 * correlating the signal with a sine and a cosine of that frequency:
 *
 *     X[k] = sum over n of x[n] (cos (2 pi k n / N) - i sin (2 pi k n / N))
 *
 * The result is a complex number: its size is how much, and its angle is
 * the phase. N bins, each a sum of N terms, make N^2 multiplications,
 * 16.8 million for N = 4096. The fast Fourier transform (FFT: Cooley and
 * Tukey, 1965, after Gauss, 1805) gets the same numbers in N log2 N,
 * 49,152 for 4096. It splits the samples into the even ones and the odd
 * ones, transforms each half (recursively), and combines them with a
 * "butterfly", because the sums of the two halves share all their work.
 * Both are here: the simple one checks the fast one (in the tests), and
 * the fast one is the one used.
 *
 *     amplitude              a 440 Hz square: its odd harmonics, at
 *        |                   1, 1/3, 1/5, ... (Oscillator.mli), make
 *        |                   bars at 440, 1320, 2200, ...
 *        |   |
 *        |   |    |    |   |
 *        +---+----+----+---+----> frequency
 *           440 1320 2200 3080
 *
 * Examples, with N = 8. An impulse, [1 0 0 0 0 0 0 0], has every bin at
 * 1: it contains all frequencies equally, and sounds as a click. A
 * cosine making one cycle over the 8 samples has bins 1 and 7 at 4 (N/2:
 * the positive and the negative frequency), and the others at 0.
 *
 * [magnitudes] scales the bins so that a sine of amplitude A shows as A
 * at its bin. A frequency between two bins leaks into its neighbours,
 * because the N samples cut the wave in the middle of a period, which
 * makes a jump that is not in the sound. A window (Hann's, which fades
 * the ends to 0) trades that leak for a wider peak, which suits a
 * display.
 *
 * References: Joseph Fourier, Théorie analytique de la chaleur, 1822;
 * James Cooley, John Tukey, "An Algorithm for the Machine Calculation
 * of Complex Fourier Series", Mathematics of Computation, 1965; Julius
 * O. Smith III, Mathematics of the Discrete Fourier Transform, 2007,
 * https://ccrma.stanford.edu/~jos/mdft/ *)

(* ix: copied from libs/audio/signal/Spectrum.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

(* complex numbers, as (real, imaginary) *)
type complex = float * float

(* [dft x] is the transform by its definition, in N^2 *)
val dft : float array -> complex array

(* [fft x] is the same, in N log N; N must be a power of 2 *)
val fft : float array -> complex array

(* [magnitudes spectrum] gives bins 0 to N/2 (the frequencies up to
 * Nyquist; the others mirror them), each as 2 |X[k]| / N, which is a
 * sine's amplitude (bin 0, the average, and bin N/2 are |X[k]| / N) *)
val magnitudes : complex array -> float array

(* [bin_frequency ~n k] is k rate / n Hz *)
val bin_frequency : n:int -> int -> float

(* [hann x] fades x to 0 at both ends (1 - cos), against the leak *)
val hann : float array -> float array

(* [of_signal ~window s] gives the magnitudes of the first samples of
 * [s], as many as the largest power of 2 that fits (at most 4096),
 * Hann-windowed if [window] is true *)
val of_signal : window:bool -> Signal.t -> float array

(* [peak mags] is the bin with the most, bin 0 excluded *)
val peak : float array -> int
