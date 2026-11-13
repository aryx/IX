(* Mpeg_system reads MPEG-1 system streams (.mpg): a video and its
   sound, interleaved.

   MPEG-1 is three standards in one (ISO/IEC 11172, 1993): video (part
   2, Mpeg1.mli), audio (part 3, Mpeg_audio.mli), and systems (part 1).
   Systems is what puts the other two in one file, or in one stream on
   a Video CD. That stream is read at a constant speed off the disc,
   so each part must arrive in time, in small pieces, with the audio
   never far from the pictures it goes with:

     pack      00 00 01 BA  the system clock (SCR) and the stream's rate
       system header 00 00 01 BB (the first pack's): the streams, their
                             buffers
       packet  00 00 01 E0  2 bytes of length; stuffing; the time this
                            piece of video is presented (PTS) and, for
                            pictures sent before they are shown (a P
                            before the Bs that come before it), decoded
                            (DTS); then the bytes of the video stream
       packet  00 00 01 C0  the same, of the audio stream
       packet  00 00 01 BE  padding
     pack      00 00 01 BA  ...
     end       00 00 01 B9

   A packet's stream id says what it carries: C0 to DF is one of 32
   audio streams, and E0 to EF is one of 16 video streams (a DVD's many
   languages and angles come from there). The **demultiplexer**, here,
   is the simple half. Each stream's packets, with their headers taken
   off and laid end to end, give back the stream as its encoder wrote
   it (an .m1v, an .mp2), for its own decoder. The clock is the subtle
   half. A timestamp counts 90,000 ticks a second (a multiple of both
   25 and 30 frames a second, and of the frames of MPEG's sample
   rates), and the first packets' timestamps say when each stream
   starts. The audio often starts a few milliseconds before or after
   the video, which a player must not ignore.

   MPEG-2's program streams (a DVD's .vob) are the same idea with a
   longer pack header (its first bits are 01, where MPEG-1's are 0010)
   and another packet header. They are refused here.

   References: ISO/IEC 11172-1 (1993), 2.4.3; "MPEG-1 Systems",
   https://en.wikipedia.org/wiki/MPEG_program_stream *)

type stream = {
  id : int; (* the stream id: C0 to DF audio, E0 to EF video *)
  bytes : string; (* the contents of its packets, end to end *)
  first_pts : float option; (* when it starts, in seconds of the clock *)
}

(* [of_string s] gives the streams, in the order in which their first
 * packets come (padding and private streams are left out). It raises
 * Failure if [s] isn't an MPEG-1 system stream *)
val of_string : string -> stream list

(* the first video stream, and the first audio stream *)
val video : stream list -> stream option
val audio : stream list -> stream option

(* [pts bytes] reads a timestamp from its 5 bytes, which hold 33 bits
 * among markers: 4 bits of prefix, then bits 32-30 and a marker bit,
 * then 15 bits and a marker, then 15 bits and a marker. The timestamp
 * is in ticks of 90,000 a second *)
val pts : string -> int -> int
