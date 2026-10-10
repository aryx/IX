(* The tests' files: a file of data/ read, by the reader Test.ml sets
 * from its capabilities *)

val reader : (string -> string) ref

(* [read "tex.pdf"]: the bytes of data/tex.pdf *)
val read : string -> string

(* [away fb img]: how far a picture of the reader's is from the
 * screen's of the same thing: the mean difference of their greys, 0
 * to 255, each averaged over squares of 4 pixels (two renderers do not
 * smooth an edge alike); 1000. if their sizes differ by more than a
 * pixel *)
val away : Framebuffer.t -> Rgba_image.t -> float
