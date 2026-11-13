(* Pdf_image paints a picture in a page: it reads rows of samples as
   colours and paints them in a unit square.

   A picture is a stream with a width, a height, a colour space
   (Pdf_color), a number of bits a component (1, 2, 4, 8 or 16), and
   the samples, row after row from the top, each row starting on a
   byte. It has no place and no size of its own. It fills the square
   from (0, 0) to (1, 1), and the page's transform at that moment says
   where that square is. "200 0 0 150 50 400 cm /Im1 Do" draws the
   picture 200 points wide and 150 high, with its corner at (50, 400).

   A picture can also be one of three more things:

     a stencil   (/ImageMask) has one bit a sample, which says where
                 to pour the current colour. A scanned page's black
                 and a bitmap font's letters are stencils.
     with an /SMask   it has a second, grey picture, which says how
                 opaque each sample is. A photograph with soft edges
                 is one.
     a JPEG      (/DCTDecode) the stream is a JPEG file, a file inside
                 the file, decoded by Jpeg (Jpeg.mli)

   A small picture (a Type 3 font's glyph) may also be written in the
   content itself, between BI and EI.

   JPEG 2000 (JPXDecode) and the fax compressions (CCITTFax, JBIG2)
   are not decoded: a grey box is drawn where the picture is.

   Reference: ISO 32000-1:2008, section 8.9. *)
(* ix: from mini-chrome's libs/pdf/Pdf_image.mli. paint's canvas and clip
 * are a pair, and its fill, alpha and shown are a triple, because
 * mini-ml's arm code takes 7 parameters at most
 * (docs/plans/done/plan_pdf.md) *)

(* [paint pdf (canvas, clip) ctm ~resources (fill, alpha, shown)
 * dictionary bytes] paints the picture in its unit square under [ctm],
 * and a stencil in [fill]. When [shown] is false (the rendering
 * without pictures), it paints a grey box instead, except for a
 * stencil *)
val paint : Pdf.t -> Pdf_canvas.t * Pdf_canvas.clip -> Affine.t -> resources:Pdf_object.t -> Pdf_color.rgb * float * bool -> Pdf_object.dict -> string -> unit
