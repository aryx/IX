(* Doc_image: a picture from a file, as a block of a document -- what
 * Markdown's ![words](file) and LaTeX's \includegraphics{file} are.
 *
 * The file is a PNG, a JPEG or a GIF, told by its first bytes
 * (Image_file); its pixels are read here, once, and the document has
 * them: a PDF file carries them, a terminal has the file's name in
 * their place. Not a drawing: an SVG file is said and not read
 * (lib_graphics's Svg draws no text, and a diagram is boxes with
 * words in them), nor a PDF file.
 *
 * How big it is shown is the reader's to say, a width in inches; with
 * none, a pixel is a point's part ([per_inch] pixels to the inch: 72
 * for LaTeX, as pdflatex takes a picture that says nothing; 96 for
 * Markdown, a screen's), and never wider than the line. Its height
 * follows. *)

(* [picture name bytes wide per_inch most]: the block, or why not (not
 * a picture's file, or one cut short). [wide]: the width asked, in
 * inches, 0 for the picture's own; [most]: the line's *)
val picture : string -> string -> float -> float -> float -> (Doc.block, string) result
