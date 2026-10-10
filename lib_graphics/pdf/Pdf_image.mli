(* Pdf_image: a picture in a page -- rows of samples, read as colours
   and painted in a unit square.

   A picture is a stream: a width, a height, a colour space
   (Pdf_color), bits a component (1, 2, 4, 8 or 16), and the samples,
   row after row from the top, each row starting on a byte. It has no
   place and no size of its own: it fills the square from (0, 0) to
   (1, 1), and the page's transform at that moment says where that
   square is -- "200 0 0 150 50 400 cm /Im1 Do" is the picture 200
   points wide and 150 high, its corner at (50, 400).

   Three more things a picture can be:

     a stencil   (/ImageMask) one bit a sample: where to pour the
                 current colour. A scanned page's black; a bitmap
                 font's letters
     with an /SMask   a second, grey picture: how opaque each sample
                 is. A photograph with soft edges
     a JPEG      (/DCTDecode) the stream is a JPEG file: decoded by
                 Jpeg (Jpeg.mli), a file inside the file

   and it may be written in the content itself, between BI and EI,
   for small ones (a Type 3 font's glyphs).

   Not decoded: JPEG 2000 (JPXDecode), fax's compressions (CCITTFax,
   JBIG2) -- a grey box where the picture is.

   Reference: ISO 32000-1:2008, section 8.9. *)
(* ix: mini-chrome's libs/pdf/Pdf_image.mli; paint's canvas and clip are a pair and its fill, alpha and shown a triple (mini-ml's arm code takes 7 parameters at most) (docs/plans/plan_pdf.md) *)

(* [paint pdf (canvas, clip) ctm ~resources (fill, alpha, shown)
 * dictionary bytes]: the picture in its unit square under [ctm]; a
 * stencil in [fill]. Not [shown] (the rendering without pictures): a
 * grey box, but for a stencil *)
val paint : Pdf.t -> Pdf_canvas.t * Pdf_canvas.clip -> Affine.t -> resources:Pdf_object.t -> Pdf_color.rgb * float * bool -> Pdf_object.dict -> string -> unit
