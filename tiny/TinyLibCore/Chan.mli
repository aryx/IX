(* Chan, lib_core/commons/'s subset (see Stdlib.mli): a channel with
 * where it comes from (xix's Chan), what TinyLibSystem.with_open_in
 * gives. The channel alone cannot say its file, and an error is said
 * by one: a program given a Chan.i writes "foo.tm:3: unknown
 * instruction", or "<stdin>:3", with nothing more passed along. The
 * output's half, o, is left out: tiny programs write a file whole
 * (TinyLibSystem.write_file) *)

type origin =
  | File of Fpath.t
  | Stdin
  | String
  | Channel
  | Network

type i = { ic : in_channel; origin : origin }

(* where the channel comes from, for a message: "foo.c", "<stdin>" *)
val origin : i -> string
