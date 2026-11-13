(* Envelopes: how a sound starts and stops (see notes_audio.md
 * section 4).
 *
 * A tone switched on or off at once clicks, because its wave jumps, and
 * a jump is a burst of every frequency. No real instrument does that: a
 * piano's note starts sharply and dies away, and a violin's swells. An
 * envelope is the volume over time, multiplied into the wave. The
 * classic one, from the analog synthesizers of the 1960s (Robert Moog's,
 * ARP's), is ADSR:
 *
 *    volume
 *     1 |   /\
 *       |  /  \
 *     S |_/____\_____________        A: attack, the time to full volume
 *       |/               |   \       D: decay, the time down to...
 *     0 +--A--D----------+-R--\-->   S: sustain, ...this level, held
 *       0                held    t   R: release, the time to silence,
 *                                       once the note is let go
 *
 * Example: A = 0.01 s, D = 0.1 s, S = 0.5, R = 0.2 s, and the note is
 * held 0.5 s. At 0.005 s, halfway up, the level is 0.5; at 0.06 s,
 * halfway down, 0.75; at 0.3 s, sustaining, 0.5; at 0.6 s, halfway
 * through the release, 0.25; and from 0.7 s on, 0. When the note is let
 * go before the sustain (a short note), the release starts from
 * wherever the volume was.
 *
 * A percussive sound (a blip, a drum, most game sounds) has a short
 * attack and a decay to 0, with no sustain ([percussive]); an organ is
 * all sustain. The lines are straight here. Analog synthesizers curve
 * them (exponentially, because the ear hears ratios: see Mix.mli), as
 * the live envelope below can.
 *
 * References: the ADSR envelope generator, credited to Vladimir Ussachevsky
 * (1965) for Robert Moog's modular synthesizers; Curtis Roads, The
 * Computer Music Tutorial, 1996, chapter 4. *)

(* ix: copied from libs/audio/synthesis/Envelope.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type t = {
  attack : float; (* in seconds *)
  decay : float; (* in seconds *)
  sustain : float; (* a level, 0 to 1 *)
  release : float; (* in seconds *)
}

(* [percussive ~attack ~decay] goes up, then down to 0, with no sustain
 * and no release *)
val percussive : attack:float -> decay:float -> t

(* [level env ~held time] is the volume at [time] seconds after the
 * start, when the note is let go at [held] *)
val level : t -> held:float -> float -> float

(* [duration env ~held] is when the envelope is silent for good,
 * held + release *)
val duration : t -> held:float -> float

(* [apply env ~held samples] multiplies each sample by the level at its
 * time *)
val apply : t -> held:float -> Signal.t -> Signal.t

(*****************************************************************************)
(* {1 Live: an envelope driven by a gate} *)
(*****************************************************************************)
(* Above, the note's length is known ([held]), and the envelope is
 * computed whole. When it is played live (Instrument.mli), nobody knows
 * when the key will come up. So the envelope is a state machine, driven
 * by a *gate*, which is on while the key is held (see notes_synth.md
 * section 4):
 *
 *     gate on              gate off
 *        |                    |
 *   Idle --> Attack --> Decay --> Sustain --> Release --> Idle
 *               ^                                 |
 *               '--- gate on again: from the level where it is
 *
 * A new gate starts the attack from the current level, not from 0. So a
 * note played again while the last one dies away rises from there,
 * without a jump. (Whether a new key reopens the gate at all, or plays
 * legato, is Voicing.mli's choice.) The ADSR's times and sustain are
 * read at each block, so knobs can be turned while it runs.
 *
 * {2 Straight or exponential}
 *
 * [Linear] gives the lines above, the same levels as [level] (the tests
 * compare the two on the example). [Exponential] gives the segments of
 * an analog envelope, a capacitor charging through a resistor towards a
 * target. Each sample is a one-pole step, level += (target - level) c,
 * so the level approaches its target by a fixed *ratio* per sample. This
 * has two consequences:
 *
 *  - It never arrives. So the attack aims *past* 1, at 1.5, and stops
 *    when it gets to 1. Since 1.5 (1 - e^(-t / tau)) = 1 at t = tau ln 3,
 *    tau = attack / ln 3 (0.91 attack) makes it arrive in its time.
 *    Halfway through, it is already at 1.5 (1 - 1 / sqrt 3) = 0.634, not
 *    0.5, which gives a punchier start. The decay and the release aim at
 *    their targets for good, and their time is the time to get most of
 *    the way, to a thousandth of the distance: tau = time / ln 1000
 *    (time / 6.91).
 *  - It is a straight line in decibels, the ear's scale (Mix.mli). The
 *    exponential release loses 60 dB over its time, the same number of
 *    dB every millisecond, which is a natural fade. The straight release
 *    loses little at first and plunges at the end (-6 dB at half its
 *    time, -20 dB at 90%, -40 dB at 99%, then silence), so it sounds cut
 *    off.
 *
 * Worked example, the exponential curve on the example's ADSR (A = 0.01,
 * D = 0.1, S = 0.5, R = 0.2). It is at 0.634 at 5 ms, and at 1 at 10 ms
 * (441 samples). It is at 0.5158 at 0.06 s (halfway through the decay,
 * the distance to S, 0.5, is divided by sqrt 1000 = 31.6), and at 0.5005
 * at 0.11 s. Let go from 0.5 at 0.5 s, it is at 0.0158 at 0.6 s and at
 * 0.0005 at 0.7 s (-60 dB). It becomes Idle below 0.00001 (-100 dB).
 *
 * References: the Minimoog's contour generators; Will Pirkle, Designing
 * Software Synthesizer Plug-Ins in C++, 2014, chapter 7 (the analog
 * envelope's overshooting targets). *)

type curve = Linear | Exponential
type stage = Idle | Attack | Decay | Sustain | Release

type running

(* creates an envelope that is idle, at 0 *)
val start : unit -> running

(* the key is pressed (the attack starts, from the current level), or
 * let go (the release starts, from the current level) *)
val gate_on : running -> unit
val gate_off : running -> unit

(* [fill curve env r out] fills [out] with the next [Array.length out]
 * levels *)
val fill : curve -> t -> running -> Signal.t -> unit

val stage : running -> stage
val current : running -> float
