(* Image_file reads a picture's file, whatever its format. The format is
 * told by the file's first bytes and not by its name (a PNG starts
 * with "\137PNG", a JPEG with FF D8). mini-office (Insert > Image...)
 * and mini-page call it.
 *
 *     the first bytes              the format       its reader
 *     89 50 4E 47 0D 0A 1A 0A      PNG              Png
 *     FF D8                        JPEG             Jpeg
 *     47 49 46 38 (GIF8)           GIF              Gif    the browser's
 *     text with <svg in it         SVG              Svg    Browser_picture
 *                                                          asks these two
 *
 * Each reader gives an Rgba_image, so whoever shows the picture never
 * knows what the file was.
 *
 * design:
 * The format is told by the bytes, not by the name. A name's ending is
 * a promise that nobody checks: a .jpg that is a PNG is common, a
 * download has the name its link gave it, and Plan 9 and Unix have no
 * rule that a name must end in anything. So a format's designers put a
 * few fixed bytes first (a magic number; Png.mli tells how PNG's eight
 * were chosen with care), and file(1) has told what a file is by them
 * since the Unix of the 1970s. A browser does the same with a picture,
 * instead of trusting what the server says it is (Browser_picture). *)

(* the endings that the names of such files have, to list them: ".png",
 * ".jpg", ".jpeg" *)
val extensions : string list

(* whether the bytes are in a format read here *)
val known : string -> bool

(* the picture. It raises Failure saying why not: the bytes are in
 * neither format, or the file's reader refuses it. *)
val decode : string -> Rgba_image.t
