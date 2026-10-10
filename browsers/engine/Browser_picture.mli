(* Browser_picture: a page's picture, as a browser keeps it -- waiting
 * for its turn, arrived and decoded, or not to be had -- and its bytes
 * decoded by what they say they are.
 *
 * The first bytes of a file say its format better than a server's
 * Content-Type does (a .gif served as text/plain still starts with
 * GIF8): the formats' magic numbers, as TinyMediaPlayer's Media.sniff
 * reads them for every format.
 *
 *   GIF8      GIF (1987)
 *   \x89PNG   PNG (1996)
 *   \xFF\xD8  JPEG (1992)
 *   <svg      SVG (2001), text (after <?xml ...?> perhaps): drawn at its
 *             own size into pixels (graphics/images/svg's Svg)
 *
 * Decoded by our own readers (graphics/images/: Gif, Png, Jpeg, Svg), pure
 * OCaml, so a browser running in a browser decodes them too.
 *
 * In the system: a picture's bytes come by Http_client like the
 * page's (Tab asks for each <img> once the page is laid out), are
 * decoded here by lib_graphics' readers (Image_file for PNG and
 * JPEG, Gif, Svg), and the layout is done again with the size now
 * known: the text of a page that did not say its pictures' width=
 * and height= jumps as they come, in every browser. PNG's pixels are
 * deflate's (Zlib.mli), GIF's are LZW's (Lzw.mli), JPEG's are
 * Huffman's codes over a cosine transform (Huffman.mli, Dct): three
 * of lib_compression's four modules are needed to show one page.
 *
 * cs-history:
 * Pictures in the page were Mosaic's doing: Marc Andreessen proposed
 * <img> on the www-talk list in February 1993 and shipped it, while
 * the list was still discussing something more general. Mosaic
 * read GIF (CompuServe, 1987) and X bitmaps. GIF's compression, LZW,
 * turned out to be patented, and when Unisys asked for royalties at
 * the end of 1994 a group on Usenet designed a free replacement in a
 * few weeks: PNG ("PNG's Not GIF"; a W3C Recommendation, 1996). JPEG
 * (1992) was for photographs from the start. SVG (2001) is the one
 * that is not pixels; it waited ten years for Internet Explorer.
 * Since: WebP (Google, 2010) and AVIF (2019), each a video codec's
 * still frame; neither is read here. *)

type t = Waiting | Arrived of Rgba_image.t | Broken

(* the bytes decoded: Arrived, or Broken for what is none of the three
 * or does not decode *)
val decode : string -> t

(* the size a picture that could not be had takes: the broken image's *)
val broken_size : float

(* its size, for the layout, once known: its pixels', or the broken
 * image's *)
val size : t -> (float * float) option
