(* Player: a file of sound played a block at a time, whatever its
 * format.
 *
 * The sounds of a game are rendered ahead: a tree of a few notes
 * (Synth) become samples once, then played. A song is not: four
 * minutes of it are 21 million samples, twice. So what plays a song
 * gives its next samples when they are asked for, a block at a time,
 * and keeps between two blocks only what the format needs:
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
 * It is the shape of an instrument's [fill] (Instrument), without the
 * keys and the knobs: the mixer pulls one as it pulls the other.
 * mini-play is this module and a loop that writes the blocks; a game's
 * music from a file is the same player given to the mixer.
 *
 * Every file ends at Signal's rate, 44,100 samples a second: a WAV or
 * an MP3 at another is resampled (Resample's linear reading), the MP3
 * as its frames come, two of them held since a sample out may be read
 * between a frame's last and the next one's first.
 *
 * others:
 * 9front has a program a format, each a filter from the file to
 * samples on its standard output (audio/mp3dec, audio/wavdec,
 * audio/oggdec, games/midi), and play(1), a script that looks at the
 * file's first bytes and runs the one that reads it into /dev/audio.
 * Here one program, and the format by the file's name. *)

type t = {
  (* the next block: both channels written over, their length the
   * block's; silence past the end *)
  fill : Signal.stereo -> unit;
  (* whether the end was reached *)
  finished : unit -> bool;
}

(* [of_samples s]: samples already there, played once *)
val of_samples : Signal.stereo -> t

(* [of_file name bytes]: the player of a file, by its name's end (.mod,
 * .mid or .midi, .mp3 or .mp2, .wav, .ogg, .abc); Error with why not *)
val of_file : string -> string -> (t, string) result
