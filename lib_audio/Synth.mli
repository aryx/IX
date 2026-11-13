(* Sounds as values: what Audio's sounds are underneath, and how they
 * become samples (see notes_audio.md sections 3-5, 8).
 *
 * A sound is a tree, the way a picture is a tree of shapes. At the
 * leaves are voices: an oscillator or noise, at a frequency, for a
 * duration, at a volume, maybe sliding to another frequency, maybe
 * fading out. Above them are sounds played together or one after the
 * other. The two combinators are those of Paul Hudak's Euterpea (the
 * library of The Haskell School of Music), whose music values are
 * built with (:=:), "together", and (:+:), "one after the other"; here
 * they combine sounds rather than notes:
 *
 *     after [ voice A4 0.1; voice E5 0.2 ]        A4 then E5
 *     together [ voice C4 1; voice E4 1; voice G4 1 ]    a C major chord
 *
 *         together                  a sound's duration is a voice's own;
 *        /    |    \                for together, the longest; for after,
 *      C4    E4    G4               the sum
 *
 * Rendering: each voice is rendered by its source, then multiplied by
 * its volume and by its envelope. The source is one of these:
 * - its oscillator (Oscillator's phase accumulator), the frequency
 *   moving from [frequency] to [slide] over the voice, for a laser's or
 *   a jump's sweep; it is band-limited, unless it is [Naive];
 * - its FM pair (Fm.mli): a fading voice's index follows its envelope,
 *   bright when struck and darker as it dies, Chowning's way;
 * - its noise (Noise's LFSR), stepped [frequency] times a second, which
 *   is its "pitch".
 * The envelope is [fade], a percussive one (an attack of 5 ms, then
 * down to 0 over the rest); otherwise it is ramps of 5 ms in and out,
 * so that even a plain voice never clicks (Envelope.mli). Then Mix.add
 * renders together, Mix.then_ renders after, and a filter (Filter.mli)
 * runs over a sound's samples for [Filtered]: subtractive synthesis,
 * a rich sound with some of it taken away.
 *
 * References: Paul Hudak, Donovan Quick, The Haskell School of Music:
 * From Signals to Symphonies, Cambridge University Press, 2018,
 * chapter 1 (Music values, (:+:) and (:=:)); Euterpea,
 * https://www.euterpea.com *)

(* ix: copied from libs/audio/Synth.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

(*****************************************************************************)
(* {1 Sounds as trees} *)
(*****************************************************************************)

type source =
  | Wave of Oscillator.waveform (* band-limited (Oscillator.mli) *)
  | Naive of Oscillator.waveform (* the formula of the phase, aliasing *)
  | Fm of { ratio : float; index : float } (* the modulator's ratio *)
  | Noise
  (* a plucked string (Pluck.mli): its slide and effects are ignored;
   * when kept playing, it is a triangle (a string cannot be held) *)
  | Pluck

type voice = {
  source : source;
  frequency : float; (* Hz; for noise, the LFSR's steps per second *)
  slide : float option; (* the frequency reached at the end *)
  seconds : float;
  volume : float; (* 0 to 1 *)
  fade : bool; (* percussive: dies away over its duration *)
  effects : Pitch_effect.t list; (* vibrato, jumps, arpeggios, multiplied *)
  (* an ADSR instead of the 5 ms ramps (or [fade]), released at
   * [seconds] minus its release time: sfxr's attack, sustain, decay *)
  envelope : Envelope.t option;
}

type t =
  | Voice of voice
  | Together of t list
  | After of t list
  (* samples already computed, such as a MIDI file's rendering
   * (Music.render_score); the modifiers below leave them untouched *)
  | Samples of Signal.t
  (* the sound through a biquad (Filter.mli), its cutoff moving from
   * [cutoff] to [cutoff_to] over the sound (the same value for a fixed
   * cutoff) *)
  | Filtered of filter * t
  (* the sound echoed ([echo] below), [tail] longer *)
  | Echo of echo * t
  (* the sound in a room ([reverb] below), with its reverberation time
   * in seconds; the sound is that much longer *)
  | Reverb of float * t
  (* the sound panned, from -1 left to 1 right (Space.pan): only
   * [render_stereo] hears it, and [render] mixes it down to one
   * channel *)
  | Panned of float * t
  (* the sound, rendered in stereo, through a live processor, followed
   * by [tail] seconds of silence for what the processor adds (a delay's
   * echoes). This runs a live effect (effects/'s Drive, Modulation,
   * Dynamics, ...) once over a sound rendered ahead. [make] makes a
   * fresh processor for each rendering, because an effect keeps state
   * and a sound is rendered each time it is played. It exists so that
   * playground/'s Audio can offer the live effects to games' sounds
   * without the engine knowing them (effects/ is above it). *)
  | Processed of processed * t

and echo = { delay : float; feedback : float }

and filter = { kind : Filter.kind; cutoff : float; cutoff_to : float; q : float }

and processed = { make : unit -> Signal.stereo -> unit; tail : float }

(* when false, every Wave is played as Naive and the band-limited
 * oscillators are off, for the backends' debug key (the software
 * backend's "l"). This applies to the sounds rendered from then on (a
 * loop already rendered keeps its own samples), and to the continuous
 * voices at once. It is true by default *)
val band_limited : bool ref

(*****************************************************************************)
(* {1 Making them} *)
(*****************************************************************************)

(* [voice source frequency] lasts 0.3 s at volume 0.5, and neither
 * slides nor fades *)
val voice : source -> float -> t

(* the modifiers, which apply to every voice of the tree: *)
val lasting : float -> t -> t
val fading : t -> t
val louder : float -> t -> t (* the volume multiplied *)
val sliding : float -> t -> t (* to that frequency *)
val naive : t -> t (* Wave to Naive *)
val with_effect : Pitch_effect.t -> t -> t (* one more *)

(* [faster k s] plays [s] [k] times as fast: every duration is divided
 * by [k] (the voices', their effects' times, an echo's delay), and the
 * pitches are kept. It sets a tune's tempo (Samples, already computed,
 * are left untouched) *)
val faster : float -> t -> t

(* [pitched k s] multiplies every frequency of [s] by [k] (slides too),
 * and keeps the durations. But a recording, Samples, has no frequency:
 * it is read [k] times as fast (by Resample, with !Resample.kind), so
 * it is higher and shorter, pitch and time changing together. Together
 * with [faster k] (which leaves Samples alone), it makes a Doppler
 * shift, a sound squeezed or stretched as a whole *)
val pitched : float -> t -> t

(*****************************************************************************)
(* {1 Rendering} *)
(*****************************************************************************)

(* [duration s] is in seconds (see above) *)
val duration : t -> float

(* [render s] gives its samples, [duration s] long, in one channel
 * (pans are ignored) *)
val render : t -> Signal.t

(* [render_stereo s] gives the same in two channels. The gains of each
 * [Panned] subtree (Space.pan) are applied, and its far ear is delayed
 * (Space.interaural_delay, so both channels are then that much
 * longer); nested pans are multiplied. A tree with no pan is [render]
 * in both channels (the same array, not copied) *)
val render_stereo : t -> Signal.stereo

(*****************************************************************************)
(* {1 The echo and the reverb, rendered} *)
(*****************************************************************************)

(* The echo is the sound plus itself [delay] seconds later, [feedback]
 * as loud, and that echo echoed again, and so on, each echo being
 * [feedback] times the last:
 *
 *     y[n] = x[n] + feedback y[n - delay rate]
 *
 * This is a feedback comb filter, whose memory is a delay line holding
 * the last [delay] seconds of output (a circular buffer: 13,230 samples
 * for 0.3 s). The echoes die away geometrically, and the output lasts
 * [tail] longer than the input: the time for them to fall below -60 dB
 * (a thousandth, the convention of reverberation time, Wallace
 * Sabine's RT60, 1900).
 *
 * Example: with feedback 0.5 and a delay of 0.25 s, the echoes are at
 * 0.5, 0.25, 0.125...; the tenth (0.001) comes at 2.5 s, which is the
 * tail.
 *
 * A reverb is a room's thousands of echoes, off every wall, too many
 * and too close together to hear one by one: a wash that dies away.
 * Manfred Schroeder (Bell Labs, 1962) made one out of the echo above:
 * four feedback combs in parallel, with delays around 30 to 45 ms that
 * are mutually prime (29.7, 37.1, 41.1, 43.7 ms, so their echoes never
 * line up and they do not ring at one pitch), then two all-pass
 * filters in series (5.0 and 1.7 ms). The all-pass filters multiply
 * the echoes without colouring the sound: an all-pass lets every
 * frequency through at the same level, only later:
 *
 *     y[n] = -g x[n] + x[n - D] + g y[n - D]
 *
 *     in --+--> comb 29.7 ms --+
 *          +--> comb 37.1 ms --+--> / 4 --> all-pass 5 ms --> all-pass 1.7 ms --> wet
 *          +--> comb 41.1 ms --+
 *          +--> comb 43.7 ms --+
 *
 * Each comb's feedback is set from the reverberation time asked for, T
 * (60 dB down after T seconds): a comb of delay D loses 60 dB in T when
 * its feedback is 10^(-3 D / T). A bathroom is about 0.5 s, a hall 2,
 * and a cathedral 5 or more. It sounds metallic next to a modern reverb
 * (the combs' echoes are regular; Freeverb, 2000, uses eight combs, and
 * a convolution with a real room's recorded echo is exact): that is an
 * exercise.
 *
 * References: Julius O. Smith III, Physical Audio Signal Processing,
 * 2010, "Feedback Comb Filters" and "Schroeder Reverberators",
 * https://ccrma.stanford.edu/~jos/pasp/; Manfred R. Schroeder, "Natural
 * Sounding Artificial Reverberation", Journal of the Audio Engineering
 * Society 10(3), 1962. *)

(* [tail ~delay ~feedback] is how much longer the echo makes a sound:
 * the delay times the number of echoes it takes to fall below 0.001
 * (2.5 s for 0.25 and 0.5). [feedback] is in [0, 1) *)
val tail : delay:float -> feedback:float -> float

(* [echo ~delay ~feedback s] is [s] echoed, [tail] longer *)
val echo : delay:float -> feedback:float -> Signal.t -> Signal.t

(* [reverb ~seconds ~mix s] is [s] plus [mix] (0.3 is the usual) of
 * Schroeder's reverb, with [seconds] as its reverberation time; the
 * sound is that much longer *)
val reverb : seconds:float -> mix:float -> Signal.t -> Signal.t

(*****************************************************************************)
(* {1 A sound in pieces (ix's own)} *)
(*****************************************************************************)
(* A tune rendered whole is millions of samples computed before the
 * first one is heard (Tetris's theme takes 7 seconds on a Pi 1). Each
 * of its notes is a small sound at a known place in it. When the notes
 * are rendered as the player comes to them, the cost is spread over
 * the tune. *)

(* [length s] is the number of samples [render s] gives, when that is
 * known without rendering: for voices and recordings, one after
 * another or together. It is not known for what a filter, an echo, a
 * reverb, a pan or a processor is over. *)
val length : t -> int option

(* [pieces s], for an [s] of a known length, gives its voices and
 * recordings, each with the sample it starts at and its length, in
 * the order they are written; rests (voices of no volume) are left
 * out. The sum of each piece's [render] at its place is [render s]. *)
val pieces : t -> (int * int * t) list
(* ix's own: a voice's samples one at a time. It gives their number,
 * and the function that gives the i-th one, which must be asked in
 * order from 0 (the oscillator's state is in it). [render] of the
 * voice is all of them *)
val voice_steps : voice -> int * (int -> float)

(*****************************************************************************)
(* {1 Continuous voices, frame after frame} *)
(*****************************************************************************)

(* a continuous voice's state, frame after frame: its oscillator's
 * phase (or its noise's register and clock), its last volume, and its
 * time (for its pitch effects, so that a vibrato goes on from frame to
 * frame) *)
type running

val start : unit -> running

(* [continue running v n] gives the next [n] samples of [v] as a steady
 * sound (its duration, slide, fade and envelope are ignored), and the
 * state for the next call. Its phase goes on from the last call, and
 * its volume moves smoothly from the last call's to [v]'s (so there is
 * no zipper noise when a theremin's volume changes) *)
val continue : running -> voice -> int -> Signal.t * running

(* [continue_into running v out n] writes continue's samples in the
 * first [n] of [out] (the mixer's way: no array of pointers is made),
 * and gives the state for the next call *)
val continue_into : running -> voice -> Float.Array.t -> int -> running

(* [release running n] gives [n] samples of the voice fading from its
 * last volume to 0, when it stops *)
val release : running -> voice -> int -> Signal.t
