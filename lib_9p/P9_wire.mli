(* 9P2000's messages on the wire (principia's convS2M and convM2S, and
 * convD2M, convM2D for a file's entry): the size (4 bytes, itself
 * counted), the type (1), the tag (2), then the type's fields, numbers
 * the low byte first, a string its length (2) and its bytes. *)

(* a message's bytes *)
val encode : P9.message -> string

(* a message from its bytes (the size first); Failure when malformed *)
val decode : string -> P9.message

(* the next message's bytes from a descriptor (a pipe, a connection):
 * its size read, then the rest; None at the end *)
val read : Unix.file_descr -> string option

(* a file's entry as a read of a directory gives it, and as Stat's *)
val encode_dir : Sys_plan9.dir -> string
