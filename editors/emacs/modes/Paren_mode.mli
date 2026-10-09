(* A minor mode: the parenthesis, bracket or brace that matches the
 * one before the point (a closing one) or at the point (an opening
 * one) is shown in reverse. efuns' Paren_mode, which shows it when
 * the closing one is typed.
 *
 * Counted, not parsed: one in a string or a comment counts as any
 * other; no farther than 20,000 characters. *)
val mode : Efuns.minor_mode

(* [matching text pos]: where the one that matches pos's is *)
val matching : Text.t -> int -> int option
