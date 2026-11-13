(* A progressive JPEG sends the same picture in several passes, each
   sharpening the one before.

   A baseline file (Jpeg.mli) sends each block whole, one after the
   other, so a picture arriving slowly is drawn from the top, a strip
   at a time. A progressive one sends every block a little at a time,
   in passes over the whole picture called scans. A first scan gives
   every block's average, and the picture is there at once, in large
   squares; the next scans add detail everywhere. The standard has had
   it from the start (ITU-T T.81, 1992, Annex G), with two ways to cut
   a block's 64 coefficients into passes, which are used together:

     spectral selection          a scan carries the coefficients from
                                 Ss to Se only, in zigzag order: 0
                                 alone (the DC), then 1 to 5, 6 to 63...
     successive approximation    a scan carries them without their Al
                                 lowest bits; later scans add one bit
                                 each (Ah is the bit the scan before
                                 stopped at)

   So a scan is one of four kinds, told by its header (Ss, Se, Ah, Al):

     DC, first      Ss = 0, Ah = 0   each block's DC coefficient, as in
                                     baseline (a difference from the
                                     block before), shifted left by Al
     DC, refining   Ss = 0, Ah > 0   one bit a block: its bit Al
     AC, first      Ss > 0, Ah = 0   runs of zeros and values, as in
                                     baseline, between Ss and Se; and
                                     a run of blocks with nothing more
                                     in the band (below)
     AC, refining   Ss > 0, Ah > 0   one more bit for each coefficient
                                     already not zero, and the ones
                                     that become so (+1 or -1 at bit
                                     Al), found by runs of zeros

   An AC scan has one component (a DC scan may carry the three,
   interleaved as in baseline). What baseline's end-of-block says of
   one block, an AC scan can say of many. The symbols 0x00, 0x10...
   0xE0 are EOB0 to EOB14, and they say "this block and the 2^r - 1 +
   (r more bits) blocks after it have nothing more in this band" (the
   end-of-band run). High frequencies are zero in most blocks, so a
   scan of them is mostly such runs.

   The refining AC scan is the subtle one. The decoder can tell a
   coefficient that is zero so far from one that is not (it has the
   earlier scans), so their bits are mixed in one stream. A symbol
   (r, 1) says "r coefficients are still zero, then one becomes +1 or
   -1 (a sign bit follows)", and *between* them, each coefficient that
   is already not zero is passed with one bit, its correction. So the
   run counts only the zeros, and the bits of the others come as they
   are met. An end-of-band run does the same up to the end of the
   band, where only corrections are left.

   The decoder therefore keeps every block's coefficients (integers,
   in zigzag order) until the last scan. Only then does it do what
   baseline does at each block: multiply by the quantization table,
   and apply the inverse transform (Dct). That part is in Jpeg; this
   module is one function, which reads a block's part of a scan.

   cs-history:
   It was made for pictures looked at as they come over a slow line,
   the telephone's in 1992, then the web's modems: a progressive
   picture could be judged at a tenth of its bytes. The Independent
   JPEG Group's library wrote them from its version 6 (1995). They
   came back twenty years later for another reason: the scans compress
   a little better than baseline's blocks (the zeros of a band are
   together), and Mozilla's mozjpeg (2014) makes every JPEG
   progressive for that. Today many of the web's photographs are
   progressive.

   others:
   The same wish, a picture that is there at once and then sharpens,
   was answered in three ways. GIF's interlacing (Gif.mli) sends the
   rows out of order, an eighth of them first, so the picture is
   stripes that get filled in. PNG's Adam7 (Png.mli) sends seven small
   pictures, the first being one pixel of each 8 x 8 square. Both
   reorder pixels, and both cost bytes, because a pixel is far from its
   neighbours in the early passes. JPEG orders by frequency, not by
   place: the first scan is already the whole picture, blurred, and
   the file is no bigger for it.

   Reference: ITU-T Recommendation T.81 (1992), Annex G. Its figures
   G.3 to G.9 are the encoder's procedures with Huffman codes, which
   the function below runs backwards, because the standard draws none
   for the decoder (its section G.2 says so). *)
(* ix: copied from libs/graphics/images/jpeg/Jpeg_progressive.mli in
 * the author's playground (docs/plans/done/plan_pdf.md). The four
 * readers of block are one record (source), so it has 6 parameters
 * where it had 9, because mini-ml's arm code takes 7 at most. *)

(* a scan's header: the band (its first and last coefficient, in
 * zigzag order), and the bits. [ah] is 0 for a first scan, and else
 * the bit the coefficients were known down to; [al] is the bit this
 * scan gives. *)
type scan = { ss : int; se : int; ah : int; al : int }

(* what a block is read with: [bit], [receive] (which reads n bits as
 * a number), and the scan's Huffman tables, given when asked (ix: they
 * are a record, where they were four of block's parameters) *)
type source = { bit : unit -> int; receive : int -> int; dc : unit -> Huffman.t; ac : unit -> Huffman.t }

(* [block scan from ~pred ~run coefs at] reads one block's part of the
 * scan from [from], into [coefs] from index [at] (64 integers, in
 * zigzag order). [pred] is the component's DC so far, and [run] is the
 * number of blocks still to skip in an end-of-band run. The caller
 * keeps both and sets them to 0 at a scan's start and at a restart
 * marker. *)
val block : scan -> source -> pred:int ref -> run:int ref -> int array -> int -> unit
