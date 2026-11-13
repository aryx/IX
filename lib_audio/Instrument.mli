(* An instrument: a sound played live, whose notes and knob changes
 * arrive while it sounds (see notes_synth.md section 1).
 *
 * The rest of audio/ renders ahead: a sound is a value (Synth.t), and
 * its samples are computed whole when it is played. A synthesizer
 * cannot work that way: when a key goes down, nobody knows yet when it
 * will come up, and someone may turn the filter's knob in between. So
 * an instrument is a *process*: a state, which events change, and
 * which is asked for the next block of samples.
 *
 *     update, 60 a second            the sound card, 44,100 a second
 *
 *     note_on 60 ----.
 *     set "volume" --+--> [ state ] --fill--> the next n samples --> Mixer
 *     note_off 60 ---'       ^  |                  (a pull: 735 a frame)
 *                            '--'
 *                     kept from block to block
 *
 * Every live block of plan_synth_teaching.md (the oscillators, the
 * ladder, the envelopes, the effects) follows the same pattern. It is
 * shown here on the smallest instrument there is, [sine]:
 *
 *  - its parameters and its memory are in one record of mutable
 *    fields, hidden behind the .mli: the oscillator's phase, the gate's
 *    level, the knobs. They are mutable because the DSP books write
 *    them that way and a sound card pulls them that way: a block is
 *    computed in place, nothing is allocated for each sample, and the
 *    state is the process's own business;
 *  - an event (a key, a knob) changes the state *between* blocks, and
 *    is heard from the next block on, so an event's time is a block's
 *    boundary. With a pull for each frame (a golden run, -dump-frame), a
 *    note played at frame k starts at sample 735 k. Natively, about
 *    50 ms of queue also lie ahead of it: that is the latency between
 *    Audio.mli's two clocks;
 *  - [fill] computes a block, and a knob's new value is *ramped* over
 *    the block rather than jumped to. A volume that goes from 0.2 to
 *    0.8 at once makes a step in the wave, which is heard as a click. A
 *    knob turned slowly makes a step every block, so a click 60 times a
 *    second: the "zipper noise" of the first digital synthesizers.
 *
 * A worked example of the ramp: the volume is turned from 0.2 to 0.8,
 * over a block of 735 samples. Sample i (counting from 0) gets
 *
 *     0.2 + 0.6 (i + 1) / 735          0.20082, 0.20163, ..., 0.8
 *
 * so that neighbours are 0.6 / 735 = 0.00082 apart, instead of one
 * step of 0.6. The gate is ramped the same way, over 5 ms (220.5
 * samples): when a key is pressed it goes from 0 to 1 in 221 samples,
 * and when the key is released it goes back to 0. So a note never
 * starts or stops on a jump.
 *
 * [t] is a record of functions (an object in all but name), because
 * the mixer holds instruments of different kinds (this sine, the
 * Minimoog) and wants the same four things from each. The state stays
 * inside, in the closures.
 *
 * References: Will Pirkle, Designing Software Synthesizer Plug-Ins in
 * C++, 2014 (chapter 2: the plug-in's process of blocks, and the
 * smoothing of parameters); Steinberg's VST 2 SDK, 1999, whose
 * processReplacing (a block of samples in, a block out, in place) has
 * the shape that every plug-in API has had since. *)

(* ix: copied from libs/audio/Instrument.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type t = {
  (* a key goes down: its number (MIDI's: 60 is middle C, and 69 is the
   * A at 440 Hz, see Music.midi_frequency), and its velocity, from 0 to
   * 1 *)
  note_on : int -> float -> unit;
  (* the key comes up *)
  note_off : int -> unit;
  (* a knob is turned to a value, by its name; the names that the
   * instrument does not have are ignored *)
  set : string -> float -> unit;
  (* computes the next block: both channels are written over, and their
   * length is the block's *)
  fill : Signal.stereo -> unit;
}

(* [sine ()] is one sine wave. It plays the last key pressed until that
 * key is let go: another key's release is ignored, and a key pressed
 * while one sounds changes the pitch at once, the wave going on
 * (legato). The key's velocity is the loudness, and the gate is ramped
 * over 5 ms. It has one knob, "volume", from 0 to 1, which is 0.5 at
 * first. *)
val sine : unit -> t

(* the gate's ramp, in samples: 5 ms *)
val gate_samples : float
