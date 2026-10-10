(* TinyLib: lib_core/commons/Chan, the part the tiny programs call (tiny/TinyLib/README.md)
 *
 * A channel with where it comes from, or goes (xix's Chan). The
 * channel alone cannot say its file, and an error is said by one: a
 * lexer that has only an in_channel writes "line 3: syntax error", one
 * that has a Chan.i writes "foo.c:3: syntax error", or "<stdin>:3" for
 * a pipe, with nothing more passed along. Kept whole here though no
 * tiny program names it yet (the README says why). *)

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

(* human readable dest of an output channel (e.g., "foo.c" or "<stdout>") *)
val destination: o -> string
