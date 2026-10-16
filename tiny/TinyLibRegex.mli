(* Regular expressions, in Plan 9's notation, for a tiny program that
 * asks whether a line matches one (grep, in TinyUtilities.ml):
 *
 *     c  \c  .  [a-z]  [^a-z]  ^  $     a byte, quoted, any, a class, its
 *                                       complement, a line's start, its end
 *     e*  e+  e?  e1e2  e1|e2  (e)      repeats, one after the other,
 *                                       either, a group
 *
 * m-ix's matcher (lib_core/commons/Regex.ml, libregexp's way) says
 * where the leftmost longest match is and where each group matched in
 * it, which an editor needs. A yes or a no needs neither, and what is
 * left is Thompson's method (1968): the expression becomes an
 * automaton, its states linked records, and a line is read once, byte
 * after byte, with the set of the states the bytes so far can be in.
 * Nothing is tried and taken back, so a line costs its length times the
 * pattern's at most. For "ab*c":
 *
 *     start --a--> loop --b--> (loop)        loop: a Split, to the b
 *                   |                          or to what follows
 *                   '--c--> Matched
 *
 * A pattern is checked as Plan 9's is: an alternative or a group with
 * nothing in it, a class with no byte, a - with nothing on a side are
 * errors. Bytes, not UTF-8's characters: . takes one byte.
 *
 * As the other TinyLibXxx, the same file for OCaml (dune's library) and
 * for tiny-ml (given before the program's file); a program opens it.
 *)

(* a pattern made an automaton *)
type regex

(* a pattern's automaton; Failure with what is wrong in it *)
val compile : string -> regex

(* whether the automaton matches somewhere in the line *)
val matches : regex -> string -> bool
