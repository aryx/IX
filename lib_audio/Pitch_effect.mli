(* Pitch effects: a voice's pitch changed over time, wobbling or
 * jumping (see notes_audio.md section 8).
 *
 * They multiply a voice's frequency by a factor that changes with time
 * t, the seconds since the voice started:
 *
 *   - a vibrato makes the pitch wobble up and down, [depth] semitones
 *     either way, [rate] times a second: 2^(depth sin (2 pi rate t) /
 *     12). A singer's or a violinist's vibrato is 5 to 7 a second, and
 *     a quarter of a semitone deep; faster and deeper, it is a siren or
 *     a UFO.
 *   - a jump moves the pitch [semitones] up (or down) once, at [at]
 *     seconds: it makes a coin's two notes in one sound (sfxr's
 *     "change").
 *   - an arpeggio plays the notes of a chord one after the other,
 *     [step] seconds each, around and around:
 *
 *         semitones  0  4  7  0  4  7  0 ...     C E G C E G: a C major
 *         pitch      ___                          chord, played by a
 *                       ___                       single voice
 *                          ___
 *
 *     It is the chiptune trick. The NES had two square channels and the
 *     C64 three voices, too few to play chords; when the notes are
 *     cycled every frame (1/60 s), they blur into one warbling chord.
 *     (Arpeggio machines do the same, and so does the trackers' "0xy"
 *     effect: the note, then x semitones up, then y up, one every
 *     tick.)
 *
 * The echo and the reverb, the other effects of a rendered sound, are
 * in Synth. The live effects, through which a sound goes block after
 * block, are in audio/effects/.
 *
 * Reference: Tomas Pettersson, sfxr, 2007 (vibrato and "change" are
 * among its parameters). *)

(* ix: copied from libs/audio/Pitch_effect.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type t =
  | Vibrato of { rate : float; depth : float } (* Hz, semitones *)
  | Jump of { semitones : float; at : float } (* at, in seconds *)
  | Arpeggio of { semitones : float list; step : float } (* each [step] s *)

(* [factor p t] is the frequency's multiplier at [t] seconds in: 1 for
 * no change, 2 for an octave up *)
val factor : t -> float -> float

