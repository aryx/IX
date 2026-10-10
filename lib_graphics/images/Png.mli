(* PNG: predict each pixel from its neighbors, then DEFLATE the
   differences.

   cs-history:
   PNG was designed in the open, fast, for a reason: at the end of 1994
   Unisys and CompuServe announced that software writing GIFs owed a
   license for GIF's LZW compression, patented. In January 1995 Thomas
   Boutell posted a draft of a replacement on Usenet; the group that
   formed around it named it PNG ("PNG's Not GIF", officially Portable
   Network Graphics) and fixed what GIF lacked while they were at it:
   true color, 16 bits a channel, a real alpha channel, a signature
   that detects broken transfers, a CRC a chunk, and patent-free
   compression, DEFLATE (Zlib.mli; the playground's Inflate.mli). A W3C
   Recommendation in 1996, among the consortium's first, RFC 2083 in
   1997, ISO/IEC 15948 in 2004; the third edition (2025) adds APNG,
   animated PNG, and HDR.

   The decoder's way, which the encoder goes backwards:

     the file -> chunks, each CRC checked -> the IDATs' data joined
       -> Zlib.inflate -> rows, each a filter's byte and its bytes
       -> the filter undone, with the row above -> (Adam7's seven
       small pictures put back in place) -> samples made red, green,
       blue and alpha by the color type (the palette, tRNS)
       -> Rgba_image

   The file (numbers big-endian, unlike GIF's):

     89 50 4E 47 0D 0A 1A 0A        the signature
     then chunks:  length(4) type(4) data(length) CRC-32(4) of type + data
       IHDR  width(4) height(4) bit depth(1) color type(1)
             compression 0, filter 0, interlace 0 or 1
       PLTE  the palette, 3 bytes a color (color type 3)
       tRNS  transparency: an alpha per palette entry, or the one gray
             or RGB value that is transparent
       IDAT  the pixels, compressed; several IDATs are one zlib stream
             (Zlib.mli), cut anywhere
       IEND  the end

   The signature is a small lesson in 1990s file transfers: 89 has the
   high bit set (a 7-bit link strips it), "PNG" for the humans, 0D 0A
   (CR LF) and 0A (LF) catch a transfer that converts line endings, 1A
   stops DOS's "type" from printing the rest. A chunk type starting with
   an upper-case letter is critical (a decoder must understand it),
   lower-case ancillary (gAMA, tEXt, ...: skip it) -- so old decoders
   read new files.

   Color types: 0 gray, 2 RGB, 3 palette, 4 gray + alpha, 6 RGBA; bit
   depths 1, 2, 4 (several pixels a byte), 8 and 16.

   The filters are PNG's real idea, before DEFLATE: each row starts with
   a byte choosing a *filter*, which replaced each byte x by its
   difference, mod 256, from a prediction made from its neighbors (the
   same channel of the pixel to the left, above, above-left):

       c  b
       a  x        0 None     x
                   1 Sub      x - a
                   2 Up       x - b
                   3 Average  x - floor ((a + b) / 2)
                   4 Paeth    x - (which of a, b, c is closest to a + b - c)

   On a gradient 10 20 30 40 50, Sub gives 10 10 10 10 10: DEFLATE sees
   one byte repeated instead of five different ones. Alan Paeth's
   predictor (1991) guesses the plane through the three neighbors, p = a
   + b - c, and takes the neighbor nearest to it (ties: a, then b, then
   c). The worked example:

     a = 100, b = 120, c = 90:  p = 130;  |p-a| = 30, |p-b| = 10,
     |p-c| = 40, so b = 120  (the values grow downward: up guesses best)

   Interlacing (Adam7, after Adam Costello, 1995): seven passes, each
   pixel of an 8 x 8 tile in the pass numbered below, each pass a small
   picture filtered and compressed on its own, so a browser drew a
   coarse picture after 1/64 of the data:

     1 6 4 6 2 6 4 6
     7 7 7 7 7 7 7 7
     5 6 5 6 5 6 5 6
     7 7 7 7 7 7 7 7
     3 6 4 6 3 6 4 6
     7 7 7 7 7 7 7 7
     5 6 5 6 5 6 5 6
     7 7 7 7 7 7 7 7

   Read here: every color type, bit depth and filter, Adam7, tRNS; each
   chunk's CRC checked. 16-bit channels keep their high byte; 1-, 2-
   and 4-bit gray is scaled to 0..255 (2-bit 3 is 255). Ignored, as
   most decoders do: color management (gAMA, cHRM, sRGB, iCCP),
   the background (bKGD), text, APNG's extra frames (the default image
   is shown).

   Where it stands in ix: under it, Zlib for the compression and for
   the CRC (by halves, an int of 31 bits on arm not holding one); the
   filters are the same five that a PDF's streams may have (Pdf_filter's
   predictors: PDF took them from here). Over it, Image_file, for
   mini-page, mini-office and the browser's pictures. [encode] has
   no caller yet but the tests, which read back what it wrote.

   cs-history:
   A format made by the net for the web, and the web took ten years
   to show it whole. Netscape and Internet Explorer read PNG from
   their fourth versions (1997), but Internet Explorer, to version 6,
   drew a picture's alpha channel as an opaque box: so the shadows and
   rounded corners of the 2000s were GIFs with one transparent
   colour, or PNGs behind a filter that only that browser knew, until
   version 7 (2006). And PNG never took GIF's other place: its
   authors left animation to a separate format, MNG, that no browser
   kept; Mozilla's APNG (2004, in Firefox 3 in 2008), a PNG with more
   frames in chunks an old decoder skips, was refused by the PNG
   group in 2007 and waited for Chrome until 2017, and for the
   standard until 2025. The animated GIF outlived the patent that PNG
   was made against (expired in 2003 and 2004).

   others:
   What came after for the same place, each a web format: WebP's
   lossless (PNG's filters grown, by block and with more guesses, and
   a compression that knows a symbol is a pixel; mini-chrome reads
   it, ix does not) and SVG (Svg.mli) for what is a drawing and not
   pixels. PNG stays what a screenshot, a diagram and an icon are
   saved as: every program reads it, and nothing is lost.

   design:
   Two stages that know nothing of each other. The filter knows what
   a picture is (a pixel is like its neighbours) and compresses
   nothing: it only makes the bytes small numbers and alike. DEFLATE
   knows nothing of pictures and compresses any bytes that repeat. A
   format made in a few months could take the second ready made, with
   its free library, and spend its design on the first. JPEG is cut
   the same way (a transform that knows the eye, then Huffman codes:
   Jpeg.mli), and so is every codec since.

   References: Portable Network Graphics (PNG) Specification (W3C,
   second edition 2003 = ISO/IEC 15948); Alan Paeth, "Image File
   Compression Made Easy", in Graphics Gems II (1991); Greg Roelofs,
   PNG: The Definitive Guide (O'Reilly, 1999). *)
(* ix: the author's playground's libs/graphics/images/png/Png.mli; encode's alpha and filter are said, where they were optional (true, none) (docs/plans/plan_pdf.md) *)

(* the 8 bytes every PNG file starts with *)
val signature : string

(* [decode s]: the picture of the PNG file [s]. Raises Failure on
 * anything wrong with it (the signature, a CRC, the compressed data, an
 * unknown critical chunk, a palette index out of the palette, ...). *)
val decode : string -> Rgba_image.t

(* [scanlines s]: the rows of a non-interlaced PNG [s] as the file holds
 * them once inflated: each one's filter (0 to 4) and its filtered
 * bytes, the differences from the predictions -- what DEFLATE
 * compressed (examples/ImagePng.ml draws them). Raises Failure on an
 * interlaced or corrupt file. *)
val scanlines : string -> (int * Bytes.t) list

(* [encode ~alpha ~filter img]: a PNG file of [img], RGBA (color type 6), or RGB
 * (2) with [~alpha:false], its alpha dropped; 8 bits, not interlaced.
 * Each row gets the filter whose output, read as signed bytes, sums
 * the smallest (the heuristic the PNG specification suggests, section
 * 12.8), or [filter] (0 to 4) on every row, then Zlib.deflate. *)
val encode : alpha:bool -> filter:int option -> Rgba_image.t -> string

(* [chunks s]: the chunks of [s], (type, data), up to IEND, their CRCs
 * checked *)
val chunks : string -> (string * string) list

(* [paeth a b c]: Paeth's prediction, from left, up and up-left *)
val paeth : int -> int -> int -> int
