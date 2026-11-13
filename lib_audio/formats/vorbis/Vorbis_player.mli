(* Vorbis_player: an .ogg file played as it goes. A packet is decoded
 * when the samples before it are used up, rather than the whole file
 * being decoded first: six minutes of stereo at 44,100 samples a
 * second are 32 million floats, 250 MB, where the file is 3 MB of
 * packets and a packet's block is a few thousand samples.
 *
 *   the packets (Ogg)   kept as they are, the file's bytes
 *        |  one at a time, when the block before is used up
 *        v
 *   Vorbis.decode       a block, each channel's samples
 *        |  read at the file's rate, made the mixer's (Signal.rate)
 *        v  by a line between two samples (Resample's Linear)
 *   fill                both channels of the mixer's block
 *
 * At the end, it starts again from the first sound packet (the decoder
 * being made again from the headers) if it loops; otherwise it gives
 * silence. The end is the length that the last page says (Ogg.length),
 * where Vorbis.of_ogg cuts the sound too, because the encoder's padding
 * of the last block is not silence.
 *
 * ix's own: the playground decodes a file whole (Vorbis.of_ogg), while
 * this player works the way Mod_player does, for Audio.play_ogg. *)

type t

(* [create ~loop bytes] is a player of the .ogg file's sound, from its
 * start; Error if it is not Ogg Vorbis *)
val create : loop:bool -> string -> (t, string) result

(* [fill p out] writes the next samples, in both channels, at
 * Signal.rate *)
val fill : t -> Signal.stereo -> unit

(* the file's rate and channels *)
val rate : t -> int
val channels : t -> int

(* whether it has played to its end, and does not loop *)
val finished : t -> bool
