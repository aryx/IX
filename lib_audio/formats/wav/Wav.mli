(* WAV files: samples on disk, the PPM of sound (see notes_audio.md
 * section 2): what the golden tests compare, and what a sound can be
 * listened to with, in any player.
 *
 * A WAV file (Microsoft and IBM's RIFF format, 1991) is a 44-byte
 * header, then the samples, here 16-bit integers (little-endian), one
 * channel:
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

(* ix: the author's playground's libs/audio/formats/wav/Wav.mli; no file read or written here (write, read, write_stereo: the caller's, through its capabilities), stereo_to_string in their place, and stereo_of_string, a file's two channels kept (docs/plans/plan_audio.md) *)

(* [to_string samples]: the whole file, header and samples (each as
 * Signal.to_int16) *)
val to_string : Signal.t -> string

(* [of_string s]: the samples of a WAV file, 16-bit PCM, as floats (x /
 * 32,767): its chunks walked for "fmt " and "data" (a file may carry
 * others), stereo mixed down to one channel, another sample rate
 * resampled to Signal.rate (Resample.to_rate); Error for anything else
 * (8, 24 or 32-bit, compressed) *)
val of_string : string -> (Signal.t, string) result

(* [stereo_of_string s]: the same with its two channels kept (a file of
 * one channel: both the same samples): what a player wants *)
val stereo_of_string : string -> (Signal.stereo, string) result

(* [stereo_to_string s]: two channels, the header's channels 2, the
 * bytes a second and per sample frame doubled, and the samples
 * interleaved, left then right: L0 R0 L1 R1 ... *)
val stereo_to_string : Signal.stereo -> string
