(* This module is where a platform finds a program's sound (it is ix's
 * own; docs/plans/plan_audio.md, stage 4). In the playground a
 * platform calls Audio.pull, so every program is linked with the
 * synthesizer. Here most programs make no sound (an editor, a
 * spreadsheet), and a platform must not ask for lib_audio. So Audio
 * says here that it is linked, and a platform looks here:
 *
 *     a game ---> Audio (apis/) ---> lib_audio: the mixer
 *                   | at its start: source := Some ...
 *                   v
 *               Audio_source  <--- a platform, after each frame,
 *                                  takes the next n samples if there
 *                                  is a source, and sends them to
 *                                  SDL's queue, to /dev/audio, or to
 *                                  a WAV file
 *
 * Samples are floats from -1 to 1, 44,100 a second, for the left ear
 * and for the right one. *)

type t = {
  (* the next [n] samples, for the left ear and for the right one *)
  pull : int -> float array * float array;
  (* how late the program's sounds are heard, in seconds, as the
   * platform measures it (Audio.latency) *)
  latency : float -> unit;
}

(* none until Audio is linked *)
val source : t option ref

(* [s16 (left, right)] gives the samples as a sound card and
 * /dev/audio take them: 16 bits signed, the low byte first, left then
 * right. A sample past -1 or 1 is cut there. *)
val s16 : float array * float array -> string

(* [wav samples] makes a WAV file of them (16 bits, two channels,
 * 44,100 a second) *)
val wav : string -> string

(* how many samples a frame is (a sixtieth of a second: 735), and how
 * many a platform keeps queued ahead of the sound card (three frames,
 * as in the playground's Native_loop_2d) *)
val frame_samples : int
val queue_ahead : int
