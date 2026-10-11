(* Where a platform finds a program's sound (ix's own;
 * docs/plans/plan_audio.md, stage 4). In the playground a platform
 * calls Audio.pull, so every program is linked with the synthesizer;
 * here most programs make no sound (an editor, a spreadsheet), and a
 * platform must not ask for lib_audio. So Audio says here that it is
 * linked, and a platform looks:
 *
 *     a game ---> Audio (apis/) ---> lib_audio: the mixer
 *                   | at its start: source := Some ...
 *                   v
 *               Audio_source  <--- a platform, after each frame:
 *                                  the next n samples, if there is a
 *                                  source; to SDL's queue, to
 *                                  /dev/audio, or to a WAV file
 *
 * Samples are floats from -1 to 1, 44,100 a second, the left ear's
 * and the right one's. *)

type t = {
  (* the next [n] samples: the left ear's, the right one's *)
  pull : int -> float array * float array;
  (* how late the program's sounds are heard, in seconds, as the
   * platform measures it (Audio.latency) *)
  latency : float -> unit;
}

(* none until Audio is linked *)
val source : t option ref

(* [s16 (left, right)]: the samples as a sound card takes them and as
 * /dev/audio does: 16 bits signed, the low byte first, left then
 * right; a sample past -1 or 1 is cut there *)
val s16 : float array * float array -> string

(* [wav samples]: a WAV file of them (16 bits, two channels, 44,100) *)
val wav : string -> string

(* how many samples a frame is (a sixtieth of a second: 735), and how
 * many a platform keeps queued ahead of the sound card (three frames:
 * the playground's Native_loop_2d) *)
val frame_samples : int
val queue_ahead : int
