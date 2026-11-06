(* Chan, lib_core/commons/'s subset (see Stdlib.mli): a channel with
 * where it comes from, or goes (xix's Chan), what
 * TinyLibSystem.with_open_in and with_open_out give. The channel alone
 * cannot say its file, and an error is said by one: a program given a
 * Chan.i writes "foo.tm:3: unknown instruction", or "<stdin>:3", with
 * nothing more passed along *)

type origin =
  | File of Fpath.t
  | Stdin
  | String
  | Channel
  | Network

type destination =
  | OutFile of Fpath.t
  | Stdout

type i = { ic : in_channel; origin : origin }

type o = { oc : out_channel; dest : destination }

(* where the channel comes from, or goes, for a message: "foo.c",
 * "<stdin>", "<stdout>" *)
val origin : i -> string
val destination : o -> string
