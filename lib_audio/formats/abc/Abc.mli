(* ABC notation: tunes as text (see notes_audio.md section 9).
 *
 * ABC (Chris Walshaw, 1991) writes music in plain text, the way it is
 * sung: the letters are the notes, a number says how long a note is,
 * and a bar line marks where the bar ends. Folk musicians have typed
 * tens of thousands of tunes in it, and a tune here is a few lines,
 * not a file of numbers:
 *
 *     X:1                   the tune's number (a file can hold many)
 *     T:Frere Jacques       its title
 *     L:1/8                 the unit length: a note is an eighth
 *     Q:1/4=120             the tempo: 120 quarter notes a minute
 *     K:C                   the key: C major, no sharps or flats
 *     C2 D2 E2 C2 | C2 D2 E2 C2 | E2 F2 G4 |
 *
 * The subset read here is:
 *
 * - notes: C D E F G A B from middle C (C4, MIDI 60) up, and c d e f g
 *   a b an octave higher. Each ' goes an octave up and each , an
 *   octave down: C, is C3, and c' is C6;
 * - accidentals, before the note: ^ is sharp, _ flat and = natural (^^
 *   and __ are twice that). They last until the end of the bar, for
 *   that note, as in sheet music;
 * - lengths, after the note, in units of L: C2 is twice as long, C/2
 *   or C/ half as long, and C3/2 one and a half times. z is a rest,
 *   and has a length too;
 * - [CEG] is a chord; (3CDE is a triplet, three notes in the time of
 *   two; C>D is a dotted pair (C longer by half, D half as long), and
 *   C<D the other way round;
 * - the key signature K: (major keys C G D A E B F# C#, F Bb Eb Ab Db
 *   Gb Cb, and their relative minors, Am Em ... Dm Gm ...). K:G makes
 *   every F an F#, unless it is marked =F;
 * - voices, V:1, V:2 ..., each with its own part, are played together
 *   (a melody and a bass). Fields can be inline too: [K:D], [L:1/16],
 *   [V:2];
 * - a percussion voice, "V:4 clef=perc" (ABC 2.1's own marking), has
 *   notes that are drums, not pitches. Each note's MIDI number is read
 *   as a General MIDI drum key, so C,, (36) is the bass drum, D,, (38)
 *   the snare, ^F,, (42) the closed hi-hat and ^A,, (46) the open one,
 *   and Music.to_sound plays them with the drum sounds of its MIDI
 *   player;
 * - skipped: % comments, "Am" chord names, !trill! and +fermata+
 *   decorations, {grace notes}, the ~ . H ... ornaments, ties (the
 *   note is played again), and repeats and endings (a tune loops as a
 *   whole).
 *
 * Example: with L:1/8, Q:1/4=120 and K:G, "F2 =F2 c/2" is an F#4 for
 * 0.5 s (a quarter at 120 a minute), an F4 for 0.5 s, then a C5 for
 * 0.125 s.
 *
 * References: Chris Walshaw, "The abc music standard 2.1", 2011,
 * https://abcnotation.com/wiki/abc:standard:v2.1 ; the tune collections
 * at https://abcnotation.com and https://thesession.org *)

(* ix: copied from libs/audio/formats/abc/Abc.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* one note, or a rest: when it starts and how long it lasts (in
 * seconds), and which notes it plays (MIDI numbers: several for a
 * chord, none for a rest) *)
type event = { start : float; length : float; notes : int list }

type tune = {
  title : string;
  (* each voice's events, in time order *)
  voices : event list list;
  (* for each voice, whether it is percussion (clef=perc) *)
  drums : bool list;
}

(* [parse text] gives the first tune of [text] (up to the next X:), or
 * the reason why it cannot *)
val parse : string -> (tune, string) result

(* when the last voice ends *)
val duration : tune -> float
