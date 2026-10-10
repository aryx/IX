(* The discrete cosine transform: an 8 x 8 block of pixels as a sum of
   64 cosine patterns, and back.

   JPEG gives up exactness for size, and the question is what to give
   up. The eye sees slow changes (the shading of a face) much better
   than fast ones (the grain of skin, noise). So JPEG rewrites each 8 x 8
   block as how much it has of each of 64 patterns, from flat to finely
   striped, keeps the slow ones precisely and the fast ones roughly, or
   not at all (the quantization, Jpeg.mli). The patterns are cosines, u
   half-periods across the block horizontally, v vertically:

     u = 0      u = 1      u = 2         ...  u = 7
     ########   ####....   ##....##           #.#.#.#.      one row of
     (flat)     (a slope)  (a bump)           (the finest)  each, v = 0

   The forward transform (the encoder's) measures them, F(u, v) for a
   block f(x, y); the inverse (the decoder's) adds them back:

     F(u, v) = 1/4 C(u) C(v) sum over x, y of
                 f(x, y) cos((2x + 1) u pi / 16) cos((2y + 1) v pi / 16)

     f(x, y) = 1/4 sum over u, v of
                 C(u) C(v) F(u, v) cos((2x + 1) u pi / 16) cos((2y + 1) v pi / 16)

     C(0) = 1 / sqrt 2, C(k) = 1 otherwise; x, y, u, v from 0 to 7

   F(0, 0), the DC coefficient, is 8 times the block's average; the 63
   others, the AC ones, its details. The worked example
   (notes_images.md section 8): a block whose only coefficient is F(0,
   0) = 80 is flat, every pixel 1/4 * 1/2 * 80 = 10 -- then 138, once
   JPEG adds back the 128 it took away before the transform.

   The formula costs 64 multiplications a pixel, 4096 a block: [idct].
   The transform is separable -- 8 one-dimensional transforms on the
   rows, then 8 on the columns -- 16 a pixel; and Arai, Agui and
   Nakajima (1988) factored the 1D transform down to 5 multiplications,
   with 8 more folded into scale factors that a decoder can fold into
   the quantization table: [idct_aan], the one of the IJG's libjpeg's
   floating-point decoder (jidctflt.c). Both give the same pixels,
   within rounding (a test checks it); Jpeg.decode uses AAN unless told
   otherwise.

   Blocks are 64 floats, row by row: F(u, v) at v * 8 + u, f(x, y) at
   y * 8 + x.

   Why cosines, and not Fourier's sines and cosines. Fourier's
   transform takes the block as one period of a signal that repeats:
   where the right edge does not match the left, it sees a jump, and
   a jump needs every frequency. The cosine transform is Fourier's of
   the block followed by its mirror image, which always joins:

     Fourier's:   /|/|/|       a ramp repeated: a cliff at each end
     cosine's:    /\/\/\       a ramp and its mirror: no cliff

   so a smooth block is a few low coefficients and the rest near
   zero, which is all the quantization asks for.

   Where it stands in ix: called by Jpeg alone, once a block, after
   the coefficients are multiplied back by the quantization table;
   [fdct] is the tests' (no JPEG is written here).

   cs-history:
   Nasir Ahmed thought of it in 1972, at Kansas State University, and
   published it in 1974 with T. Natarajan and K. R. Rao: a transform
   nearly as good as the one that is optimal for a signal whose
   neighbouring samples are alike (Karhunen and Loeve's, which
   depends on the signal and has no fast algorithm), and computed as
   fast as Fourier's. It is in JPEG, in every video codec from H.261
   (1988) on, and, in a variant whose blocks overlap, in MP3 and AAC:
   most of the bytes that cross the Internet have been through it.

   References: Nasir Ahmed, T. Natarajan and K. R. Rao, "Discrete Cosine
   Transform", IEEE Transactions on Computers C-23 (1974); Yukihiro
   Arai, Takeshi Agui and Masayuki Nakajima, "A Fast DCT-SQ Scheme for
   Images", Transactions of the IEICE E71 (1988); ITU-T T.81 (1992),
   section A.3.3; William Pennebaker and Joan Mitchell, JPEG Still Image
   Data Compression Standard (1993), chapter 4. *)
(* ix: the author's playground's libs/graphics/images/jpeg/Dct.mli (docs/plans/plan_pdf.md) *)

(* the forward transform, from the formula *)
val fdct : float array -> float array

(* the inverse transform, from the formula *)
val idct : float array -> float array

(* the inverse transform, Arai-Agui-Nakajima's *)
val idct_aan : float array -> float array
