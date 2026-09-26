(* '#|', the pipes (principia's devpipe.c): an attach makes a pipe, a
 * directory of two files, data and data1: what is written on one is
 * read on the other, a stream of up to 32KB each way; a reader waits for
 * data, a writer for room; once an end is closed, the other end's
 * reader gets the end of file, its writer an error. *)

(* the device registered *)
val init : unit -> unit
