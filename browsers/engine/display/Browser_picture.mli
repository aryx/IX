(* Browser_picture: a page's picture, as a browser keeps it (waiting
 * for its turn, arrived and decoded, or not to be had), and its bytes
 * decoded by what they say they are.
 *
 * The first bytes of a file tell its format better than a server's
 * Content-Type does (a .gif served as text/plain still starts with
 * GIF8). They are the formats' magic numbers, which [decode] reads.
 *
 *   GIF8      GIF (1987)
 *   \x89PNG   PNG (1996)
 *   \xFF\xD8  JPEG (1992)
 *   <svg      SVG (2001), which is text (perhaps after <?xml ...?>);
 *             it is drawn at its own size into pixels
 *             (lib_graphics/svg's Svg)
 *
 * They are decoded by our own readers (lib_graphics/images/: Gif, Png,
 * Jpeg; lib_graphics/svg/: Svg), which are pure OCaml, so a browser
 * running in a browser decodes them too.
 *
 * In the system: a picture's bytes come by Http_client like the page's
 * (Tab asks for each <img> once the page is laid out). They are decoded
 * here by lib_graphics' readers (Image_file for PNG and JPEG, Gif,
 * Svg), and the layout is done again now that the size is known. So
 * the text of a page that did not give its pictures' width= and height=
 * jumps as they come, in every browser. PNG's pixels are compressed by
 * deflate (Zlib.mli), GIF's by LZW (Lzw.mli), and JPEG's are Huffman's
 * codes over a cosine transform (Huffman.mli, Dct). So three of the
 * four modules of lib_compression are needed to show one page.
 *
 * cs-history:
 * Pictures in the page were Mosaic's doing. Marc Andreessen proposed
 * <img> on the www-talk list in February 1993 and shipped it, while
 * the list was still discussing something more general. Mosaic read
 * GIF (CompuServe, 1987) and X bitmaps. GIF's compression, LZW, turned
 * out to be patented, and when Unisys asked for royalties at the end
 * of 1994, a group on Usenet designed a free replacement in a few
 * weeks: PNG ("PNG's Not GIF"; a W3C Recommendation, 1996). JPEG
 * (1992) was made for photographs from the start. SVG (2001) is the
 * one that is not pixels; it waited ten years for Internet Explorer.
 * Since then came WebP (Google, 2010) and AVIF (2019), each the still
 * frame of a video codec; neither is read here. *)

type t = Waiting | Arrived of Rgba_image.t | Broken

(* the bytes decoded: Arrived, or Broken for what is none of the four
 * or does not decode *)
val decode : string -> t

(* the size taken by a picture that could not be had: the broken
 * image's size *)
val broken_size : float

(* the picture's size for the layout, once it is known: the size of its
 * pixels, or of the broken image *)
val size : t -> (float * float) option
