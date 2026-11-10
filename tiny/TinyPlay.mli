(* tiny-play: a WAV file played, on tiny-kernel's speaker
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
 * A file's sound is its samples made into the speaker's, a block at a
 * time, each written when the last was taken, so the kernel, which
 * takes a voice's samples a second ahead of the speaker at most, paces
 * the program, and the first is heard after a block, not after the
 * whole file:
 *
 *     the file's bytes --> [wav]: RIFF's chunks, "fmt " and "data"
 *                             |  2,048 samples at a time ([block])
 *                             v
 *         the frame at each sample's time, its channels' mean, its top
 *         8 bits ([piece]) --> /dev/audio, a message `p n` and the n bytes
 *
 * The speaker's samples are 8,000 a second, a byte each, signed: what a
 * WAV has (8 or 16 bits, one channel or two, 44,100 or 11,025 a
 * second) is made that by taking, at each of the speaker's samples, the
 * file's frame at that time (exactly, by Bresenham's stepping: no
 * division a sample), the
 * mean of its channels, and its top byte. No filter: a file of 44,100
 * a second loses what is above 4,000 Hz, and what is above folds down
 * (aliasing), which a filter before the taking would prevent.
 *
 * dropped:
 * Every other format (MOD, MIDI, MP3: lib_audio has thousands of lines
 * for them), floats, a WAV's other encodings (24 or 32 bits, floats,
 * ADPCM, A-law), and the -c and -s options.
 *
 * cs-history:
 * WAV is Microsoft's and IBM's RIFF (1991), itself Electronic Arts'
 * IFF (1985, the Amiga's) with its numbers little-endian: chunks, each
 * four letters and a length, so a reader skips what it does not know.
 *)

(* a WAV's sound: its rate, its channels, its bits a sample, where its
 * samples start and how many bytes they are *)
type wav = { rate : int; channels : int; bits : int; at : int; bytes : int }

(* the WAV in a file's bytes (its contents, not its name), or Failure
 * why (not RIFF's, not PCM, not 8 or 16 bits) *)
val wav : string -> wav

(* how many of the speaker's samples (8,000 a second) its sound is *)
val samples : wav -> int

(* [piece w data k n]: the speaker's samples k to k + n - 1 of the
 * file's sound, a byte each, signed *)
val piece : wav -> string -> int -> int -> string

(* the samples a block *)
val block : int

(* [play out data]: the sound in data, a WAV file's bytes (as for
 * [wav]), written to the file descriptor out (/dev/audio, opened by
 * the caller), a block at a time; Failure why when it is no WAV this
 * plays *)
val play : int -> string -> unit

(* No main here, unlike TinyShell's or TinyAssembler's: those are
 * written on TinyLibSystem.main and its capabilities, the same on the
 * host and on tiny-kernel. play is written on TinyCalls, as the
 * programs with a screen are, for the same reason: on the host its
 * device, /dev/audio, is not Unix's (the host's TinyLibSystem) but the
 * one TinyLibSystem/sdl/TinyCalls.ml makes, as it makes their window. Its command
 * line (the file read, /dev/audio opened, why not said) is
 * user/play.ml's, a few lines, as troff's is
 * user/troff.ml's; the host's tiny-play compiles that same file. *)
