(* mini-dc: Plan 9's dc, the desk calculator. Numbers of any size on
 * a stack, the operator after its operands:
 *
 *     2 3 + 4 * p        what is typed
 *     2      3      +      4      *      p
 *     | 2 |  | 3 |  | 5 |  | 4 |  | 20 |  prints 20
 *            | 2 |         | 5 |
 *
 * No parenthesis and no precedence are needed, so no parser: a
 * command is one character, run as it is read (Dc), on integers that
 * grow as they must (Num).
 *
 * cs-history:
 * dc is the oldest language of Unix still in use. It was written at
 * Bell Labs in B, before C existed, and soon taken over by Robert
 * Morris and Lorinda Cherry; Doug McIlroy calls it "the senior
 * language on UNIX systems". When the PDP-11 came, dc was "the first
 * language to run" on it, before its assembler (McIlroy again). The
 * notation is Jan Lukasiewicz's (the
 * 1920s: a logic written without parentheses, the operator first;
 * with the operator last it is "reverse Polish"), which the desk
 * calculators of Hewlett-Packard made familiar to engineers, the
 * HP-35 of 1972 in every pocket.
 *
 * evolution:
 * bc is dc with the usual notation. Lorinda Cherry's bc (1975) is a
 * yacc grammar that translates a + b * c to dc's commands and pipes
 * them to dc, which does all the arithmetic: a compiler whose
 * target machine is another program. mini-bc is that still, with
 * this directory's machine linked in (the library ix_dc) where the
 * pipe was. GNU's bc (1991) computes by itself.
 *
 * The command line: its usage and a few examples are [help] in CLI.ml,
 * what mini-dc -h prints.
 *
 * Not dc's: its limits on memory, and Y, which prints them; the
 * shell of ! is rc by its path here (/bin/rc), as the C's. A 0 that z,
 * Z or X made has a byte in the C, and keeps it through an addition or
 * a multiplication (it then prints as 00.0 with a scale, or not at all
 * in another base): here only until it is computed with. And what the
 * C does after an operator found the stack empty, with blocks that are
 * no value any more, is not followed.
 *
 * References: dc(1); Robert Morris and Lorinda Cherry, "DC -- An
 * Interactive Desk Calculator" (in the Unix Programmer's Manual,
 * volume 2); M. D. McIlroy, "A Research UNIX Reader: Annotated
 * Excerpts from the Programmer's Manual, 1971-1986" (1987), for the
 * quotations; principia's utilities/calc/misc/dc.c. *)

type caps = < Dc.caps; Cap.stderr >

val main : < caps; .. > -> string array -> Exit.t
