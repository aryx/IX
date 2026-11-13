(* mini-awk is Plan 9's awk. A program is a list of patterns, each with
 * what to do when it matches. It is run on every line of the input,
 * and each line is cut into fields:
 *
 *     ken 1969 unix        awk '$2 > 1970 { n++; print $1, $3 }
 *     dmr 1972 c                END { print n, "lines" }' file
 *     bwk 1977 awk
 *                          dmr c
 *                          bwk awk
 *                          2 lines
 *
 * What a C program of this kind starts with is built into the
 * language: the loop over the lines, the cutting into $1, $2...,
 * variables with no declaration that are a number or a string as they
 * are used (Cell), arrays indexed by any string (w[$1] += $2), and
 * regular expressions as patterns (Re). So the program is often one
 * line, on the command line.
 *
 *     the program's text --> Lexer --> Parser --> Ast
 *                                      (Scope)     |
 *     the files of ARGV --> Io: a record --> Run: each pattern, its
 *                                             |   action
 *                Cell: variables, fields, arrays;
 *                Cformat: printf's conversions;
 *                Io: print > file, cmd | getline
 *
 * The program is parsed whole into trees, then Run walks them, one
 * record at a time. The C does the same, with trees made by yacc.
 *
 * cs-history:
 * Alfred Aho, Peter Weinberger and Brian Kernighan wrote awk at Bell
 * Labs in 1977, and its name is their initials. It went out with the
 * Seventh Edition (1979), meant for programs of a line or two, and
 * people wrote long ones. So the version of 1985 has functions,
 * getline, and several inputs and outputs; it is the one of their
 * book, "The AWK Programming Language" (1988). Plan 9's awk is that
 * program, Kernighan's own source, which he has kept alive since.
 *
 * evolution:
 * awk's parts went on in other languages. Perl (Larry Wall, 1987)
 * began as awk, sed and the shell in one, for reports, and took over
 * the programs longer than a page. The array indexed by strings
 * became the hash of Perl, the dict of Python and the object of
 * JavaScript. awk itself stayed for what it was made for, the line
 * typed in a pipeline (mini-sed is its elder there, and mini-grep is
 * the elder of both).
 *
 * The command line: its usage and a few examples are in [help] in
 * CLI.ml, which is what mini-awk -h prints (-h and --help are not
 * awk's flags).
 *
 * The program is the first argument, or the files of -f. The
 * arguments after it go in ARGV: they are files to read and var=value
 * assignments. An error in the program's text is reported with its
 * line and what was being read (the text up to the token, >>> the
 * token <<<, and the rest of the line). An error while the program
 * runs is reported with the input's record and the statement's line.
 * The status is 1 after an error, or if the program's exit gave a
 * number other than 0 (any such number gives 1, because Plan 9's
 * status is a string, "error").
 *
 * Where it differs from awk:
 *  - after an error in the text, the C goes on reading and may report
 *    two more ("illegal statement", "bailing out"); here only the first
 *    is reported, and the context it shows may end a token sooner or
 *    later;
 *  - the line of an error while the program runs is its statement's
 *    line (the C's is where yacc was when it made the last tree that
 *    ran);
 *  - a / after a ) is a division, so if (x) /re/ is not read;
 *  - the commands of system and of the pipes are run by rc, as in the
 *    C, by its path on this system (/bin/rc);
 *  - -safe and -d are accepted and do nothing; toupper and tolower
 *    know only ASCII's and Latin-1's letters; ENVIRON is there from
 *    the start, and is not made at its first use.
 * And it is the same as awk where one might not expect it. A number is
 * printed by Plan 9's print (with its fewest digits, and a half
 * rounded upward: %.0f of 2.5 is 3). A field or a string reads as a
 * number by strtoll's rules (010 is 8, 0x1A is 26). What
 * is reported of an error comes out at the program's end. And at END,
 * $0 is empty. *)

type caps = < Run.caps; Cap.argv >

val main : < caps; .. > -> string array -> Exit.t
