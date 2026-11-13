(* JPEG throws away what the eye doesn't see, then compresses the rest.

   The Joint Photographic Experts Group, formed in 1986 by ISO and the
   CCITT, compared a dozen proposals and chose the discrete cosine
   transform (Dct.mli) with quantization and Huffman codes. The
   standard is ITU-T T.81 (1992). It defines the coding, not a file.
   The file everybody writes is JFIF (Eric Hamilton, C-Cube, 1992),
   cameras write Exif around the same data, and the Independent JPEG
   Group's free libjpeg (Tom Lane, 1991) is what made the web's
   photographs JPEGs.

   Here is the encoder, which the decoder runs backwards:

     RGB -> YCbCr -> subsample -> 8x8 blocks -> DCT -> quantize -> zigzag -> runs -> Huffman
            brightness  color at    (-128)             divide and  low          of
            and color   half size                      round: the  frequencies  zeros
                                                       loss        first

   YCbCr is brightness and two color differences, as in color TV
   (these are JFIF's constants, from ITU-R BT.601):

     R = Y + 1.402 (Cr - 128)
     G = Y - 0.344136 (Cb - 128) - 0.714136 (Cr - 128)
     B = Y + 1.772 (Cb - 128)

   Subsampling: the eye sees color less sharply than brightness, so Cb
   and Cr are often kept at half the width (4:2:2), or at half the
   width and height (4:2:0). A component's sampling factors (h, v) say
   how many of its blocks cover the area that the largest factors
   cover; that area is a minimum coded unit, an MCU. In 4:2:0, Y is
   2 x 2 and Cb and Cr are 1 x 1, so an MCU is 16 x 16 pixels: 4 Y
   blocks, then one Cb and one Cr, which is 384 samples instead of 768.
   The decoder makes the color planes full size again. Box repeats
   each sample (the simple way). Triangle weighs the two nearest
   samples 3/4 and 1/4 (it is libjpeg's "fancy upsampling", smoother on
   color edges, and the default).

   Quantization is the loss: each coefficient was divided by an entry
   of an 8 x 8 table (with large entries for high frequencies) and
   rounded, and the decoder multiplies back. The tables are in the file
   ("quality" is only the encoder's way of scaling them).

   Zigzag and runs: after quantization most high frequencies are 0.
   When the block is read in a zigzag from the top-left, the zeros come
   last, in a run:

      0  1  5  6 14 15 27 28      the order of the 64 coefficients
      2  4  7 13 16 26 29 42      in the file
      3  8 12 17 25 30 41 43
      9 11 18 24 31 40 44 53
     10 19 23 32 39 45 52 54
     20 22 33 38 46 51 55 60
     21 34 37 47 50 56 59 61
     35 36 48 49 57 58 62 63

   The DC coefficient is sent as the difference from the DC of the
   previous block of the same component. Each nonzero AC coefficient
   is sent as a Huffman symbol (the run of zeros before it, and its
   size in bits), then its bits. Symbol 0x00 ends the block (the rest
   are zeros), and 0xF0 is 16 zeros. A value of size s is sent in s
   bits, with the negatives shifted: size 2 sends -3, -2, 2, 3 as 00,
   01, 10, 11:

     extend v s = if v < 2^(s-1) then v - 2^s + 1 else v

   The file is a series of markers, each FF then a byte:

     FF D8  SOI   start
     FF E0  APP0  JFIF (other APPn: Exif, ICC profiles, ...: skipped)
     FF DB  DQT   quantization tables (in zigzag order)
     FF C0  SOF0  baseline frame: size, components, sampling factors
     FF C4  DHT   Huffman tables: 16 counts, then the symbols (Huffman.mli)
     FF DD  DRI   a restart every n MCUs
     FF DA  SOS   start of scan: the Huffman-coded data follows
     FF D0-D7 RST restart: DC predictions reset, bits realigned
     FF D9  EOI   end

   Inside a scan a data byte FF is written FF 00 (byte stuffing), so no
   marker appears by accident. Restart markers let a decoder find its
   way again after corrupt data.

   What is read here:
   - baseline and extended sequential Huffman JPEGs (SOF0, SOF1) of
     8-bit samples, gray or YCbCr, with any sampling factors, any
     number of scans, and restart intervals;
   - progressive ones (SOF2, most of the web's photographs), which send
     the same blocks a part at a time, as Jpeg_progressive.mli tells;
     read it after this one.
   Refused, with a message saying so, are lossless, hierarchical and
   arithmetic-coded JPEGs, 12-bit samples, and CMYK (4 components).
   Adobe's RGB JPEGs (APP14) are read as YCbCr, since they are rare
   files.

   The Huffman codes are decoded a bit at a time (Huffman.mli). That is
   plenty for the playground's textures, and slow for a camera's 12
   megapixels.

   Where it stands in ix: under it are Dct (the transform), Huffman
   (from lib_compression, the same module that reads deflate's codes
   for Zlib: one idea, two formats), and Jpeg_progressive (a scan's
   part of a block). Over it are Image_file, for mini-page, mini-office
   and the browser, and Pdf_image: a photograph in a PDF file is a
   whole JPEG file in a stream (with the filter DCTDecode), which the
   PDF reader hands here as it is.

   design:
   One step loses, and it is one line. Of the encoder's stages only
   the quantization throws anything away (and the subsampling, when
   there is some). The colour change and the transform are exact but
   for rounding, and the zigzag, the runs and the Huffman codes are
   exact. So the whole question of how good and how big a file is
   comes down to a few tables of 64 numbers, written in the file. The
   rest of the standard is there to put the numbers that the eye
   misses least where those tables can zero them, and to put the zeros
   where the codes are short.

   others:
   This is what the blocks cost. At a low quality each 8 x 8 block is
   little more than its average, and the picture shows its grid; a
   sharp edge has ripples beside it, because the high frequencies it
   needed are gone. The video codecs that came after (H.264, 2003, and
   its followers) predict a block from its neighbours, take blocks of
   several sizes, and smooth the grid after decoding. The picture
   formats made from them (WebP from VP8, HEIF from HEVC, AVIF from
   AV1) store a video's single frame.

   why-win:
   Thirty years on, a camera, a telephone and a web page still write
   this format, though JPEG 2000 (wavelets, 2000) and the formats above
   all make a smaller file. The baseline was free of patents (the
   arithmetic coding, which was not, is the part nobody used); one free
   library read and wrote it everywhere from 1991; a chip decodes it in
   every device; and at the sizes at which people keep pictures, the
   gain of the others is not seen. These are the same reasons as for
   deflate (Zlib.mli).

   References: ITU-T Recommendation T.81 = ISO/IEC 10918-1, "Digital
   Compression and Coding of Continuous-Tone Still Images" (1992);
   Gregory Wallace, "The JPEG Still Picture Compression Standard",
   Communications of the ACM 34 (1991); Eric Hamilton, "JPEG File
   Interchange Format, Version 1.02" (C-Cube Microsystems, 1992);
   William Pennebaker and Joan Mitchell, JPEG Still Image Data
   Compression Standard (1993); Martin Fiedler's NanoJPEG, a baseline
   decoder in one short C file. *)
(* ix: copied from libs/graphics/images/jpeg/Jpeg.mli in the author's
 * playground (docs/plans/done/plan_pdf.md). The optional arguments of
 * decode must be given, in decode_with, and the upsampling is a
 * type. *)

(* how a colour plane smaller than the picture is made its size again
 * (ix: it is a type, where it was `Box and `Triangle) *)
type upsampling = Box | Triangle

(* [decode_with ~idct ~upsampling ~keep s] is the picture of the JPEG
 * file [s], its blocks inverse-transformed by [idct] and its color
 * upsampled by [upsampling]. Only the first [keep] coefficients of
 * each block, in zigzag order, are kept, and the others are made 0.
 * With 1 you get each block's average, a mosaic; with a dozen, most of
 * the picture, which is what quantization bets on; with 64, all of
 * them. It raises Failure on a corrupt file, or on one that uses what
 * is not read here.
 * (ix: the three were optional arguments of decode) *)
val decode_with : idct:(float array -> float array) -> upsampling:upsampling -> keep:int -> string -> Rgba_image.t

(* the same with the arguments' old defaults: Dct.idct_aan, Triangle,
 * 64 *)
val decode : string -> Rgba_image.t

(* [zigzag.(k)] is where the [k]th coefficient of the file goes in a
 * block, row by row: zigzag.(2) = 8, the first of the second row *)
val zigzag : int array

(* [extend v s] is the value that the [s] bits [v] stand for *)
val extend : int -> int -> int
