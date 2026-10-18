(* tiny-play: a WAV file played, on tiny-kernel's speaker
 * (plan_tiny_audio.md, step 4). m-ix's twin is mini-play
 * (apps/music/play/, on lib_audio/formats/), which plays MOD, MIDI,
 * MP3, WAV and ABC to Plan 9's /dev/audio.
 *
 *     play /examples/korobeiniki.wav        on tiny-kernel
 *     tiny-play song.wav                    on the host (../sdl/)
 *
 * The idea kept: a file's sound is its samples made into the speaker's,
 * a block at a time, each written when the last was taken, so the
 * kernel, which takes a voice's samples a second ahead of the speaker
 * at most, paces the program, and the first is heard after a block, not
 * after the whole file:
 *
 *     the file's bytes --> [wav]: RIFF's chunks, "fmt " and "data"
 *                             |  2,048 samples at a time ([block])
 *                             v
 *         the frame at each sample's time, its channels' mean, its top
 *         8 bits ([piece]) --> /audio, a message `p n` and the n bytes
 *
 * The speaker's samples are 8,000 a second, a byte each, signed: what a
 * WAV has (8 or 16 bits, one channel or two, 44,100 or 11,025 a
 * second) is made that by taking, at each of the speaker's samples, the
 * file's frame at that time (in fixed point: no division a sample), the
 * mean of its channels, and its top byte. No filter: a file of 44,100
 * a second loses what is above 4,000 Hz, and what is above folds down
 * (aliasing), which a filter before the taking would prevent.
 *
 * What is dropped: every other format (MOD, MIDI, MP3: lib_audio has
 * thousands of lines for them), floats, a WAV's other encodings
 * (24 or 32 bits, floats, ADPCM, A-law), and the -c and -s options.
 *
 * history:
 * WAV is Microsoft's and IBM's RIFF (1991), itself Electronic Arts'
 * IFF (1985, the Amiga's) with its numbers little-endian: chunks, each
 * four letters and a length, so a reader skips what it does not know.
 *)

(* a WAV's sound: its rate, its channels, its bits a sample, where its
 * samples start and how many bytes they are *)
type wav = { rate : int; channels : int; bits : int; at : int; bytes : int }

(* a file's WAV, or Failure why (not RIFF's, not PCM, not 8 or 16 bits) *)
val wav : string -> wav

(* how many of the speaker's samples (8,000 a second) its sound is *)
val samples : wav -> int

(* [piece w data k n]: the speaker's samples k to k + n - 1 of the
 * file's sound, a byte each, signed *)
val piece : wav -> string -> int -> int -> string

(* the samples a block *)
val block : int

(* [play out data]: the file's sound written to out (/audio), a block
 * at a time; Failure why when it is no WAV this plays *)
val play : int -> string -> unit
