(* Dynamics: the compressor, the limiter and the noise gate, which are
 * one machine with three settings (see notes_synth.md section 8.7).
 *
 * The other effects change a sound's spectrum or its time. These change
 * its *loudness*, and they do it from its loudness: they are a knob
 * turned by the sound itself, faster than a hand could turn it. This is
 * the design of Giannoulis, Massberg and Reiss (2012), in three parts,
 * all in decibels:
 *
 *     x --+-----------------------------------------(x gain)--> y
 *         |                                             ^
 *         '--> level (dB) --> gain computer --> smoothing --> + makeup
 *              |x|, or its RMS    the static curve   attack and release
 *
 * {1 The gain computer: the static curve}
 *
 * The curve gives what the output level would be if the input were held
 * steady at a level x, all in dB, with T the threshold, R the ratio and
 * W the knee's width:
 *
 *     y = x                                 below T - W/2 (untouched)
 *     y = T + (x - T) / R                   above T + W/2
 *     y = x + (1/R - 1) (x - T + W/2)^2 / 2W    between: the soft knee
 *
 *     out (dB)                     ratio 4:1: above the threshold, 4 dB
 *        |            ____ ...     in give 1 dB out
 *        |       ____/
 *     T  +------/
 *        |    /                    Worked example: T = -20 dB, R = 4,
 *        |  /                      an input at -8 dB (12 over) comes out
 *        |/                        at -20 + 12 / 4 = -17 dB: 9 dB of
 *        +------+--------> in (dB) gain reduction.
 *               T
 *
 * The *limiter* is the ratio made infinite (y = T above the threshold,
 * which is a ceiling). The *noise gate* is the curve turned the other
 * way, below the threshold: y = T + (x - T) R. It is an expander (R = 10
 * is practically silence), and it removes the hiss between the notes.
 *
 * {1 The smoothing: attack and release}
 *
 * The curve says how much to turn the sound down, the gain reduction
 * x - y. Applied at once, it would be heard as distortion, because it
 * would turn down a sine's peaks rather than the whole sine. So the
 * reduction follows the curve's value through a one-pole, which is fast
 * when the reduction grows (the attack, a few ms, so that a loud note is
 * caught quickly) and slow when it falls (the release, 50 to 500 ms, so
 * that the gain comes back smoothly). A compressor with a slow attack
 * lets a drum's first milliseconds through before it clamps down, which
 * gives the "punch".
 *
 * The *limiter*'s job is that nothing passes the ceiling, so it cannot
 * wait even for an attack. It looks ahead instead: the sound is delayed
 * by [lookahead], while the detector hears the loudest sample of that
 * window (the samples that are not out yet, the next one out among
 * them) and turns down at once. Every sample's gain was then set knowing
 * that sample, so nothing passes. (With a short attack in place of the
 * window, a 0.5 ms one, the peaks of a 441 Hz sine came through at
 * -5.24 dB against a -6 dB ceiling, because a one-pole cannot follow a
 * peak a third of a millisecond wide.)
 *
 * {1 The side-chain}
 *
 * The detector can listen to another sound than the one it turns down,
 * the *key*. With a kick drum as the key on a bass, the bass is ducked
 * at every kick and swells back during the release. This is "pumping",
 * the sound of 2000s dance music, and also how a radio's voice-over
 * ducks its music.
 *
 * Worked examples (the playground's Unit_dynamics):
 *
 *  - The static curve: -8 dB in gives -17 out (T -20, R 4, no knee).
 *    With a 6 dB knee, the threshold itself gives -20.56.
 *  - The attack: a -40 dB square wave jumps to -8 dB (a square's level
 *    is the same at every sample, so the detector's own ripple is out
 *    of the way). The reduction reaches 63% of its 9 dB in 4.99 ms (the
 *    attack is set to 5), and falls back to 37% in 99.96 ms (the release
 *    is set to 100) when the wave drops again.
 *  - The limiter at -6 dB (0.501), with 5 ms of look-ahead: a 441 Hz
 *    burst at 0 dB comes out at 0.501, never over.
 *  - The gate at -40 dB, 10:1: a -50 dB hum comes out at -140 dB, 90 dB
 *    under (10 dB below the threshold in is 100 dB below it out).
 *  - The side-chain: a 55 Hz bass at -12 dB, keyed by bursts of a 60 Hz
 *    sine at 0 dB (T -20, R 4, a peak detector), comes out at -26 dB
 *    during the bursts and at -12.3 dB between them, so it is ducked by
 *    13.7 dB.
 *
 * References: Dimitrios Giannoulis, Michael Massberg, Joshua D. Reiss,
 * "Digital Dynamic Range Compressor Design -- A Tutorial and Analysis",
 * JAES 60(6), 2012; Will Pirkle, Designing Audio Effect Plugins in C++,
 * 2nd ed. 2019, chapter 18. Mix.limit, the tanh at the end of the mixer,
 * is a *soft clip*, not a limiter. It bends every sample over its knee
 * at once (which is distortion), whereas this module turns the whole
 * sound down (which adds no new harmonics). *)

(* ix: copied from libs/audio/effects/Dynamics.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

type mode = Compressor | Limiter | Gate

val modes : mode list
val name : mode -> string

type detector = Peak | Rms

type settings = {
  mode : mode;
  threshold : float; (* in dB *)
  ratio : float; (* 1 to 20, where 4 means 4:1; the limiter ignores it *)
  knee : float; (* the soft knee's width, in dB *)
  attack : float; (* in seconds *)
  release : float; (* in seconds *)
  makeup : float; (* the gain applied after, in dB *)
  detector : detector;
  lookahead : float; (* in seconds; only the limiter uses it *)
}

(* a compressor: -20 dB, 4:1, a 6 dB knee, 5 ms of attack, 100 ms of
 * release, no makeup, and an RMS detector *)
val compressor : settings

(* a limiter: -1 dB, 0.5 ms of attack, 50 ms of release, a peak
 * detector, and 5 ms of look-ahead *)
val limiter : settings

(* a gate: -40 dB, 10:1 below the threshold, 1 ms of attack, 100 ms of
 * release, and a peak detector *)
val gate : settings

(* [curve settings x] is the static curve; x and the result are in dB *)
val curve : settings -> float -> float

type t

val create : unit -> t

(* [process ~key t settings s] processes [s] in place, both channels.
 * The detector hears [key] if it is Some (the side-chain; it must be
 * as long as [s]), or else [s] itself, with its two sides linked (the
 * louder one counts). *)
val process : key:Signal.stereo option -> t -> settings -> Signal.stereo -> unit

(* the gain reduction at the end of the last block, in dB (0 or more) *)
val reduction : t -> float

(*****************************************************************************)
(* {1 As an effect} *)
(*****************************************************************************)

(* The knobs are: mode (compressor, limiter or gate, initially the
 * compressor), threshold (-60 to 0 dB, initially -20), ratio (1 to 20,
 * initially 4), attack (0.5 to 100 ms, initially 5), release (10 ms to
 * 1 s, initially 100 ms) and makeup (0 to 24 dB, initially 0). The knee,
 * the detector and the look-ahead are those of the mode's settings
 * ([compressor], [limiter] or [gate]). *)
val knobs : Effect.knob list

(* [fx ()] is the effect named "dynamics", with a meter named
 * "reduction" (in dB) *)
val fx : unit -> Effect.t
