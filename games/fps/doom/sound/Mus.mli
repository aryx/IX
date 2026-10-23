(* Mus: Doom's music format made a Standard MIDI File, which
 * lib_playground's Audio.midi plays (the ports' mus2mid, i_sound.c's
 * job of DMX's in id's DOS game).
 *
 * id's WADs keep a level's music (D_E1M1) as MUS: Paul Radek's DMX
 * sound library's own, a MIDI made smaller for the cards of 1993. Its
 * events are MIDI's, fewer and packed, at 140 tics a second:
 *
 *   a byte: last (1 bit) | the event (3) | the channel (4)
 *     0 a note let go       its note
 *     1 a note played       its note (bit 7: a volume follows)
 *     2 the pitch wheel     0 to 255 (128 in the middle)
 *     3 a system event      all off, mono, poly, reset
 *     4 a controller        which (0 the instrument, 3 the volume, 4
 *                           the pan ...), its value
 *     6 the end
 *   last: the delay to the next event follows, 7 bits a byte, the
 *   high bit saying more
 *
 * MUS's channel 15 is the drums, MIDI's 9; the others take MIDI's in
 * the order they are first heard. The file made: one track, 70 tics a
 * beat at 120 beats a minute (140 a second, MUS's).
 *
 * Freedoom keeps its music as MIDI already (a WAD may hold either:
 * Doom's ports read both); [to_midi] gives a MIDI file as it is.
 *
 * Where it stands in mini-doom: Sound plays a level's music through
 * it. *)

(* [to_midi lump]: the MIDI file of a music lump (MUS, or MIDI already) *)
val to_midi : string -> string
