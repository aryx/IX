(* Notes and music (see notes_audio.md section 9): the notes'
 * frequencies, and tunes (Abc.mli) played by a small band of NES-like
 * instruments, and MIDI scores (Midi.mli).
 *
 * Western music uses twelve-tone equal temperament: an octave doubles
 * the frequency, and is split into 12 semitones, each of which
 * multiplies it by the same ratio, 2^(1/12) = 1.0595. The reference is
 * A4 = 440 Hz (the A above middle C, ISO 16, 1975). A note n
 * semitones from A4 is at 440 * 2^(n/12):
 *
 *     C4 (middle C)  -9 semitones   261.63 Hz
 *     A4              0             440
 *     E5             +7             659.26     (a fifth above: nearly 3/2)
 *     A5            +12             880        (an octave: exactly 2)
 *
 * MIDI numbers the same notes from 0, with A4 at 69 and middle C at 60
 * (notes_audio_midi.md): frequency = 440 * 2^((n - 69) / 12).
 *
 * References: Marin Mersenne, Harmonie universelle, 1636 (the ratio
 * 2^(1/12)); the MIDI 1.0 specification, 1983; Paul Hudak and Donovan
 * Quick, The Haskell School of Music, 2018, chapter 2 (pitches as
 * numbers, "absPitch"). *)

(* ix: copied from libs/audio/Music.mli
 * in the author's playground (docs/plans/plan_audio.md). Playing a
 * score a block at a time (play_score, fill_score) is ix's own. *)

(* [midi_frequency n] is MIDI note [n]'s frequency: 440 for 69 *)
val midi_frequency : int -> float

(* [midi_number name] gives "A4" -> 69, "C4" -> 60, "F#5" -> 78, "Bb3"
 * -> 58. A name is a letter, an optional # or b, and an octave from -1
 * to 9. It is None if [name] is not a note *)
val midi_number : string -> int option

(* [frequency name] gives "A4" -> 440.; it is 0. if [name] is not a
 * note *)
val frequency : string -> float

(*****************************************************************************)
(* {1 Playing tunes} *)
(*****************************************************************************)
(* A tune's voices are played by the NES's band (the 2A03 chip, 1983,
 * which has two square channels and a triangle). The first voice (the
 * melody) is played on a square, the last one (the bass) on the
 * triangle, and those in between on a softer square. Each note sounds
 * for 90% of its length, followed by a short silence, so that two
 * notes in a row are heard as two (a tracker's "note off"). Rests are
 * silences. *)

(* [instrument ~voice ~voices] is the sound of voice number [voice]
 * (counting from 0) among [voices]: its waveform and its volume *)
val instrument : voice:int -> voices:int -> Oscillator.waveform * float

(* [to_sound tune] plays its voices together, each voice being its
 * notes' sounds one after another *)
val to_sound : Abc.tune -> Synth.t

(*****************************************************************************)
(* {1 Playing MIDI scores} *)
(*****************************************************************************)
(* A MIDI file's notes overlap freely (a chord, a sustained bass under a
 * melody), which a tune's voices, whose notes come one after another,
 * cannot hold. So a score is rendered straight into one buffer, each
 * note added at its start. General MIDI's instrument families (the
 * program / 8, 1991) are mapped to our few waveforms, in the NES's
 * manner:
 *
 *   pianos, chromatic percussion (0-15)   square, fading
 *   organs (16-23)                        square, held
 *   guitars (24-31)                       sawtooth, fading
 *   basses (32-39)                        triangle
 *   strings, ensembles (40-55)            sawtooth, softer
 *   brass (56-63)                         sawtooth
 *   reeds, pipes (64-79)                  square
 *   synth leads (80-87)                   square
 *   synth pads (88-95)                    triangle
 *   the rest                              square
 *
 * Channel 10 (9 counting from 0) is the drums, played by key: 35-36 is
 * a bass drum (a triangle falling from 150 to 50 Hz), 38 and 40 a snare
 * (noise), 42, 44 and 46 hi-hats (short, bright noise), and the others a
 * short noise. The velocity is the volume (127 gives 0.25, so that
 * chords do not clip). *)

(* [render_score score] gives its samples *)
val render_score : Midi.score -> Signal.t

(* A score played a block at a time, for a player. [render_score] has a
 * whole song's samples before the first one is heard (a quarter of an
 * hour of music is 40 million floats). Here a note is rendered when its
 * time comes, added to the blocks it sounds in, and then dropped. The
 * samples are the same as [render_score]'s. *)
type playing

val play_score : Midi.score -> playing

(* [fill_score p out] writes the next samples, [out]'s length of them;
 * past the end, it is silence *)
val fill_score : playing -> Signal.t -> unit

val score_finished : playing -> bool
