(* WAV files: samples on disk, the PPM of sound (see notes_audio.md
 * section 2). The golden tests compare WAV files, and a sound saved as
 * one can be listened to in any player.
 *
 * A WAV file (Microsoft and IBM's RIFF format, 1991) is a 44-byte
 * header followed by the samples, which are here 16-bit integers
 * (little-endian), in one channel:
 *
 *   offset  bytes  what                      for 1 s at 44,100 Hz
 *     0      4     "RIFF"
 *     4      4     36 + the data's size      88,236
 *     8      4     "WAVE"
 *    12      4     "fmt "
 *    16      4     16 (the format's size)
 *    20      2     1 (PCM: plain samples)
 *    22      2     1 channel
 *    24      4     the sample rate           44,100
 *    28      4     bytes a second            88,200
 *    32      2     bytes per sample frame    2
 *    34      2     bits per sample           16
 *    36      4     "data"
 *    40      4     the data's size           88,200
 *    44     ...    the samples
 *
 * References: the RIFF/WAVE format, "Multimedia Programming Interface
 * and Data Specifications 1.0", IBM and Microsoft, 1991;
 * http://soundfile.sapp.org/doc/WaveFormat/ *)

(* ix: copied from libs/audio/formats/wav/Wav.mli
 * in the author's playground (docs/plans/plan_audio.md). No file is
 * read or written here: write, read and write_stereo are left to the
 * caller, which has the capabilities. stereo_to_string is here in
 * their place, and so is stereo_of_string, which keeps a file's two
 * channels. *)

(* [to_string samples] gives the whole file, header and samples (each
 * sample converted by Signal.to_int16) *)
val to_string : Signal.t -> string

(* [of_string s] gives the samples of a WAV file as floats. The file is
 * 16-bit PCM (x / 32,767), or 8-bit (unsigned, with 128 the silence:
 * (x - 128) / 127; ix: for Quake's sounds). Its chunks are walked for
 * "fmt " and "data" (a file may carry others), stereo is mixed down to
 * one channel, and another sample rate is resampled to Signal.rate
 * (Resample.to_rate). It is Error for anything else (24 or 32-bit,
 * compressed) *)
val of_string : string -> (Signal.t, string) result

(* [stereo_of_string s] is the same with its two channels kept (for a
 * file of one channel, both have the same samples): it is what a
 * player wants *)
val stereo_of_string : string -> (Signal.stereo, string) result

(* [stereo_to_string s] writes two channels: the header's channels are
 * 2, its bytes a second and bytes per sample frame are doubled, and
 * the samples are interleaved, left then right: L0 R0 L1 R1 ... *)
val stereo_to_string : Signal.stereo -> string
