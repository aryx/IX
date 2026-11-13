(* MPEG audio files, decoded: MP2 and MP3.

   The three layers of MPEG-1 audio (ISO/IEC 11172-3, 1993) share the
   frame (Mpeg_audio_header.mli) and the end, where 32 subbands are put
   back together into sound (Polyphase.mli). In between, each layer
   codes the subband samples its own way:

     file --> frames --> Layer2: the subband samples, quantized per band
                     \-> Layer3: each subband split in 18 again (the
                         MDCT), Huffman codes, and bytes borrowed from
                         the frames before
                                   |
                                   v
                     32 subbands --> Polyphase --> the sound

   Layer I (a simpler Layer II, with 384 samples a frame) is not read
   here. Neither are the free format and MP3's Xing and LAME tags (the
   frame count of a VBR file, and the encoder's delay and padding,
   which a gapless player cuts; the first frame, which holds the tag,
   decodes to silence).

   A frame that cannot be decoded is silence. That is a Layer III frame
   whose borrowed bytes were cut off, at the start of a stream joined
   in the middle. *)

(* ix: copied from libs/audio/formats/mpeg_audio/Mpeg_audio.mli
 * in the author's playground (docs/plans/plan_audio.md). The decoder
 * with a state (create, and next, which decodes a frame when it is
 * asked for) is ix's own, and decode is written over it. *)

(* [decode s] gives the first frame's header, and the samples at its
 * sample rate (Resample.to_rate converts them to Signal.rate), a mono
 * file's samples being in both channels. It is Error when there is no
 * frame, or when the layer is one we do not read *)
val decode : string -> (Mpeg_audio_header.t * Signal.stereo, string) result

(* A file decoded a frame at a time. A song of four minutes is 21
 * million samples, which [decode] has all in memory before the first
 * one is heard. Here a player asks for the next 1,152 (Layer III's
 * frame, 26 ms) when it has played the last ones. What goes from a
 * frame to the next (Layer III's borrowed bytes, the overlap of its
 * transform, the filter bank's memory) is in [t]. *)
type t

(* [create s] is at the first frame; its Error is [decode]'s *)
val create : string -> (t, string) result

(* the first frame's header (the rate, the channels, the bitrate) *)
val header : t -> Mpeg_audio_header.t

(* how many samples all its frames hold *)
val samples : t -> int

(* [next d] gives the next frame's samples, at the file's rate, a mono
 * file's samples being in both channels; None after the last frame *)
val next : t -> Signal.stereo option
