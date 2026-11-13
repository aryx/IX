(* The VCO, a synthesizer's oscillator, played live (see notes_synth.md
 * section 3).
 *
 * Oscillator.mli has the waveforms, each a formula of the phase, and
 * PolyBLEP. This module is the oscillator of a synthesizer's voice. It
 * runs a block at a time (the pattern of Instrument.mli) and keeps its
 * phase from block to block, and it has what the voice does to it:
 *
 *  - Its frequency is given per *sample*, as a block of frequencies. So
 *    a vibrato (an LFO), a glide or a pitch wheel moves it smoothly
 *    within a block. This is the V in VCO: a voltage controlling the
 *    frequency, continuously.
 *  - The pulse's width is given per sample too. This is pulse-width
 *    modulation: an LFO moves the width, so the recipe of the harmonics
 *    (|sin (pi k width)| in Oscillator.mli) shifts all the time, and one
 *    oscillator sounds like several (the Juno's strings).
 *  - Hard sync: the oscillator is restarted by another oscillator, the
 *    master, at each of the master's periods.
 *
 * {1 Hard sync}
 *
 *     master  /|  /|  /|          the slave is restarted at each of the
 *            / | / | / |          master's periods: the master sets the
 *     slave /|/|/|/|/|/|/         pitch, and the slave's frequency now
 *           ^   ^   ^             sets the *shape* (how many of its
 *           restarts              periods fit, and where the last is cut)
 *
 * Sweeping the slave's frequency then sweeps the harmonics like a vowel,
 * while the pitch stays put. This is the Prophet-5's sync lead (1978).
 *
 * The restart is a jump of height h = (the wave at 0) - (the wave where
 * the slave was), and it falls *between* two samples: the master's phase
 * reaches 1 at a fraction of the step from one sample to the next. The
 * BLEP (Oscillator.mli) corrects a jump over the sample before and the
 * sample after. Placed at the right fraction, with d the time from the
 * jump to the next sample (in samples, 0 to 1), the corrections are:
 *
 *     the sample before:  + h/2 d^2
 *     the sample after:   + h/2 (2d - d^2 - 1)
 *
 * (These are PolyBLEP's two halves for a jump of 2, at u = d - 1 and
 * u = d, scaled by h/2.) The sample before is computed knowing that the
 * jump is coming, because the master says, at each sample, whether and
 * where it wraps before the next one. The slave's own jump at its phase
 * 0 is then not the jump that happened, so its own correction is left
 * out there.
 *
 * Measured (the playground's Unit_vco): for a sawtooth synced to a 1001 Hz
 * master, at 2.37 times the master's frequency, the loudest alias below 5 kHz
 * goes from -29.5 dB (naive) to -69.9 dB (corrected). Corrected as if the
 * restart fell on the next sample, it is -30.7, hardly better than
 * naive. The restarts land anywhere between samples, and a jump moved to
 * a sample is a jump at the wrong time, which is itself an alias. The
 * fraction is the point.
 *
 * References: Eli Brandt, "Hard Sync Without Aliasing", ICMC 2001;
 * Vesa Välimäki, Antti Huovilainen, "Oscillator and Filter Algorithms
 * for Virtual Analog Synthesis", Computer Music Journal 30(2), 2006. *)

(* ix: copied from libs/audio/instruments/Vco.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

type shape = Sine | Triangle | Sawtooth | Pulse

val shapes : shape list
val name : shape -> string

type t

(* creates an oscillator at phase 0 *)
val create : unit -> t

(* [fill ~band_limited ~width ~sync t shape ~frequency out] fills [out]
 * with the next [Array.length out] samples of [t]. [frequency] (in Hz)
 * and [width] (a pulse's width, 0.5 when None, which is the square;
 * kept within 0.01 and 0.99) are given one per sample. [t] is restarted
 * by [sync], which must have been filled for the same block just
 * before. The samples are band-limited unless [band_limited] is false
 * (true is the usual). *)
val fill :
  band_limited:bool -> width:Float.Array.t option -> sync:t option -> t ->
  shape -> frequency:Float.Array.t -> Float.Array.t -> unit

(* [fill_sync_at_sample] is the same, but it corrects the jumps of the
 * restarts as if they fell on the sample (for the comparison in the
 * playground's Unit_vco) *)
val fill_sync_at_sample :
  width:Float.Array.t option -> sync:t -> t -> shape ->
  frequency:Float.Array.t -> Float.Array.t -> unit
