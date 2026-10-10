(* A picture from a file (PNG, JPEG), as a part of a compound
 * document: shown at the size its frame gives it (it has a natural
 * size, a unit a pixel, and is scaled as any such part:
 * Component.draw_in), turned by quarter turns from its Image menu.
 *
 * It saves the file's bytes, not its pixels: a document carries a
 * photograph at its JPEG's size, where its pixels are four bytes
 * each. Nothing is painted on it: Part_picture is the picture one
 * draws. (docs/plans/plan_office.md, stage 7) *)

val kind : string

(* [make bytes]: the part of a file's bytes; Failure, as
 * Image_file.decode, if they are no picture read here *)
val make : string -> Component.part

(* a saved part read back; a placeholder if its bytes are no picture
 * read here (they are kept and saved back) *)
val load : string -> Component.part

(* a picture turned a quarter turn to the right (of the clock's hands) *)
val turned : Rgba_image.t -> Rgba_image.t
