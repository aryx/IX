(* Printf's functions on .NET, in place of lib_core's (mini-ml -dotnet
 * compiles this right after Printf, its functions then Printf's: an
 * overlay, Lower_il.overlay). A format there is a function, the
 * compiler's of its literal: given k, the curried function of the
 * format's arguments, which gives k their text (F#'s way); so each
 * printf is the format applied to where the text goes:
 *
 *   Printf.printf "%d items\n"  ->  (fun k -> fun x -> k (... x ...))
 *                                     applied to print_string
 *
 * lib_core's Printf reads the format, a string, at run time and makes
 * its closures by Obj.magic, which .NET's typed delegates refuse. *)

val ksprintf : (string -> 'd) -> ('a, unit, string, 'd) format4 -> 'a
val sprintf : ('a, unit, string) format -> 'a
val printf : ('a, out_channel, unit) format -> 'a
val eprintf : ('a, out_channel, unit) format -> 'a
val fprintf : out_channel -> ('a, out_channel, unit) format -> 'a
val bprintf : Buffer.t -> ('a, Buffer.t, unit) format -> 'a

(* %a's and %t's text in a format compiled: sprintf's printer's string,
 * bprintf's on a buffer (fprintf's, on a channel, is refused: what it
 * writes cannot be taken) *)
val capture : (unit -> 'x -> string) -> 'x -> string
val capture_t : (unit -> string) -> string
val capture_buffer : (Buffer.t -> 'x -> unit) -> 'x -> string
val capture_buffer_t : (Buffer.t -> unit) -> string
