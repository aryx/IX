(* Regular expressions, in Plan 9's notation (regexp(7)). A match is the
 * leftmost-longest one, and its submatches are those of the
 * highest-priority way among the longest. These are libregexp's
 * answers, found by another algorithm.
 *
 *     c  \c  .  [a-z]  [^a-z]  ^  $     a character, quoted, any, a class,
 *                                       its complement, start, end
 *     e*  e+  e?  e1e2  e1|e2  (e)      repeats, concatenation, alternation,
 *                                       a group, which also captures
 *
 *     exec (compile "o|on") "one" 0            = Some [| (0, 2); ... |]
 *     exec (compile "(o|on)(e|ne)*") "one" 0   : \1 = (0, 1), \2 = (1, 3)
 *
 * {b The algorithm is libregexp's}, because its answers are the
 * specification, and they depend on how it works. It compiles the
 * pattern to a small program (regcomp.c: RUNE, ANY, CLASS, LBRA and
 * RBRA for the captures, OR, END), and runs it as a Thompson NFA with
 * captures, the "Pike VM". That is a list of threads, where each
 * thread is an instruction with its own captures, and the threads are
 * advanced together, one character at a time. Of two threads at the
 * same instruction, only the first is kept (or the one that started
 * earlier). The order of the list is not a priority. An OR follows
 * its left side at once and puts its right side at the end of the
 * list; the left side of * + ? is the skip, and the left side of a|b
 * is the b. Because of the dedup, that order shows in corner cases:
 * ((x?)?)* on xxb matches the empty string at 0 (checked on 9base),
 * where a priority-ordered matcher (a backtracker, RE2) matches xx.
 *
 * {b Lines and characters.} Positions are byte offsets, and a step
 * over a character decodes UTF-8, so . takes an é whole. As in
 * libregexp, . and [^...] never match a newline, ^ matches after a
 * newline, and $ before one. A line holds no newline, except while s
 * is making several lines out of one (Command).
 *
 * {b A pattern's program, and its run.} [compile "ab*c"] makes five
 * instructions, each with the one that follows it (the numbers give
 * the order they are made in, starting from the pattern's end):
 *
 *     4: RUNE a   then 2          --a-->(2)--------c-->(0) END
 *     2: OR       then 1, and 3          | ^
 *     3: RUNE b   then 2                 b |
 *     1: RUNE c   then 0                 `-'
 *     0: END
 *
 * An OR is where the ways part: the skip of b* (1) is followed at
 * once, and the body (3) is put on the list. On "abc" there is one
 * list of threads for each character, and each thread is shown by the
 * instruction it waits at:
 *
 *     a    {4}       RUNE a takes it                         -> {2}
 *     b    {2}       OR: 3 on the list; 1, RUNE c: not a c
 *          {3}       RUNE b takes it                         -> {2}
 *     c    {2}       OR: 3 on the list; 1, RUNE c takes it   -> {0}
 *          {3}       not a b
 *     end  {0}       END: the match, (0, 3)
 *
 * (At each character, a thread is also added for a match that would
 * start there; it is left out above.) No character of the text is
 * read twice, whatever the pattern: the work at each character is
 * bounded by the size of the list, not by the number of ways through
 * the pattern.
 *
 * {b Where it stands.} It is the one matcher for the programs that
 * come from Plan 9: ed's addresses and its s command, sed, grep, awk
 * (its Re translates awk's notation into this one), mini-emacs's
 * search, and the builder's patterns. The shell's * and ? are not
 * regular expressions; Glob handles them. A lexer's regular
 * expressions are compiled to a table before the program runs, by
 * Lexing.
 *
 * cs-history:
 * Ken Thompson's "Regular Expression Search Algorithm" (CACM, 1968)
 * was written for QED on the IBM 7094. The expression was compiled
 * to 7094 code that follows every state of the NFA at once, so a
 * search is linear in the text. That is the list of threads here,
 * run by an interpreter instead of as machine code. ed kept the
 * notation, and grep took its name from an ed command, g/re/p. Rob
 * Pike's sam gave each thread its own captures, which is the "Pike
 * VM" of libregexp and of this module (the name is Russ Cox's).
 *
 * others:
 * Perl's matcher, and those made after it (PCRE, Python's, Java's,
 * JavaScript's), try one way to its end and then come back to try the
 * next one. This is backtracking. A back-reference in the pattern
 * needs it, and it takes exponential time on a?a?a?aaa against aaa,
 * as both are made longer; Cox's 2007 article times it. RE2 (Google)
 * and Go's and Rust's libraries went back to Thompson's method and
 * gave up the back-reference.
 *
 * terminology:
 * Leftmost-longest, used here and in POSIX, picks the longest of the
 * matches that start earliest, so o|on on "one" gives "on".
 * Leftmost-first, Perl's rule, picks the first alternative that leads
 * to a match, so it gives "o". A backtracker gets the second for free,
 * and the first only by trying everything; the threads get either one
 * in one pass.
 *
 * References: Ken Thompson, "Regular Expression Search Algorithm",
 * CACM 11(6), 1968; Russ Cox, "Regular Expression Matching Can Be
 * Simple And Fast" (2007), which times the two methods, and "Regular
 * Expression Matching: the Virtual Machine Approach" (2009), on the
 * program and its threads and on where sam's captures came from;
 * regexp(7) and principia's regcomp.c, regexec.c and regaux.c
 * (libregexp), whose functions Regex's comments name. *)

type t

(* A pattern that isn't one: "missing operand", "malformed []", ... *)
exception Error of string

(* [compile p]: p as ed passes it, with a \ still before what it quotes *)
val compile : string -> t

(* [exec re s from]: the leftmost-longest match that starts at [from] or
 * after (^ still matches only at 0 or after a newline). It gives the
 * span of the whole match, then of groups 1-8, with (-1, -1) for a
 * group that did not match. *)
val exec : t -> string -> int -> (int * int) array option
