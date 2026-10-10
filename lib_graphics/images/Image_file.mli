(* Image_file: a picture's file read, whatever its format -- which is
 * said by the file's first bytes and not by its name (a PNG starts
 * with "\137PNG", a JPEG with FF D8). What mini-office (Insert >
 * Image...) and mini-page call. *)

(* the endings of the names such files have, to list them: ".png",
 * ".jpg", ".jpeg" *)
val extensions : string list

(* is it a format read here? *)
val known : string -> bool

(* the picture; Failure with why not: neither format, or a file of one
 * that its reader refuses *)
val decode : string -> Rgba_image.t
