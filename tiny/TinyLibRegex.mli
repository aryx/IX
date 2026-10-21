(* Regular expressions in Plan 9's notation, as ed and sam have them,
 * for the tiny programs that need them: grep (in TinyUtilities.ml)
 * asks whether a line matches, and the editor (TinyEditorLine.ml)
 * asks where the match is and where each group matched in it.
 *
 *     c  \c  \n  .  [a-z]  [^a-z]  ^  $   a byte, quoted, a newline, any
 *                                       byte but a newline, a class, its
 *                                       complement, a line's start, its end
 *     e*  e+  e?  e1e2  e1|e2  (e)      repeats, one after the other,
 *                                       either, a group (\1 to \9)
 *
 * The matcher is a small backtracker that returns the leftmost-longest
 * match, as sam does. It keeps a memo of the (node, position) pairs it
 * has tried, so a pair is tried at most once and a match costs at most
 * the pattern's size times the text's length. matches shares one memo
 * across all the places where a match may start: a node is always
 * followed by the same rest of the pattern, so a pair that failed from
 * one start fails from every other. A yes or no therefore reads the
 * line about once, as Thompson's automaton (1968) does.
 *
 * old: grep had its own matcher, Thompson's automaton, and the editor
 * had this one. The two parsed patterns in slightly different ways,
 * and the editor's one alone could say where a match is.
 *
 * Errors are sam's: "no operand for `*'", "unmatched `('", "malformed
 * `[]'". Bytes, not UTF-8's characters: . takes one byte.
 *
 * Its twin is m-ix's Regex (lib_core), mini-ed's and mini-grep's,
 * which follows libregexp (principia's lib_strings/libregexp/:
 * regcomp.c, regexec.c) to give its answers, by the same algorithm, a
 * list of threads advanced a character at a time, and decodes UTF-8.
 * sam has a matcher of its own (principia's editors/sam/regexp.c, its
 * execute and, for a search backward, bexecute), lists of threads too.
 * Ours is a backtracker, the shorter program, kept linear by the memo;
 * where libregexp's answer comes from the order of its list (the
 * corner cases in Regex.mli), this one's may differ.
 *)

(* a pattern, parsed *)
type regex

(* a pattern parsed; Failure with what is wrong in it *)
val compile : string -> regex

(* whether the pattern matches somewhere in the line *)
val matches : regex -> string -> bool

(* [search re text p lim]: the leftmost-longest match starting in
 * [p, lim] and ending by lim. The array holds the start and end of the
 * whole match (0 and 1), then of each group (2 and 3 for \1...), -1 for
 * a group that did not match. *)
val search : regex -> string -> int -> int -> int array option

(* [search_back re text p]: the match ending nearest before p, the
 * longest of those *)
val search_back : regex -> string -> int -> int array option
