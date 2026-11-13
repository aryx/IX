(* ix: a channel together with where it comes from, or where it goes
 * (xix's Chan). FS.with_open_in gives one. A channel alone cannot
 * tell which file it is on, and an error message needs to say it. A
 * lexer that has only an in_channel writes "line 3: syntax error";
 * one that has a Chan.i writes "foo.c:3: syntax error", or
 * "<stdin>:3" for a pipe, and nothing more has to be passed along. *)

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

(* human readable origin of an input channel (e.g., "foo.c" or "<stdin>") *)
val origin: i -> string

(* human readable destination of an output channel (e.g., "foo.c" or
 * "<stdout>") *)
val destination: o -> string
