(* tiny-play: plays a WAV file on tiny-kernel's speaker
 * (plan_tiny_audio.md, step 4).
 *
 *     play /examples/korobeiniki.wav        on tiny-kernel
 *     tiny-play song.wav                    on the host (user/sdl/)
 *
 * twin:
 * mini-play (apps/media/play/, on lib_audio/formats/) plays MOD,
 * MIDI, MP3, WAV and ABC to Plan 9's /dev/audio.
 *
 * kept:
 * The file's samples are converted into the speaker's one block at a
 * time, and each block is written once the kernel has taken the last.
 * The kernel accepts a voice's samples at most a second ahead of the
 * speaker, so it paces the program, and the sound starts after one
 * block instead of after the whole file:
 *
 *     the file's bytes --> [wav] reads RIFF's chunks, "fmt " and "data"
 *                             |  2,048 samples at a time ([block])
 *                             v
 *         [piece]: at each sample's time, the frame's channels averaged,
 *         the top 8 bits kept --> /dev/audio, a message `p n` and n bytes
 *
 * The speaker takes 8,000 samples a second, each a signed byte. A WAV
 * can have 8 or 16 bits, one channel or two, and 44,100 or 11,025
 * samples a second. To convert it, at each of the speaker's samples we
 * take the file's frame at that time (exactly, using Bresenham's
 * stepping, so there is no division per sample), average its channels,
 * and keep the top byte. There is no filter: a file at 44,100 a second
 * loses everything above 4,000 Hz, and what is above folds down
 * (aliasing). A low-pass filter before the sampling would prevent
 * that.
 *
 * dropped:
 * Every other format (MOD, MIDI, MP3: lib_audio has thousands of lines
 * for them), floats, a WAV's other encodings (24 or 32 bits, floats,
 * ADPCM, A-law), and the -c and -s options.
 *
 * cs-history:
 * WAV is a kind of RIFF, Microsoft's and IBM's format (1991), which is
 * itself Electronic Arts' IFF (1985, on the Amiga) with little-endian
 * numbers. A file is a list of chunks, each starting with four letters
 * and a length, so a reader can skip what it does not know.
 *)

(* [at] and [bytes] locate the samples in the file. *)
type wav = { rate : int; channels : int; bits : int; at : int; bytes : int }

(* Reads the file's contents, not its name. It raises Failure when the
 * file is not RIFF, not PCM, or not 8 or 16 bits. *)
val wav : string -> wav

(* the length of the sound in speaker samples (8,000 a second) *)
val samples : wav -> int

(* [piece w data k n]: speaker samples k to k + n - 1, signed bytes *)
val piece : wav -> string -> int -> int -> string

(* the number of samples in a block *)
val block : int

(* [play out data] writes a block at a time to out, which the caller
 * opened on /dev/audio. It raises Failure as [wav] does. *)
val play : TinyLibSystem.fd -> string -> unit

(* The program play file.wav, the same on the host and on tiny-kernel
 * (user/play.ml is one line). On the host, /dev/audio is not Unix's but
 * the one that TinyLibSystem/sdl/ provides, as it provides the window. *)
val main : < Cap.open_in; Cap.open_out; Cap.stderr; .. > -> string array -> Exit.t
