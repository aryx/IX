(* Regular expressions in Plan 9's notation, as ed and sam have them,
 * for the tiny programs that need them: grep (in TinyUtilities.ml)
 * asks whether a line matches, and the editor (TinyEditorLine.ml)
 * asks where the match is and where each group matched in it.
 *
 *     c  \c  \n          a byte, a quoted byte, a newline
 *     .                  any byte but a newline
 *     [a-z]  [^a-z]      a class of bytes, and its complement
 *     ^  $               the start and the end of a line
 *     e*  e+  e?         repeats
 *     e1e2  e1|e2        one after the other, and either one
 *     (e)                a group, referred to by \1 to \9
 *
 * The matcher is a small backtracker that returns the leftmost-longest
 * match, as sam does. It keeps a memo of the (node, position) pairs it
 * has tried, so a pair is tried at most once and a match costs at most
 * the pattern's size times the text's length. [search] shares one memo
 * across all the places where a match may start: a node is always
 * followed by the same rest of the pattern, so a pair that failed from
 * one start fails from every other. So a search that fails, and a mere
 * yes or no ([matches]), read the line about once, as Thompson's
 * automaton (1968) does.
 *
 * The error messages are sam's: "no operand for `*'", "unmatched `('",
 * "malformed `[]'", and "too many subexpressions" (there are at most
 * nine groups, \1 to \9). We work on bytes, not on UTF-8 characters:
 * . matches one byte.
 *
 * twin:
 * m-ix's Regex (in lib_core), used by mini-ed and mini-grep, follows
 * libregexp (principia's lib_strings/libregexp/: regcomp.c, regexec.c)
 * and gives the same answers by the same algorithm: a list of threads
 * advanced one character at a time. It also decodes UTF-8. sam has a
 * matcher of its own (principia's editors/sam/regexp.c, with execute,
 * and bexecute for a search backward), also based on lists of threads.
 * Ours is a backtracker, which is a shorter program, and the memo keeps
 * it linear. In the corner cases where libregexp's answer depends on
 * the order of its thread list (see Regex.mli), our answer may differ.
 *)

type regex

(* raises Failure with what is wrong in the pattern *)
val compile : string -> regex

(* whether the pattern matches somewhere in the line *)
val matches : regex -> string -> bool

(* [search re text p lim] finds the leftmost-longest match that starts
 * in [p, lim] and ends by lim. The 20 slots hold the start and end of
 * the whole match (0 and 1), then of each group (2 and 3 for \1...),
 * or -1 for a group that did not match or that the pattern lacks. *)
val search : regex -> string -> int -> int -> int array option

(* the longest of the matches that end nearest before p *)
val search_back : regex -> string -> int -> int array option
