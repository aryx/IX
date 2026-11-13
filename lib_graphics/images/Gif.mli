(* GIF has 256 colors, LZW compression, and animation as an
   afterthought.

   CompuServe, the online service, needed pictures that its members'
   different computers could all show over slow modems. That was
   GIF87a (June 1987, by Steve Wilhite's team): a palette of up to 256
   colors, the pixels compressed by LZW (Lzw.mli), and rows interlaced
   so that a modem showed a blurry picture first. GIF89a (1989) added
   the graphic control extension (a transparent color, a delay, a
   disposal), meant for slideshows. Netscape Navigator 2.0 (1995) added
   the looping extension, and the animated GIF became the web's
   animation format for the next thirty years (elm-lang.org's Mario
   included).

   This is the file (its numbers are little-endian, unlike PNG's):

     "GIF89a"                        or "GIF87a"
     logical screen                  width(2) height(2) flags(1)
                                     background(1) aspect(1)
     [global palette]                3 * 2^(1 + (flags land 7)) bytes,
                                     if flags land 0x80
     blocks, each starting with a byte:
       0x21 0xF9  graphic control, for the next frame: 04 packed(1)
                  delay(2, in 1/100 s) transparent index(1) 00;
                  packed = disposal (bits 2-4), transparent? (bit 0)
       0x21 ...   other extensions (comments, NETSCAPE2.0's looping,
                  ...): skipped
       0x2C       a frame: x(2) y(2) width(2) height(2) flags(1)
                  [local palette] (same rule; flags land 0x40:
                  interlaced) min_code_size(1) sub-blocks of LZW data
       0x3B       the end
     sub-blocks: (a size byte, that many bytes) until a size of 0

   The pixels are indices into a palette, so a GIF photograph has to
   choose its 256 colors, and a sprite never notices. One index may be
   transparent, fully: there is no half-opacity (PNG's alpha is what
   GIF lacked).

   A frame is often a patch, not a full picture. mario/walk/left.gif is
   35 x 35; its first frame is full, and the next seven are 16 x 26 or
   so, at an offset, holding what changes around Mario's body:

          0         9                  25       35
        0 +-----------------------------------+
          |          full picture (35x35)     |
        5 |         +----------------+        |
          |         |  frame 2 patch |        |
          |         |   (16x26)      |        |
       31 |         +----------------+        |
       35 +-----------------------------------+

   Each patch is drawn over the picture so far (its transparent pixels
   let the picture show through) and shown for its delay. Then it is
   *disposed of* before the next one: it is left there (0, 1), cleared
   to transparent (2; the spec says "to the background color", but
   browsers clear it), or the picture is put back as it was before the
   patch (3). So [animation] keeps a canvas of the screen's size, draws
   each patch on it, and takes a snapshot of it: one full picture a
   frame.

   Delays are in 1/100 s, and old GIFs (Mario's among them) say 0,
   which taken literally means "as fast as possible". Browsers make a
   delay of 0 or 1 a tenth of a second, and so do we, so that the
   native version looks like the web one.

   Interlacing stores a frame's rows in four passes: every 8th row from
   row 0, every 8th from row 4, every 4th from row 2, and every 2nd
   from row 1.

   What is not read: the background color and the pixel aspect ratio
   (as in browsers), the loop count (animations loop forever, as
   browsers do), and the text and plain-text extensions. A palette
   index past the end of the palette is black. A file missing its
   final 0x3B is accepted, as browsers do.

   Where it stands in ix: under it is Lzw, with GIF's variant of the
   codes (in lib_compression; Lzw.mli has the dictionary worked out and
   the patent's story, and a PDF's old streams have the other variant,
   in Pdf_filter). Over it is the browser alone (Browser_picture, which
   shows the first frame). Image_file does not read GIFs, because no
   one writes a new picture as one.

   modern:
   The word outlived the format. What a site calls a GIF today is
   mostly a short video without sound (H.264 in an MP4 file, or
   WebM), made from the uploaded GIF and much smaller: 256 colours a
   frame and LZW over patches are a poor way to store a film. The
   file format stays for what it was made for, small pictures of few
   colours, and because everything reads it.

   References: CompuServe, "Graphics Interchange Format, Version 89a"
   (1990); Terry Welch, "A Technique for High-Performance Data
   Compression", IEEE Computer 17 (1984). *)
(* ix: copied from libs/graphics/images/gif/Gif.mli in the author's
 * playground (docs/plans/plan_browser.md) *)

(* a frame, before composition: a patch of the picture *)
type frame = {
  x : int;
  y : int;
  (* the patch's pixels, with the transparent index given alpha 0 *)
  patch : Rgba_image.t;
  (* in seconds *)
  delay : float;
  (* 0 or 1 leave the patch, 2 clears it, 3 restores what was there *)
  disposal : int;
  (* what the patch was decoded from: its palette (3 bytes a color, its
   * own or the global one), and its LZW data with the sub-blocks
   * joined (for Lzw.steps) *)
  palette : string;
  min_code_size : int;
  lzw : string;
}

(* [frames s] is the logical screen's size and the frames of the GIF
 * file [s]. It raises Failure if [s] is not a GIF, or is a corrupt
 * one. *)
val frames : string -> (int * int) * frame list

(* [animation s] is the full pictures of the GIF file [s], composed as
 * a browser does, each with its delay in seconds *)
val animation : string -> (Rgba_image.t * float) list

(* [decode s] is the first full picture of [s], which is what a still
 * viewer shows *)
val decode : string -> Rgba_image.t
