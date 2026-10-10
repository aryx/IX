(* mini-awk: Plan 9's awk. A program is patterns and what to do at
 * each, run on every line of the input, the line cut into fields:
 *
 *     ken 1969 unix        awk '$2 > 1970 { n++; print $1, $3 }
 *     dmr 1972 c                END { print n, "lines" }' file
 *     bwk 1977 awk
 *                          dmr c
 *                          bwk awk
 *                          2 lines
 *
 * What a C program of the kind starts with is the language's own:
 * the loop over the lines, the cutting into $1, $2..., variables
 * with no declaration that are a number or a string as they are
 * used (Cell), arrays indexed by any string (w[$1] += $2), regular
 * expressions as patterns (Re). So the program is often a line, on
 * the command line.
 *
 *     the program's text --> Lexer --> Parser --> Ast
 *                                      (Scope)     |
 *     the files of ARGV --> Io: a record --> Run: each pattern, its
 *                                             |   action
 *                Cell: variables, fields, arrays;
 *                Cformat: printf's conversions;
 *                Io: print > file, cmd | getline
 *
 * The program is parsed whole into trees, then Run walks them a
 * record at a time; the C is the same, its trees made by yacc.
 *
 * cs-history:
 * Alfred Aho, Peter Weinberger and Brian Kernighan, Bell Labs,
 * 1977; the name is their initials. It went out with the Seventh
 * Edition (1979), meant for programs of a line or two, and people
 * wrote long ones: so the version of 1985 has functions, getline,
 * several inputs and outputs, and is the one of their book, "The AWK
 * Programming Language" (1988). Plan 9's awk is that program,
 * Kernighan's own source, kept alive by him since.
 *
 * evolution:
 * awk's parts went on in other languages. Perl (Larry Wall, 1987)
 * began as awk, sed and the shell in one, for reports, and took the
 * programs longer than a page; the array indexed by strings is the
 * hash of Perl, the dict of Python, the object of JavaScript. awk
 * itself stayed for what it was made for, the line typed in a
 * pipeline (mini-sed is its elder there, mini-grep the elder of
 * both).
 *
 * The command line: its usage and a few examples are [help] in CLI.ml,
 * what mini-awk -h prints (-h and --help, not awk's flags).
 *
 * The program is the first argument, or the files of -f; the
 * arguments after it are ARGV's, files to read and var=value
 * assignments. An error in the program's text is said with its line
 * and what was being read (the text up to the token, >>> the token
 * <<<, the rest of the line); one while it runs, with the input's
 * record and the statement's line. The status is 1 after an error, or
 * if the program's exit gave a number not 0 (any: Plan 9's status is a
 * string, "error").
 *
 * Not awk's:
 *  - after an error in the text, the C goes on reading and may say two
 *    more ("illegal statement", "bailing out"); the first only here,
 *    and the context it shows may end a token sooner or later;
 *  - an error's line while the program runs is its statement's (the
 *    C's is where yacc was when it made the last tree it ran);
 *  - a / after a ) is a division: if (x) /re/ is not read;
 *  - the commands of system and of the pipes are rc's, as the C's, by
 *    its path on this system (/bin/rc);
 *  - -safe and -d are taken and do nothing; toupper and tolower know
 *    ASCII's and Latin-1's letters only; ENVIRON is there from the
 *    start, not made at its first use.
 * And as awk's, where one might not expect it: a number is printed by
 * Plan 9's print (its fewest digits, a half rounded upward: %.0f of 2.5
 * is 3), a field or a string that starts as a number is one by
 * strtoll's rules (010 is 8, 0x1A is 26), what is said of an error
 * comes out at the program's end, and at END $0 is empty. *)

type caps = < Run.caps; Cap.argv >

val main : < caps; .. > -> string array -> Exit.t
