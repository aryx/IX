(* Globbing matches *, ? and [...] against file names, and against
 * strings for ~ and switch.
 *
 * As a word is expanded (Word), it keeps which of its characters were
 * quoted. Only the unquoted * ? and [ are pattern characters, so '*'.c
 * and $x.c with x='*' are literal, and *.c is a pattern. rc marks the
 * unquoted ones with a special byte as it lexes (principia's lex.c,
 * GLOB). Here a word is a list of pieces, each quoted or not.
 *
 *     in a directory with a.c b.c .hidden (checked on 9base's rc):
 *     *.c        a.c b.c
 *     *          .hidden a.c b.c       * matches a leading . too
 *     nomatch*   nomatch*              no match: the word itself
 *     */*.c      d1/x.c d2/y.c         one directory level per /
 *
 * [abc] and [a-z] match one character of the set, and [~a-z] matches
 * one that is not in it. The matches of one word are sorted. In ~ and
 * switch, the same patterns match strings, and there * matches / too.
 *
 * cs-history:
 * The name comes from a program. In the first Unix shells, the shell
 * did not expand a * at all. When it saw one in a command, it ran
 * /etc/glob (for "global") with the command and its arguments. glob
 * read the directories, replaced each pattern by the names that
 * matched, and ran the command, or said "No match". So the shell
 * stayed small, on a machine where it had to. Bourne's shell (1979)
 * did the expansion itself, and the word stayed: a pattern is a glob,
 * in the shell and in the C library's glob().
 *
 * others:
 * What to do with a pattern that matches nothing? Here, as in the
 * Bourne shell, the word is left as it is, so rm nomatch* says that
 * it cannot remove "nomatch*". csh, as /etc/glob did, refuses to run
 * the command ("No match"), and so do zsh and fish; bash lets an
 * option choose (failglob, nullglob). An empty list would be the
 * consistent answer in a shell whose values are lists, but rc kept
 * sh's rule.
 *
 * road-not-taken:
 * A * that tries every suffix by recursion, as here and in rc, is
 * exponential on a*a*a*b against many a's. Going back only to the
 * last * is enough, and is linear (Russ Cox, 2017). But a file name
 * is short and nobody writes that pattern, so the shells kept the
 * simple code.
 *
 * References: principia's glob.c (glob, match); rc(1), "Patterns";
 * Tom Duff, "Rc -- The Plan 9 Shell" (1990), "Patterns", which says
 * that only / and the components . and .. must be written explicitly,
 * where Bourne's "An Introduction to the UNIX Shell" says it of any
 * "." at the start of a name; /etc/glob (VII) of the first edition's
 * manual (1971); Russ Cox, "Glob Matching Can Be Simple And Fast Too"
 * (2017). *)

type piece = { text : string; literal : bool }

(* an expanded word *)
type word = piece list

val to_string : word -> string

(* does it have an unquoted pattern character? *)
val is_pattern : word -> bool

(* [matches pat s]: does [s] match [pat], with * matching / too (for ~
 * and switch)? *)
val matches : word -> string -> bool

(* [files ~readdir ~exists w]: the file names that [w] matches, sorted,
 * or [w] itself if it matches none or is not a pattern. [readdir dir]
 * lists a directory ("" is the current one), or gives None if it
 * cannot be read. *)
val files :
  readdir:(string -> string list option) -> exists:(string -> bool) -> word -> string list
