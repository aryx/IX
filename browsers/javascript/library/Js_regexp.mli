(* Js_regexp is JavaScript's regular expressions, the part that pages
   use: a pattern is read into a tree, and matched by backtracking.

   cs-history:
   This is where they came from. Stephen Kleene's "regular events" (1951, 1956)
   were a mathematician's notation for what a finite automaton
   accepts; Ken Thompson made them a tool, compiling an expression to
   machine code that follows every alternative at once (QED, 1968;
   then ed, and grep, 1973). Those match in time proportional to the
   text. Another line of implementations tries one alternative at a
   time and comes back on failure, which is backtracking. It began
   with Henry Spencer's library (1986), then Perl (Larry Wall, 1987),
   which kept what no automaton can do, groups referred back to (\1),
   and over the years added lookaheads and lazy quantifiers. Perl's
   syntax has been what the world means by "regex" ever since, and it
   is what JavaScript took (Navigator 4, 1997; the standard's ES3,
   1999). So this matcher backtracks, as Perl's and every browser's
   do: it is the only way to have backreferences, and its price is a
   pattern such as (a+)+b that takes exponential time on "aaaa...".

   (See mini-chrome's notes_javascript.md.) Hacker News' script counts
   its stories with s.match(/[0-9]+/); a page's scripts split, test
   and replace with them. Here is what is read:

     x  \.  \/  \n  \t  \uXXXX     a character (the strings are UTF-8,
                                   read a character at a time: Js_string)
     .                             any but a newline
     [abc] [a-z] [^0-9]            a set, ranges, its complement
     \d \w \s  \D \W \S            digits, word characters, spaces, and not
     ^ $                           the start and the end (of a line, with m)
     \b \B                         a word's edge, and not
     (x) (?:x)                     a group, captured (its number counted
                                   from its "(") or not
     x|y                           either
     x* x+ x? x{n} x{n,} x{n,m}    repeated, greedy; lazy with a ? after
     (?=x) (?!x)                   x is ahead, or is not: nothing consumed
     (?<=x) (?<!x)                 x is behind, or is not
     \1  (?<name>x)  \k<name>      what a group matched, again; a group
                                   named

   and the flags g (every match, done by Js_builtins), i (case ignored), m
   (^ and $ at each line), s (. matches a newline too), u (\u{1F600};
   a dot and a set take a whole character, all its bytes, with the
   flag or without) and y (the match must be at the position asked).

   A look ahead is the pattern tried from here, with its end thrown away:
   jQuery's /^[\s]*[>+~]|:(even|odd)(?=[^-]|$)/ wants ":even" not
   followed by a dash. A look behind is tried from each position before,
   until one ends exactly here. A backreference compares the text again:

     /(["'])(.*?)\1/ on {|say "hi" or 'yo'|}: group 1 is the quote that
     opened, \1 the same one closing: "hi" then 'yo', never "hi' 

   **Matching by backtracking**: each part of the pattern is tried at a
   position with "what comes after" as a continuation; a repetition
   takes as many as it can (greedy) and gives them back one by one when
   what follows fails. That is Henry Spencer's way, Perl's, and every
   browser's (theirs compile to bytecode). Its cost can be exponential
   on pathological patterns ({|(a*)*b|}); a step budget stops those.

     /a(b+)c/ on "xabbbcx": tried at 0 (fails at x), at 1: a, then b+
     takes bbb, c matches: [1, 6), group 1 [2, 5)

   Classes of Unicode (\p{L}) are not read. The spans that [exec]
   gives are byte offsets in the UTF-8 text; Js_builtins turns them
   into the units a script counts (Js_string).

   Where it stands: [compile] is called for a /.../ literal (Js_eval,
   Js_compile) and for new RegExp (Js_builtins). [exec] is called by
   Js_builtins under test, exec, match, replace, split and search. A
   compiled pattern is a kind of object (Js_value's Regexp).

   others:
   ix has the two lines of the history above, with a matcher for each,
   and they can be read side by side. lib_core's Regex is Thompson's
   line as Plan 9's libregexp has it: the pattern is compiled to a
   small program and run as an automaton, with every alternative
   advanced together a character at a time (the Pike VM). It is what
   grep, sed and the editors of ix match with, in time proportional to
   the text, and it has no backreference, no look ahead, and no lazy
   repeat. This one is Spencer's line: it tries one alternative at a
   time, and the others on failure. On (a+)+b against forty a's and no
   b, Regex says no after reading each character once; this one gives
   up after a million steps (its budget) and says no too, for another
   reason. Even their answers differ where both answer: Plan 9's gives
   the longest match from the leftmost start, and Perl's and
   JavaScript's give the first one found in the pattern's order. So
   a|ab on ab gives ab there and a here.

   Reference: Ken Thompson, "Regular Expression Search Algorithm"
   (CACM, 1968); ECMA-262 5.1, section 15.10 (RegExp); Russ Cox, "Regular
   Expression Matching Can Be Simple And Fast" (2007: why backtracking,
   and its worst case); Kernighan and Pike, "The Practice of
   Programming", chapter 9 (a matcher in 30 lines). *)
(* ix: copied from languages/javascript/library/Js_regexp.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

type t

(* the pattern compiled with its flags ("gim"), or Error with why it
 * cannot be *)
val compile : string -> string -> (t, string) result

val source : t -> string
val flags : t -> string
val global : t -> bool

(* the number of capturing groups *)
val groups : t -> int

(* the groups that have a name, (?<name>x), and their numbers *)
val names : t -> (string * int) list

(* the y flag: [exec] matches at [from] or not at all *)
val sticky : t -> bool

(* [exec re s from] finds the first match at or after [from]. It gives
 * the match's span, and each group's span if the group took part;
 * index 0 is the whole match. *)
val exec : t -> string -> int -> (int * int) option array option
