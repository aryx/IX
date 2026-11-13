(* An MPEG audio frame's header: the 4 bytes before each frame.

   An MPEG audio file (MPEG-1, ISO/IEC 11172-3, 1993; MPEG-2's lower
   rates, ISO/IEC 13818-3, 1995) is a sequence of frames. Each frame
   is enough on its own to decode (almost: Layer III borrows bytes, see
   Layer3.mli), and each starts with a header of 32 bits:

     AAAAAAAA AAABBCCD EEEEFFGH IIJJKLMM

     A  11  sync: all ones, what a decoder looks for (to resync after
            junk)
     B   2  version: 11 MPEG-1, 10 MPEG-2, 00 MPEG-2.5 (Fraunhofer's,
            never standard, for the lowest rates)
     C   2  layer: 11 I, 10 II, 01 III -- the three codecs of the
            standard, each more elaborate than the last
     D   1  0 when a 16-bit CRC follows the header
     E   4  bitrate, an index in a table for each version and layer
     F   2  sample rate, an index (44,100, 48,000, 32,000 for MPEG-1;
            halved for MPEG-2, quartered for 2.5)
     G   1  padding: one byte more in this frame
     H   1  private
     I   2  mode: stereo, joint stereo, dual channel, mono
     J   2  the mode's extension: which joint stereo
     K,L,M  copyright, original, emphasis

   The frame's length follows from the bitrate. A frame is 1152
   samples (384 for Layer I, 576 for MPEG-2's Layer III), so at 128
   kbit/s and 44,100 Hz, it lasts 1152 / 44,100 s at 128,000 bits a
   second: 144 * 128,000 / 44,100 = 417.96 bytes. A frame has 417
   bytes, and the padding bit adds a 418th byte to one frame in 25, to
   keep up.

   The frames of a file of one bitrate all have the same length. A
   *variable* bitrate file (VBR) changes the length from frame to
   frame, which the headers allow since each is read on its own. The
   "free format" (bitrate index 0, where the length is found by
   searching for the next header) is not read here.

   References: ISO/IEC 11172-3 (1993), section 2.4.1.3 and 2.4.2.3;
   ISO/IEC 13818-3 (1995); "MPEG Audio Frame Header",
   http://www.mp3-tech.org/programmer/frame_header.html *)

(* ix: copied from libs/audio/formats/mpeg_audio/Mpeg_audio_header.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

type version = Mpeg1 | Mpeg2 | Mpeg2_5
type mode = Stereo | Joint_stereo | Dual_channel | Mono

type t = {
  version : version;
  layer : int; (* 1, 2 or 3 *)
  crc : bool; (* a CRC of 2 bytes follows the header *)
  bitrate : int; (* bits a second *)
  sample_rate : int;
  padding : bool;
  mode : mode;
  mode_extension : int;
  channels : int; (* 1 or 2 *)
  length : int; (* the frame's bytes, the header's included *)
  samples : int; (* each channel's, in this frame *)
}

(* [parse s at] gives the header at byte [at] of [s]; None if there is
 * none (no sync, or a reserved or free-format value) *)
val parse : string -> int -> t option

(* [first_frame s] gives where the first frame is, and its header. It
 * looks past an ID3v2 tag if there is one (the tags a music player
 * shows, before the audio: "ID3", a version, flags, and a size in 4
 * bytes of 7 bits each). The first frame is the first header that is
 * followed by another like it (the same version, layer and sample
 * rate) or by the end, since two in a row are rarely chance, while one
 * often is *)
val first_frame : string -> (int * t) option

(* [at_start s] gives the first frame's header if it is right at the
 * start (past an ID3v2 tag) and is followed by another like it. This
 * is what a media player asks when it sniffs a file's kind, because
 * first_frame's search is too willing (two headers in a row happen in
 * any large file) *)
val at_start : string -> t option

(* [frames s] gives every frame's position and header, from the first
 * one; junk between frames is skipped, a byte at a time until a
 * header *)
val frames : string -> (int * t) list

val version_name : version -> string
