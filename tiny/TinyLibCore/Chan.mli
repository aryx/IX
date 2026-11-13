(* Chan: a subset of lib_core/commons/'s module (see Stdlib.mli), which
 * comes from xix's Chan. A Chan is a channel together with where it
 * comes from, or where it goes, and it is what
 * TinyLibSystem.with_open_in and with_open_out give. A channel alone
 * cannot say what its file is, so an error message needs a Chan. A
 * program given a Chan.i can write "foo.s:3: unknown instruction", or
 * "<stdin>:3", with nothing more passed along. *)

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

(* where the channel comes from, or where it goes, as a message says it:
 * "foo.c", "<stdin>", "<stdout>" *)
val origin : i -> string
val destination : o -> string
