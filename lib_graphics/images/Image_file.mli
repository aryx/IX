(* Image_file: a picture's file read, whatever its format -- which is
 * said by the file's first bytes and not by its name (a PNG starts
 * with "\137PNG", a JPEG with FF D8). What mini-office (Insert >
 * Image...) and mini-page call.
 *
 *     the first bytes              the format       its reader
 *     89 50 4E 47 0D 0A 1A 0A      PNG              Png
 *     FF D8                        JPEG             Jpeg
 *     47 49 46 38 (GIF8)           GIF              Gif    the browser's
 *     text with <svg in it         SVG              Svg    Browser_picture
 *                                                          asks these two
 *
 * and each gives an Rgba_image, so whoever shows the picture never
 * knows what the file was.
 *
 * design:
 * By its bytes, not by its name. A name's ending is a promise that
 * nobody checks: a .jpg that is a PNG is common, a download has the
 * name its link gave it, and Plan 9 and Unix have no rule that a
 * name end in anything. So a format's designers put a few fixed
 * bytes first (a magic number; PNG's eight are chosen with care:
 * Png.mli), and file(1) has told what a file is by them since the
 * Unix of the 1970s. A browser does the same to a picture, against
 * what the server says of it: Browser_picture. *)

(* the endings of the names such files have, to list them: ".png",
 * ".jpg", ".jpeg" *)
val extensions : string list

(* is it a format read here? *)
val known : string -> bool

(* the picture; Failure with why not: neither format, or a file of one
 * that its reader refuses *)
val decode : string -> Rgba_image.t
