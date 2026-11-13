(* Doc_image: a picture from a file, as a block of a document. This is
 * what Markdown's ![words](file) and LaTeX's \includegraphics{file}
 * become.
 *
 * The file is a PNG, a JPEG or a GIF, recognized by its first bytes
 * (Image_file). Its pixels are read here, once, and the document keeps
 * them: a PDF file carries them, and a terminal shows the file's name
 * in their place. A drawing is not read: an SVG file is reported and
 * not read (lib_graphics's Svg draws no text, and a diagram is boxes
 * with words in them), and neither is a PDF file.
 *
 * The reader says how big the picture is shown, as a width in inches.
 * When it says nothing, the picture is shown at [per_inch] pixels to
 * the inch: 72 for LaTeX (a pixel is a point, as pdflatex takes a
 * picture that says nothing), and 96 for Markdown (a screen's). It is
 * never wider than the line. Its height follows from its width. *)

(* [picture name bytes wide per_inch most] returns the block, or why it
 * could not be made (not a picture's file, or one cut short). [wide]
 * is the width asked for, in inches, or 0 for the picture's own;
 * [most] is the line's width. *)
val picture : string -> string -> float -> float -> float -> (Doc.block, string) result
