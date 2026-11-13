(* MOD: a song that carries its own instruments (see
 * notes_audio_formats.md section 1).
 *
 * Karsten Obarski's Ultimate Soundtracker (Amiga, 1987) wrote the first
 * modules, and was the tracker to make them. A module holds short
 * recordings (samples) and the notes that play them in one file, so
 * the song sounds the same everywhere, unlike a MIDI file, which
 * leaves the sound to whatever reads it. NoiseTracker and ProTracker
 * (1989-90) made the form that everyone used, big-endian like the
 * Amiga's 68000:
 *
 *   offset  size
 *        0    20   the title
 *       20  30x31  the instruments: name (22), length in words (2),
 *                  finetune (1), volume 0-64 (1), loop start in words
 *                  (2), loop length in words (2; 1: no loop)
 *      950     1   the song's length: the positions that play
 *      951     1   (restart: kept, not used)
 *      952   128   the order list: a pattern for each position
 *     1080     4   "M.K." -- 1084 bytes of header
 *     1084  1024x  the patterns: 64 rows x 4 channels x 4-byte cells
 *                  (as many as the order list's highest number + 1)
 *                  then the samples, 8-bit signed, one after the other
 *
 * The tag says how many channels there are: "M.K.", "M!K!", "FLT4" and
 * "4CHN" mean four, "6CHN" and "8CHN" (FastTracker's) six and eight,
 * and "FLT8" and "OCTA" eight. No tag at all means Ultimate
 * Soundtracker's own form: 15 instruments, a 600-byte header (20 + 15
 * x 30 + 1 + 1 + 128), four channels, and a loop start in bytes rather
 * than words.
 *
 * {1 A cell}
 *
 *     byte 0      byte 1      byte 2      byte 3
 *     iiii pppp   pppp pppp   iiii eeee   xxxx xxxx
 *
 * A cell holds the instrument's high and low nibbles (0: none), a
 * 12-bit period (0: no new note), the effect (0-F) and its parameter.
 * A worked example: instrument 1 at C-2 (period 428 = 0x1AC), with
 * effect C (the volume) at 0x20, is 01 AC 1C 20; instrument 17 (0x11)
 * with the same is 11 AC 1C 20.
 *
 * {1 Periods}
 *
 * A cell has no note. What it has is what the Amiga's Paula chip
 * counts down from, at 3,546,895 Hz (a PAL machine's clock), between
 * two bytes of the sample. So a period is a sample rate, 3,546,895 /
 * period: C-2's 428 is 8,287 Hz. ProTracker's table ([periods]) covers
 * three octaves, from C-1 (856) to B-3 (113), each semitone being the
 * last one divided by 2^(1/12) and rounded. The finetune (-8 to 7
 * eighths of a semitone, a signed nibble) shifts an instrument's
 * periods. What pitch a period *sounds* is the sample's business: a
 * recording of a C played at C-2 sounds a C.
 *
 * References: Ultimate Soundtracker (Karsten Obarski, EAS Computer
 * Technik, 1987); the format as documented with the players that read it
 * (MikMod, libxmp, OpenMPT's wiki); ProTracker's period table. *)

(* ix: copied from libs/audio/formats/mod/Mod.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(*****************************************************************************)
(* {1 The song} *)
(*****************************************************************************)

type instrument = {
  name : string; (* up to 22 characters *)
  finetune : int; (* -8 to 7 *)
  volume : int; (* 0 to 64 *)
  loop_start : int; (* in bytes *)
  loop_length : int; (* in bytes; 0: no loop *)
  data : string; (* the sample, 8-bit signed, as in the file *)
}

type cell = {
  instrument : int; (* 1 to 31; 0: none *)
  period : int; (* 0: no new note *)
  fx : int; (* the effect, 0 to 15 (fx, effect being a keyword since OCaml 5.3) *)
  param : int; (* 0 to 255 *)
}

type song = {
  title : string;
  instruments : instrument array; (* 31, or 15 for Ultimate Soundtracker's *)
  restart : int;
  positions : int array; (* the played part of the order list: a pattern each *)
  patterns : cell array array array; (* pattern, row (64), channel *)
  tag : string; (* "M.K.", ...; "" for Ultimate Soundtracker's *)
}

(* the number of channels a tag says: 4 for "M.K.", 8 for "8CHN"...;
 * None if it is not a tag *)
val channels_of_tag : string -> int option
val channels : song -> int

(* [of_string bytes] gives a module, or the reason why it cannot *)
val of_string : string -> (song, string) result

(* [to_string song] writes the file: the order list is padded to 128
 * with 0, and there are as many patterns as in [song.patterns] *)
val to_string : song -> string

(* the header's size: 1084 (31 instruments) or 600 (15) *)
val header_size : song -> int

(*****************************************************************************)
(* {1 Cells} *)
(*****************************************************************************)

val empty_cell : cell

(* [cell_of_bytes s i] reads the 4 bytes at [i], and [cell_to_bytes c]
 * writes them back *)
val cell_of_bytes : string -> int -> cell
val cell_to_bytes : cell -> string

(*****************************************************************************)
(* {1 Periods and notes} *)
(*****************************************************************************)

(* ProTracker's periods at finetune 0, from C-1 to B-3: 856 ... 428
 * (C-2) ... 113 *)
val periods : int array

(* [note_name period] gives "C-2" or "F#1", the nearest in [periods];
 * "---" for 0 *)
val note_name : int -> string

(* [period_of_name "C-2"] is 428; None if the name is not a note *)
val period_of_name : string -> int option

(* [rate period] is the sample rate Paula plays it at, 3,546,895 /
 * period (8,287.1 Hz for 428) *)
val rate : int -> float

(* the Amiga's clock for Paula, PAL: 3,546,895 Hz *)
val paula_clock : float

(*****************************************************************************)
(* {1 Samples} *)
(*****************************************************************************)

(* [sample i k] is instrument [i]'s byte [k] as a number from -1 to 1 *)
val sample : instrument -> int -> float

(* [data_of_floats a] turns numbers from -1 to 1 into 8-bit signed
 * bytes, an instrument's [data]. They are clamped, and an odd length
 * is padded with a 0, since lengths are in words *)
val data_of_floats : float array -> string
