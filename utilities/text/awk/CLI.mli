(* The command line: its usage and a few examples are [help] in CLI.ml,
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
