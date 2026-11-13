(* Tunes in solfège: do ré mi fa sol la si, the note names sung in
 * France, Italy, Spain and Latin America (see notes_audio.md section 9;
 * Abc.mli has the letters C D E F G A B of the English-speaking and
 * German world). They are parsed into the same Abc.tune, so they are
 * played the same way (Music.to_sound).
 *
 * The names are a thousand years old. Guido d'Arezzo (around 1025)
 * taught singers with the hymn Ut queant laxis, whose lines each start
 * one note higher, on the syllables ut re mi fa sol la. si came later,
 * from the hymn's last line, Sancte Iohannes. ut became do in 17th
 * century Italy (after Giovanni Battista Doni, the story goes), because
 * do is easier to sing. Here the do is fixed: do is always C (C4,
 * middle C, in octave 4), as in France and Italy. The
 * English-speaking "movable do" of music classes (The Sound of Music's
 * "Do-Re-Mi") calls do the first note of whatever key the song is in.
 *
 * The notation is words separated by spaces:
 *
 *   do re mi fa sol la si   the notes (ré with its accent too; ut for do)
 *   do# sib                 sharp (dièse) and flat (bémol)
 *   do5 si3                 an octave; it stays for the next notes,
 *                           and is 4 at first
 *   mi:2 re:1/2             a length, in beats (quarter notes); 1 at first
 *   -  -:2                  a rest (a silence)
 *   |                       a bar line (ignored: it is for the eye)
 *   tempo 120               beats a minute; 120 at first
 *   voix, voice             a new voice, played together with the others
 *   % a comment             to the end of the line
 *
 * Example: "tempo 120  do re mi:2 | do5 si4:1/2" is C4 for 0.5 s, D4 for
 * 0.5 s, E4 for 1 s, C5 for 0.5 s and B4 for 0.25 s. Au clair de la
 * lune (French, traditional, 18th century) is:
 *
 *   do do do re mi:2 re:2 | do mi re re do:4
 *
 * References: Guido d'Arezzo, Epistola de ignoto cantu, around 1030;
 * https://en.wikipedia.org/wiki/Solf%C3%A8ge *)

(* ix: copied from libs/audio/formats/abc/Doremi.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* [parse text] gives the tune, or the reason why it cannot *)
val parse : string -> (Abc.tune, string) result
