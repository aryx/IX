(* Vorbis_player: an .ogg file played as it goes, a packet decoded when
 * the samples before it are used up -- not the whole file decoded
 * first: six minutes of stereo at 44,100 samples a second are 32
 * million floats, 250 MB, where the file is 3 MB of packets and a
 * packet's block a few thousand samples.
 *
 *   the packets (Ogg)   kept as they are, the file's bytes
 *        |  one at a time, when the block before is used up
 *        v
 *   Vorbis.decode       a block, each channel's samples
 *        |  read at the file's rate, made the mixer's (Signal.rate)
 *        v  by a line between two samples (Resample's Linear)
 *   fill                both channels of the mixer's block
 *
 * At the end, from the first sound packet again (the decoder made
 * again from the headers), if it loops; else silence. The end is the
 * length the last page says (Ogg.length), as Vorbis.of_ogg cuts it:
 * the encoder's padding of the last block is not silence.
 *
 * ix's own: the playground decodes a file whole (Vorbis.of_ogg); this
 * is Mod_player's way, for Audio.play_ogg. *)

type t

(* [create ~loop bytes]: a player of the .ogg file's sound, from its
 * start; Error if it is not Ogg Vorbis *)
val create : loop:bool -> string -> (t, string) result

(* [fill p out]: the next samples, both channels, at Signal.rate *)
val fill : t -> Signal.stereo -> unit

(* the file's rate and channels *)
val rate : t -> int
val channels : t -> int

(* it has played its end and does not loop *)
val finished : t -> bool
