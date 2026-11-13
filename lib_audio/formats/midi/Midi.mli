(* MIDI files: music as messages with their times (see
 * notes_audio_midi.md for the whole story).
 *
 * MIDI (1983) does not carry sound, only what a player does: "key 60
 * pressed, this hard", "released", "switch to the trumpet". A message
 * is a status byte (with its high bit 1: it says what, and on which of
 * 16 channels) and one or two data bytes (with their high bit 0, from 0
 * to 127):
 *
 *   9n kk vv    note on, channel n, key kk (60: middle C), velocity vv
 *   8n kk vv    note off (and a note on with velocity 0 is one too)
 *   Cn pp       program change: the instrument (General MIDI's list)
 *
 * Running status: several messages in a row with the same status send
 * it once, so 90 3C 64 40 64 43 64 is three notes on, C E G, a chord,
 * in 7 bytes instead of 9.
 *
 * A Standard MIDI File (1988) stores the messages with their times. It
 * is made of chunks (a 4-letter tag, then a 32-bit big-endian length):
 * an MThd header (the format, the tracks, and the division, in ticks
 * per quarter note), then MTrk tracks. In a track, each event comes
 * after a delta time in ticks, written as a variable-length quantity:
 * 7 bits a byte, with the high bit set on every byte but the last:
 *
 *        0 -> 00     127 -> 7F     128 -> 81 00     200 -> 81 48
 *      480 -> 83 60      16383 -> FF 7F       16384 -> 81 80 00
 *
 * Ticks become seconds through the tempo, a meta event (FF 51 03) in
 * microseconds per quarter note. At 480 ticks per quarter and 500,000
 * microseconds (120 beats a minute), a tick is 1.042 ms, and there are
 * 960 ticks a second. The tempo can change in the middle of a song, so
 * the conversion walks the tempo map, each stretch at its own tempo.
 *
 * MIDI's cousins, the trackers' module files (MOD, S3M, XM, IT, from
 * the Amiga and the demoscene), carry their instruments' samples
 * inside, where MIDI carries only what to play: see
 * notes_audio_midi.md section 9 (they are not read here).
 *
 * References: the MIDI 1.0 Detailed Specification, and the Standard
 * MIDI Files 1.0 specification (the MIDI Manufacturers Association,
 * 1983 and 1988), https://midi.org/specifications ; General MIDI 1
 * (1991); notes_audio_midi.md. *)

(* ix: copied from libs/audio/formats/midi/Midi.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

(* a note of a score: when it starts and how long it lasts (in
 * seconds), its key (a MIDI number), its velocity (0-127), its channel
 * (0-15, 9 for drums), and the program (the instrument, 0-127) at that
 * time *)
type note = { start : float; length : float; key : int; velocity : int; channel : int; program : int }

type score = { notes : note list; (* by start time *) duration : float }

(*****************************************************************************)
(* {1 Variable-length quantities} *)
(*****************************************************************************)

(* [vlq n] gives the bytes of [n] (see the table above) *)
val vlq : int -> string

(* [read_vlq s i] gives the number at [i], and the position after it *)
val read_vlq : string -> int -> int * int

(*****************************************************************************)
(* {1 Files} *)
(*****************************************************************************)

(* [parse bytes] gives a Standard MIDI File's notes (formats 0 and 1,
 * with every track's notes merged), or the reason why it cannot *)
val parse : string -> (score, string) result

(* [of_tune ~program tune] writes a Standard MIDI File (format 1, 480
 * ticks a quarter, 120 beats a minute, a track for each voice, each on
 * its own channel) that plays an Abc.tune with the instrument
 * [program] (80, a square lead, is the usual). It turns ABC (or
 * solfège) into MIDI *)
val of_tune : program:int -> Abc.tune -> string
