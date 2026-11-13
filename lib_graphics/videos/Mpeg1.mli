(* Mpeg1 reads MPEG-1 video (ISO/IEC 11172-2, 1993), where a frame is
 * predicted from others by moving blocks, and only the difference is
 * sent.

   FLI stores a frame as the pixels that changed (Fli.mli), but a
   camera that pans changes them all. MPEG-1's idea is that the pixels
   didn't change, they **moved**. So a frame is cut into
   **macroblocks** of 16 x 16 pixels (four 8 x 8 blocks of Y, one of Cb
   and one of Cr: 4:2:0, Yuv.mli), and each macroblock is either

     intra       coded alone, as JPEG would code it (Jpeg.mli): the DCT
                 of each block, quantized, in zigzag order, as
                 (run, level) codes (Mpeg1_vlc.mli)
     predicted   copied from a frame already decoded, **moved** by a
                 motion vector, plus the DCT of what still differs, the
                 **residual**. That is often nothing, and takes a few
                 bits

   and the pictures come in three kinds:

     I  intra: every macroblock is coded alone. A player can start
        there.
     P  predicted forward from the last I or P
     B  bidirectional: predicted from the I or P before, from the one
        after, or from the average of both. These are the best
        predictions. So a B is sent after the P it needs, and the
        decoder **reorders** the pictures:

          display order:   I0  B1  B2  P3  B4  B5  P6
          decode order:    I0  P3  B1  B2  P6  B4  B5

        A decoder holds the last reference (I or P) back, shows the Bs
        as they come, and shows the held one when the next reference
        comes.

   **Half a pixel**: a vector counts half pixels. Between two pixels,
   the prediction is their average, rounded up, (a + b + 1) / 2, and
   between four it is (a + b + c + d + 2) / 4. Here is a worked
   example: the row 10 20 30 40 moved by 3 half pixels, that is 1.5 to
   the left, so that the prediction of pixel x comes from the pixels at
   x + 1 and x + 2. It gives 25 35, then the edge. The color's vector
   is half the brightness's (the color has half the resolution),
   rounded towards 0, so 3 half pixels become 1.

   A vector is sent as its difference from the one before (the
   neighbour's vector, which is usually the same, so the difference is
   "1", one bit: Mpeg1_vlc.mli), in f_code ranges. A skipped
   macroblock, of which nothing is sent at all, is, in a P picture, the
   macroblock of the reference at the same place, and, in a B picture,
   the previous macroblock's prediction again.

   **Quantization** is JPEG's. Each coefficient is multiplied back by
   the macroblock's quantizer_scale (1-31, the encoder's knob, sent per
   slice or per macroblock) and by a matrix entry (from the intra
   matrix given, or the default one; for predicted blocks, the entry is
   16 everywhere). An intra coefficient is 2 level q m / 16, and a
   predicted one is (2 level + sign) q m / 16, then made odd (this is
   the IDCT mismatch control: an even value is moved one towards 0),
   within -2048..2047. An intra block's DC is sent as the difference
   from the previous block's, as in JPEG, in units of 8.

   The bitstream is made of layers inside layers, each starting with a
   start code (Bitstream.mli):
   - a sequence header (the size, the frame rate, the matrices);
   - groups of pictures;
   - a picture header (its kind, its place in display order, the
     vectors' ranges);
   - slices: a slice is a row of macroblocks, or part of one, where a
     decoder resynchronizes after an error, and where the predictions
     start over;
   - macroblocks.

   What is read here: MPEG-1 video elementary streams (.m1v, what a
   .mpg holds inside its packets; the packets, which are the system
   stream, are not read), I, P and B pictures, the matrices, skipped
   macroblocks, and both vector precisions. D pictures (DC only, for
   fast search, never used) are not read. The IDCT is Dct.mli's
   floating-point one, so a pixel can differ by one from another
   decoder's (the standard allows it, within the IEEE 1180 limits).

   References: ISO/IEC 11172-2 (1993); Didier Le Gall, "MPEG: a video
   compression standard for multimedia applications", CACM 34(4)
   (1991); Dominic Szablewski's pl_mpeg (2019), a decoder in one file
   of C, and jsmpeg. *)

type kind = I | P | B

(* how a macroblock was coded, for the analyzer *)
type how = Intra | Forward | Backward | Both | Zero (* in a P picture, with no vector: the same place *) | Skipped

(* a picture, as decoded: its kind, and each macroblock's coding and
 * vectors (in half pixels, and (0, 0) when there is none), row by
 * row *)
type info = { kind : kind; macroblocks : (how * (int * int) * (int * int)) array; mb_width : int }

type header = { width : int; height : int; rate : int * int; kinds : kind array (* display order *) }

(* [of_string s] gives the header, the frames in display order, decoded
 * forward only (Movie.sequential), and each frame's info (decoding the
 * frame if need be). With [residual], each frame shown is instead
 * **what was sent** for it: the intra macroblocks as they are, the
 * predicted ones as their residual on gray (128), and the skipped ones
 * gray. This switches the prediction off for the analyzer (the
 * references are still the true pictures). It raises Failure if [s]
 * isn't an MPEG-1 video stream. *)
val of_string : residual:bool -> string -> header * Movie.t * (int -> info)

(* the half-pixel prediction of Mpeg1.mli's worked example: [predict
 * row x v] is the prediction of pixel [x] of [row] moved by [v] half
 * pixels *)
val predict : int array -> int -> int -> int

(* The decoder's arithmetic is also given for the encoder
 * (Mpeg1_encode.mli). An encoder predicts from what the decoder will
 * have, not from the source, or the two drift apart a little more at
 * every P frame. *)

(* the default intra matrix, in natural order *)
val default_intra : int array

(* [prediction plane ~stride ~rows ~x ~y ~size v] is the [size] x [size]
 * square at (x, y) of [plane], moved by [v] half pixels *)
val prediction : Bytes.t -> stride:int -> rows:int -> x:int -> y:int -> size:int -> int * int -> int array

(* [dequantize ~intra ~q ~m level] gives a coefficient back from its
 * level *)
val dequantize : intra:bool -> q:int -> m:int -> int -> int

(* the frame rates' codes: the rate (num, den) is at index code *)
val picture_rates : (int * int) array
