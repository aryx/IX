(* Voicing: which of the keys held a voice plays, and how it gets from
 * one note to the next (see notes_synth.md section 5).
 *
 * A monophonic synthesizer (the Minimoog, the TB-303) has one voice and
 * ten fingers to listen to. It keeps the keys held, in the order they
 * were pressed, and a rule, the *priority*, picks the one that sounds:
 *
 *     hold C4, then press E4:     Low: C4   High: E4   Last: E4
 *     let go of E4:               C4 for all three (the only one left)
 *     hold C4 and E4, press D4:   Low: C4   High: E4   Last: D4
 *
 * Low-note priority is the Minimoog's (its keyboard circuit reads the
 * lowest key down). Last-note priority has been the choice of most
 * monosynths since; it is the one that feels natural when playing fast.
 * Keeping all the keys held, not only the last one, is what makes a
 * trill possible: you hold one key and tap another, and each release
 * goes back to the held note.
 *
 * What the voice has to do then is an [event]. A note begins from
 * silence (the envelopes' gate opens), or the note *changes* while the
 * gate stays open, or the last key is let go. Changing the note without
 * reopening the gate is *legato*: the envelopes go on where they are,
 * and the notes make one phrase. With [~retrigger:true] every change
 * reopens the gate (the attack starts again, from the level where it
 * is: see Envelope.mli), so each note is articulated. The Minimoog is
 * legato ("single trigger").
 *
 * {1 Glide}
 *
 * In a glide (portamento), the pitch goes to the new note instead of
 * jumping. It is a one-pole on the pitch in *semitones*, not in hertz:
 *
 *     p += (target - p) c,    c = 1 - e^(-1 / (tau rate))
 *
 * so an octave up and an octave down take the same time, as the ear
 * expects (in hertz, the octave down would cover half as many hertz).
 * The glide knob is the time constant tau: after tau, the pitch is
 * 63.2% of the way (1 - 1/e), and after 5 tau, 99.3%. Worked example:
 * from C4 to C5, 12 semitones, with tau = 0.1 s. After 0.1 s the pitch
 * is at 67.59 (between G4 and G#4, 405.5 Hz), and after 0.5 s it is at
 * 71.92, 8 cents under C5, 520.8 Hz. A glide of 0 jumps. The pitch keeps
 * its value when the keys are let go, so the next note glides from the
 * last one, as on the Minimoog (whose pitch was a voltage held on a
 * capacitor).
 *
 * References: the Minimoog Model D's keyboard (low-note priority,
 * single trigger); Will Pirkle, Designing Software Synthesizer Plug-Ins
 * in C++, 2014, chapter 8 (voice management, portamento). *)

(* ix: copied from libs/audio/instruments/Voicing.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

type priority = Low | High | Last

(* what the voice does after a key: begin the note [n] with its gate
 * opening; change to [n], with the gate staying as it is; close the
 * gate; or do nothing *)
type event = Begin of int | Change of int | End | Nothing

type t

(* [create ~priority ~retrigger ()] starts with no key held; legato is
 * [~retrigger:false] *)
val create : priority:priority -> retrigger:bool -> unit -> t

(* [press t key] and [release t key] put a key (by MIDI's numbers) down
 * and up *)
val press : t -> int -> event
val release : t -> int -> event

(* the key sounding, if any *)
val sounding : t -> int option

(*****************************************************************************)
(* {1 Glide} *)
(*****************************************************************************)

type glide

(* a glide at [note] (a MIDI number) *)
val glide : note:float -> unit -> glide

(* [glide_to g note] makes the pitch move to [note] from now on *)
val glide_to : glide -> int -> unit

(* [fill_frequency g ~seconds out] fills [out] with the next
 * [Array.length out] frequencies, in Hz, as the pitch glides with the
 * time constant [seconds] (0 means at once) *)
val fill_frequency : glide -> seconds:float -> Float.Array.t -> unit

(* [fill_pitch] is the same, with the pitch in semitones (a MIDI
 * number, fractional), for a voice that adds more to it (a wheel, a
 * vibrato) before turning it into hertz *)
val fill_pitch : glide -> seconds:float -> Float.Array.t -> unit

(* the pitch now, in semitones (a MIDI number, fractional) *)
val pitch : glide -> float

(* [frequency pitch] is 440 x 2^((pitch - 69) / 12), for a fractional
 * pitch *)
val frequency : float -> float
