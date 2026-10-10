(* mini-ed: Plan 9's ed, the line editor. The text is a buffer of
 * numbered lines that is never shown; what is typed is commands, one a
 * line, each some addresses (which lines) and a letter (what to do
 * with them), and ed answers with the lines asked for, a count, or ?.
 *
 *     standard input                    the modules, a command's way
 *        | Input      a character at a time; g's command list in front
 *     1,3s/a/b/p
 *        | Address    1,3 read and evaluated at once: lines 1 to 3
 *        | Command    the letter s, which reads /a/b/ and p itself
 *        |-- Regex    a compiled and matched against each of the lines
 *        |            (lib_core's: Grep's, Sed's and awk's too)
 *        |-- Text     the lines: replaced, appended, deleted, moved,
 *        |            marked, written to a file and read from one
 *        '-- Out      the p: the last line changed, on standard output
 *
 * There is no tree of a command and no screen to repair: each module
 * reads the characters it needs and acts at once. The session that
 * mini-ed -h prints shows the commands a first reader needs.
 *
 * It is the editor that asks nothing of the machine: no cursor to
 * move, no terminal to know, a console that prints lines is enough.
 * So it is the first editor mini-9pi has, before any window (ed on
 * its card), and one of the first programs ix builds by itself.
 *
 * why-study:
 * An editor without a screen can be given its commands by a program.
 * Plan 9's compilers are built with one such script, mkenam: ed reads
 * the header that lists the assembler's instructions (5.out.h), v/re/d
 * deletes every line that is not one, three s commands turn each name
 * into a quoted string, 1i and $a put a C array's first and last lines
 * around them, and w writes enam.c (tests/mkenam.sh runs it here). A
 * screen editor does the same by hand, each time the header changes.
 * And much of Unix is ed's commands taken out of ed: s/re/new/ is
 * sed's, which is ed on a stream too long for a buffer; g/re/p, every
 * line that matches printed, is grep; diff -e writes its answer as an
 * ed script; a, i, d, s, w and q after a colon are still vi's.
 *
 * evolution:
 * The line editor, from QED to sam. QED (L. Peter Deutsch and Butler
 * Lampson, Berkeley, 1965-66) was written for teletypes on a shared
 * machine: paper, ten characters a second, so a command had to be
 * short and print only what was asked. Ken Thompson wrote a QED for
 * CTSS and added regular expressions to it (Regex.mli has his paper
 * of 1968), then another for Multics, then for the first Unix a
 * smaller one, ed (1969): one buffer where QED had many, fewer
 * commands. At Queen Mary College George Coulouris made ed kinder
 * (em, "editor for mortals", 1976), and Bill Joy at Berkeley, who saw
 * it that summer, wrote ex, whose visual mode showed the buffer on a
 * screen: vi. In Plan 9 the same line goes on with Rob Pike's sam
 * (1987), whose commands are ed's but whose addresses are regular
 * expressions over the whole text, not lines, with every change
 * undone at will, and then acme (1994). ed itself was kept, with
 * runes for characters and libregexp's full expressions.
 *
 * others:
 * GNU ed adds a prompt (-p) and messages in words (h, H) to the ?,
 * and is what POSIX describes. The ed here is Plan 9's: a file's
 * characters are UTF-8, a pattern may have ( ) and |, and the tests
 * compare each answer with 9base's ed, byte for byte.
 *
 * The command line: its usage and options are [help] in CLI.ml, what
 * mini-ed -h prints (-h and --help, not ed's).
 *
 * An interrupt prints ? and goes back to the commands; a hangup writes
 * the buffer to ed.hup and quits. The exit status is 0, as ed.c's.
 *
 * References: principia's editors/ed/ed.c and its book (the Editor
 * book, which starts with mkenam); ed(1) of the Plan 9 manual; Brian
 * Kernighan, "A Tutorial Introduction to the UNIX Text Editor" (Bell
 * Labs; in the seventh edition's manual, volume 2), the session to
 * type first; L. Peter Deutsch and Butler Lampson, "An Online Editor"
 * (CACM, 1967), QED; Dennis Ritchie, "An incomplete history of the QED
 * Text Editor", from Berkeley's QED to ed; Rob Pike, "The Text Editor
 * sam" (Software -- Practice and Experience, 1987), what came after. *)

type caps = < Command.caps; Cap.argv; Cap.exit; Cap.stdout >

val main : < caps; .. > -> string array -> int
