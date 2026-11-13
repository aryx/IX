(* mini-dc is Plan 9's dc, the desk calculator. It keeps numbers of any
 * size on a stack, and an operator comes after its operands:
 *
 *     2 3 + 4 * p        what is typed
 *     2      3      +      4      *      p
 *     | 2 |  | 3 |  | 5 |  | 4 |  | 20 |  prints 20
 *            | 2 |         | 5 |
 *
 * No parenthesis and no precedence are needed, so there is no parser:
 * a command is one character, run as soon as it is read (Dc), on
 * integers that grow as they must (Num).
 *
 * cs-history:
 * dc is the oldest language of Unix still in use. It was written at
 * Bell Labs in B, before C existed, and soon taken over by Robert
 * Morris and Lorinda Cherry; Doug McIlroy calls it "the senior
 * language on UNIX systems". When the PDP-11 came, dc was "the first
 * language to run" on it, before its assembler (McIlroy again). The
 * notation is Jan Lukasiewicz's: in the 1920s he wrote logic without
 * parentheses, with the operator first, and with the operator last it
 * is called "reverse Polish". The desk calculators of Hewlett-Packard
 * made it familiar to engineers, with the HP-35 of 1972 in every
 * pocket.
 *
 * evolution:
 * bc is dc with the usual notation. Lorinda Cherry's bc (1975) is a
 * yacc grammar that translates a + b * c to dc's commands and pipes
 * them to dc, which does all the arithmetic: it is a compiler whose
 * target machine is another program. mini-bc is still that, with this
 * directory's machine linked in (the library ix_dc) where the pipe
 * was. GNU's bc (1991) computes by itself.
 *
 * The command line: its usage and a few examples are [help] in CLI.ml,
 * which is what mini-dc -h prints.
 *
 * Not dc's:
 * - dc's limits on memory, and Y, which prints them, are not here;
 * - the shell that ! runs is rc, by its path (/bin/rc), as in the C;
 * - in the C, a 0 that z, Z or X made has a byte, and keeps it through
 *   an addition or a multiplication (it then prints as 00.0 with a
 *   scale, or not at all in another base); here it keeps it only
 *   until it is computed with;
 * - what the C does after an operator found the stack empty, with
 *   blocks that are no longer a value, is not followed.
 *
 * References: dc(1); Robert Morris and Lorinda Cherry, "DC -- An
 * Interactive Desk Calculator" (in the Unix Programmer's Manual,
 * volume 2); M. D. McIlroy, "A Research UNIX Reader: Annotated
 * Excerpts from the Programmer's Manual, 1971-1986" (1987), for the
 * quotations; principia's utilities/calc/misc/dc.c. *)

type caps = < Dc.caps; Cap.stderr >

val main : < caps; .. > -> string array -> Exit.t
