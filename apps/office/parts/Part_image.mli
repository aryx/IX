(* A picture from a file (PNG, JPEG), as a part of a compound
 * document: shown at the size its frame gives it (it has a natural
 * size, a unit a pixel, and is scaled as any such part:
 * Component.draw_in), turned by quarter turns from its Image menu.
 *
 * It saves the file's bytes, not its pixels: a document carries a
 * photograph at its JPEG's size, where its pixels are four bytes
 * each. Nothing is painted on it: Part_picture is the picture one
 * draws. (docs/plans/plan_office.md, stage 7)
 *
 * What is saved is a digit, the quarter turns, then the file as it
 * was read. Keeping the file has a second reason for a JPEG: its
 * compression loses detail each time it is done, so a document that
 * decoded a photograph and wrote it again at each Save would wear
 * it out. Here it is decoded on Open and never encoded.
 *
 * The file's way: File_menu.choose lists the stored files that end
 * as a picture's do, Office_edit.insert_image gives the bytes to
 * [make], Image_file (lib_graphics) says by their first bytes which
 * of Png and Jpeg reads them, and the result is an Rgba_image that
 * the part hands to the platform as one shape (Playground's bitmap).
 *
 * design:
 * A turn makes a new picture, its pixels moved ([turned]), and does
 * not ask the platform to draw the old one rotated, which Playground
 * can say. One platform makes that hard: Plan 9's draw device copies
 * a rectangle of an image as it is, and neither scales nor turns it,
 * so the platform over it has to make the pixels shown itself. An
 * upright picture is what every platform shows the same way, so the
 * part gives them that, and makes it once, not at each frame: the
 * picture shown is the same value until the next turn, and a
 * platform that kept what it made of it finds it again. *)

val kind : string

(* [make bytes]: the part of a file's bytes; Failure, as
 * Image_file.decode, if they are no picture read here *)
val make : string -> Component.part

(* a saved part read back; a placeholder if its bytes are no picture
 * read here (they are kept and saved back) *)
val load : string -> Component.part

(* a picture turned a quarter turn to the right (of the clock's hands) *)
val turned : Rgba_image.t -> Rgba_image.t
