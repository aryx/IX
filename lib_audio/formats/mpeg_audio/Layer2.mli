(* Layer II (MP2): the subband samples, quantized band by band.

   Layer II is Polyphase.mli's idea and nothing more: the 32 subbands,
   each given as many bits as the encoder's model of the ear says it
   deserves. It came from MUSICAM (IRT, Philips, CCETT, Matsushita,
   1989). It is what digital radio (DAB) and the Video CD carry, and it
   is the sound of most MPEG-1 and MPEG-2 video, the DVB broadcasts
   among them.

   A frame is 1152 samples: 36 time slots of the 32 subbands, in 3
   parts of 12 (each part is 384 sound samples, Layer I's whole frame).
   After the header come:

     bit allocation   for each band (and channel), how many levels its
                      samples are quantized to, from none (not sent:
                      silence, or masked) to 65,535. It takes 2 to 4
                      bits a band, an index into the band's list of
                      allowed levels (Table B.2: the high bands may
                      only choose among few)
     scfsi            for each band sent, which of the 3 parts share a
                      scalefactor (4 ways, 2 bits)
     scalefactors     for each band sent, 1 to 3 of them, 6 bits each:
                      the band's loudness, 2^(1 - i/3), from 2 down in
                      steps of 2 dB. The samples are fractions of it
     samples          12 times, for each band, 3 samples, each an
                      integer number of levels; or the 3 are grouped in
                      one number when the levels are 3, 5 or 9 (3 x 3 x
                      3 = 27 fits in 5 bits, where 3 x 2 bits would
                      take 6)

   A sample coded as [c] of [n] levels is the fraction (2c + 1 - n) / n
   of its scalefactor: the n values are evenly spread between -1 and 1,
   with 0 among them (n is odd). The standard writes it with two
   constants for each n (Table B.4, "C" and "D"), which give the same
   numbers.

   The bit allocation tables (B.2a to d) depend on the bitrate per
   channel and on the sample rate. Low bitrates may code fewer bands (8
   or 12, the highest frequencies being dropped), and high ones up to
   30 (never the last 2 of the 32, which are above 20 kHz). MPEG-2's
   lower sample rates have a table of their own (ISO/IEC 13818-3,
   Table B.1).

   **Joint stereo** (intensity stereo, in Layer II): above a band given
   by the mode extension (4, 8, 12 or 16), the two channels share their
   samples, and each keeps its own scalefactors. That gives the same
   waveform, louder on one side, because the ear locates high
   frequencies by loudness, not by phase.

   References: ISO/IEC 11172-3 (1993), 2.4.1.6, 2.4.3.3, Tables B.1,
   B.2, B.4; ISO/IEC 13818-3 (1995), Table B.1. *)

(* ix: copied from libs/audio/formats/mpeg_audio/Layer2.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* [decode header bits] gives the frame's subband samples, with [bits]
 * just past the header (and its CRC). Each channel has 36 time slots
 * of 32 bands, and slot [t]'s band [sb] is at [t * 32 + sb] *)
val decode : Mpeg_audio_header.t -> Bitstream.t -> float array array

(* [table header] is the bit allocation table that the frame uses. For
 * each band, it gives the levels that each allocation code means (0
 * first, for not sent), and it has as many bands as the frame codes *)
val table : Mpeg_audio_header.t -> int array array
