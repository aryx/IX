(* A minor mode: the parenthesis, bracket or brace that matches the
 * one before the point (a closing one) or at the point (an opening
 * one) is shown in reverse. efuns' Paren_mode shows it when the
 * closing one is typed.
 *
 * The parentheses are counted, not parsed: one in a string or a
 * comment counts as any other, and the search goes no farther than
 * 20,000 characters. *)
val mode : Efuns.minor_mode

(* [matching text pos] gives where the one that matches pos's is *)
val matching : Text.t -> int -> int option
