(* The step sequencer: a pattern played in the audio clock (see
 * notes_synth.md section 1; plan_synth_teaching.md, TinyTB303, B1).
 *
 * An instrument hears its keys between blocks (Instrument.mli), so at a
 * frame's granularity, 16.7 ms. That is fine for a finger, whose own
 * timing is no better. But a sequencer is not a finger. A 16th note at
 * 120 BPM lasts 5512.5 samples, and on the frame clock its steps would
 * land on multiples of 735: the second step at 5880 instead of 5512.5,
 * 8.3 ms late, and the next ones early or late by different amounts.
 * The groove goes wrong, and the ear catches it. So the sequencer runs
 * inside the voice, in the samples it computes. When it is asked for
 * the next block, it says at which sample of the block each event
 * falls, and the voice renders the block in pieces between them.
 *
 *     steps (16ths)   |  C    |  C    |  rest |  Eb   |
 *     gate            |##     |#######|       |##     |    half a step,
 *                          ^ slide: the gate held,          or held into
 *                            the next note glides in        a slide
 *
 * A step is a note or a rest, and a note may be *accented* (the voice
 * plays it louder and brighter) or may *slide* into the next one. In a
 * slide the gate is held open through the next note, which the voice
 * glides to instead of starting it again. These are the TB-303's two
 * gestures, and the whole of acid's phrasing. A note's gate is open for
 * half its step, unless it slides into a note. (Half a step is what is
 * commonly quoted for the 303; ours is still to be checked.)
 *
 * An event falls at the first sample at or after its exact time (step k
 * is at k x 60 / (bpm x 4) seconds), counted from the start and never
 * rounded to a block's edge. So the samples are the same whatever the
 * size of the blocks.
 *
 * A step may also carry *parameter locks*: a knob's value stored in the
 * step, so that a pattern is a sequence of sounds and not only of
 * notes. This is Elektron's idea (the Machinedrum, 2001), and the whole
 * way of playing their machines. What a lock means between the steps is
 * a choice, and two machines made the two choices:
 *
 *     cutoff locked at 0.2 on step 1, 0.8 on step 9 (of 16):
 *
 *     step            1   3   5   7   9   11  13  15  1
 *     Per_step        .2  -   -   -   .8  -   -   -   .2    - : the knob's own
 *     Points 0        .2  .2  .2  .2  .8  .8  .8  .8  .2    held till the next
 *     Points 1        .2  .35 .5  .65 .8  .65 .5  .35 .2    a line to the next
 *
 * In Elektron's choice (Per_step), the lock belongs to its step only,
 * and the knob's own value comes back after it. In the OP-XY's (Teenage
 * Engineering, 2024; Points with its smoothing), "lock points are
 * treated as vectors". A lock is a point the value goes through, and
 * the value is held until the next lock (smoothing 0) or glides to it
 * (smoothing 1 glides the whole way, 0.5 the last half of the way),
 * going round from the pattern's end to its first lock. A parameter with
 * no lock anywhere has the knob's own value. To get Elektron's behaviour
 * on the OP-XY, you lock the knob's own value on the steps after. This
 * says what each choice makes easy: a single accent of sound, or
 * automation.
 *
 * Worked example (the playground's Unit_sequencer): at 120 BPM a step is 5512.5
 * samples. The first four steps begin at samples 0, 5513, 11025 and 16538, and
 * their gates close at 2757, 8269, 13782 and 19294, whether the blocks
 * are 735 samples (a frame's), 500 or 1. The locks of the figure, read
 * as steps 1, 5, 7 and 15 begin, are:
 * - Per_step: 0.2, none, none, none;
 * - Points 0: 0.2, 0.2, 0.2, 0.8;
 * - Points 1: 0.2, 0.5, 0.65, 0.35;
 * - Points 0.5: 0.2, 0.2, 0.5, 0.5. *)

(* ix: copied from libs/audio/instruments/Sequencer.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

(* a step: [note] is a MIDI note, or None for a rest; [locks] are the
 * values of its knobs, by name *)
type step = { note : int option; accent : bool; slide : bool; locks : (string * float) list }

(* a rest; a note, which may be accented or sliding *)
val rest : step
val note : accent:bool -> slide:bool -> int -> step

(* [lock s name v] is the step with [name] locked to [v] (replacing its
 * lock if it had one), and [unlock s] is the step with no locks *)
val lock : step -> string -> float -> step
val unlock : step -> step

type event =
  (* a note begins; with [glide], the gate stays open and the voice
   * glides to it from the note sounding (the step before slid into
   * it) *)
  | Note_on of { note : int; accent : bool; glide : bool }
  | Note_off

type t

val create : bpm:float -> step array -> t

(* change the pattern, and turn the tempo; both are heard from the next
 * step *)
val set_pattern : t -> step array -> unit
val set_bpm : t -> float -> unit

(* [start t] plays from the pattern's first step, at the next sample;
 * after [stop t] there are no more events (the voice lets its note
 * go) *)
val start : t -> unit
val stop : t -> unit
val running : t -> bool

(* the step sounding (for a panel to light), counted from 0 *)
val step : t -> int

(* [samples_per_step bpm] is 60 / (bpm x 4) seconds, in samples *)
val samples_per_step : float -> float

(* [advance t n f] advances over the next [n] samples, calling
 * [f offset event] for each event falling in them, in order, where
 * [offset] counts from the block's first sample *)
val advance : t -> int -> (int -> event -> unit) -> unit

(*****************************************************************************)
(* {1 Parameter locks} *)
(*****************************************************************************)

(* what a lock means between steps: it belongs to its step only
 * (Elektron's choice), or it is a point the value goes through, with a
 * smoothing from 0 to 1 (the OP-XY's) *)
type locks = Per_step | Points of float

(* [lock_value locks pattern name position] is the value of [name] at
 * [position], in steps from the pattern's start (fractional, and
 * wrapping round). It is None where the knob's own value holds. *)
val lock_value : locks -> step array -> string -> float -> float option

(* [position t offset] is where the pattern is, in steps, [offset]
 * samples into the block last advanced. It is None before the first
 * step, or when the sequencer is stopped. *)
val position : t -> int -> float option

(* [locked t locks name offset] is [lock_value] at [position] *)
val locked : t -> locks -> string -> int -> float option
