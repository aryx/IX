(* Player: a sound file played a block at a time, whatever its format.
 *
 * The sounds of a game are rendered ahead: a tree of a few notes
 * (Synth) becomes samples once, and is then played. A song cannot be
 * handled that way, since four minutes of it are 21 million samples,
 * twice. So what plays a song gives its next samples when they are
 * asked for, a block at a time, and keeps between two blocks only what
 * the format needs:
 *
 *                 +-- .mod --> Mod_player   the rows, four channels' place in their samples
 *    the file's   +-- .mid --> Music        the notes to come, those sounding
 *    bytes -------+-- .mp3 --> Mpeg_audio   a frame decoded (1,152 samples), where in it
 *                 +-- .wav --> Wav          its samples, where in them
 *                 +-- .ogg --> Vorbis       a packet decoded (a block), where in it
 *                 +-- .abc --> Abc, Music   a tune of a page: rendered whole
 *                         |
 *                         v
 *                    fill out            the next block, both channels
 *
 * It has the shape of an instrument's [fill] (Instrument), without the
 * keys and the knobs, and the mixer pulls one as it pulls the other.
 * mini-play is this module and a loop that writes the blocks; a game's
 * music from a file is the same player given to the mixer.
 *
 * Every file comes out at Signal's rate, 44,100 samples a second. A
 * WAV or an MP3 at another rate is resampled (Resample's linear
 * reading). An MP3 is resampled as its frames come, and two frames are
 * held, since a sample out may be read between a frame's last sample
 * and the next frame's first.
 *
 * others:
 * 9front has a program for each format, each a filter from the file to
 * samples on its standard output (audio/mp3dec, audio/wavdec,
 * audio/oggdec, games/midi). Its play(1) is a script that looks at the
 * file's first bytes and runs the program that reads it into
 * /dev/audio. Here there is one program, and it picks the format by
 * the file's name. *)

type t = {
  (* computes the next block: both channels are written over, and their
   * length is the block's; past the end, it is silence *)
  fill : Signal.stereo -> unit;
  (* whether the end was reached *)
  finished : unit -> bool;
}

(* [of_samples s] plays samples that are already there, once *)
val of_samples : Signal.stereo -> t

(* [of_file name bytes] is the player of a file, chosen by the end of
 * its name (.mod, .mid or .midi, .mp3 or .mp2, .wav, .ogg, .abc), or
 * Error with the reason *)
val of_file : string -> string -> (t, string) result
