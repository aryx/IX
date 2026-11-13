(* A MOD player: the song's patterns played on Paula's channels (see
 * notes_audio_formats.md section 1).
 *
 * Time is counted in ticks, each lasting 2.5 / tempo seconds. The
 * tempo is 125 by default, which makes a tick every 20 ms, or 882 of
 * our samples: the PAL screen's 50 Hz, on which the first trackers
 * played. A row lasts [speed] ticks (6 makes a row every 120 ms). At a
 * row's first tick, each channel reads its cell: a new instrument sets
 * the volume, and a new period restarts the sample (at its finetune).
 * Then the effects act, some once on that tick, and most on every
 * other tick of the row:
 *
 *     tick   0      1      2      3      4      5      0 (next row)
 *            cell   slides, vibrato, volume slides, arpeggio's notes...
 *
 * These effects are played:
 * - 0xy, the arpeggio (the note, then +x, then +y semitones, a tick
 *   each);
 * - 1xx and 2xx, the slides (the period goes down or up by xx a tick);
 * - 3xx, the slide to the cell's note;
 * - 4xy, the vibrato (ProTracker's sine table, speed x, depth y);
 * - 5xy and 6xy (3 and 4 going on, with a volume slide);
 * - 9xx, the sample from byte xx x 256;
 * - Axy, the volume slide;
 * - Bxx, the jump to position xx;
 * - Cxx, the volume;
 * - Dxy, the break to row 10x + y of the next position;
 * - Fxx, the speed (under 32) or the tempo;
 * - E1y and E2y (fine slides), EAy and EBy (fine volume slides), and
 *   ECy (the note cut at tick y).
 * The others (the pattern loop E6, the delays ED and EE, the filter
 * E0...) are read and ignored.
 *
 * The four channels are Paula's, panned as on the Amiga: 1 and 4 hard
 * on the left, 2 and 3 hard on the right ([separation] 1). A
 * separation of 0 mixes them all in the middle, and 0.5 halfway, which
 * is what players offer for headphones.
 *
 * A worked example of a row's length: at speed 6 and tempo 125, a row
 * is 6 x 882 = 5,292 samples, or 120 ms; after F03 (speed 3), it is
 * 2,646. F7D (tempo 125) is the default, and FA0 (160) makes a tick
 * 689.06 samples.
 *
 * References: the ProTracker effects as documented with the players
 * (MikMod, libxmp, OpenMPT's wiki); ProTracker's vibrato table. *)

(* ix: copied from libs/audio/formats/mod/Mod_player.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

type t

(* [create ~loop song] starts at the song's start. At its end, it goes
 * back to the first position if [loop] (for a game's music), and is
 * silent otherwise (for a player) *)
val create : loop:bool -> Mod.song -> t

(* [fill p out] writes the next samples, in both channels *)
val fill : t -> Signal.stereo -> unit

(* how to read the samples (Paula.mli); Hold by default *)
val set_reading : t -> Paula.reading -> unit

(* 1 is hard (the Amiga's), 0 is all in the middle *)
val set_separation : t -> float -> unit

(* where it is: the position in the order list, and the row *)
val position : t -> int * int

(* [seek p ~position ~row] plays from there, at its first tick *)
val seek : t -> position:int -> row:int -> unit

(* [set_song p song] plays [song] from now on, from where it is: a
 * tracker's edits are heard as they are made (its instruments' samples
 * are read again) *)
val set_song : t -> Mod.song -> unit

(* the song it plays *)
val song : t -> Mod.song

(* whether the song was played to its end (never, when looping) *)
val finished : t -> bool

(* channel [c]'s period and volume, for tests and a display *)
val channel_period : t -> int -> int
val channel_volume : t -> int -> int

(* the speed and the tempo now *)
val speed : t -> int
val tempo : t -> int

(* the samples a tick lasts at [tempo]: 44,100 x 2.5 / tempo *)
val tick_samples : int -> float
