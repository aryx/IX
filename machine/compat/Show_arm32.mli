(* An instruction as binutils' objdump prints it (2.42), aliases and
 * all: what the decoder is tested against (machine/tests: every word
 * decoded and printed by the two), and mini-5i -t's trace. Kept apart:
 * the machine runs the same without it. *)

(* [print ~addr i]: addr, the instruction's own, for a branch's target *)
val print : addr:int -> Arm32.t -> string
