(* mini-bc is Plan 9's bc, the calculator with the usual notation, on
 * numbers of any size. It computes nothing itself: it is a compiler
 * from a language that looks like C to dc's commands, and dc (mini-dc's
 * machine, Dc) does the arithmetic. Here is what mini-bc -c prints:
 *
 *     a + b * c          lalblc*+ps.
 *
 *                        la lb lc   the values of the three registers
 *                                   are pushed
 *                        * +        then multiplied and added
 *                        p s.       the result is printed, and put
 *                                   away in register .
 *
 *     define f(x) {      [Sxlxlx*Lxs. 1QLxs.0 1Q]s<6>
 *      return (x*x)
 *     }                  a macro kept in f's register (<6>, because f
 *                        is the sixth letter). The argument is pushed
 *                        on x's own stack (Sx), x*x is computed, the
 *                        x of before is put back (Lx), and 1Q leaves
 *                        one macro; at the end, 0 is returned
 *     f(12)              12 l<6>xps.
 *
 *     if (1 < 2) 7       [ 7 ]s<128>
 *                        1  2 ><128>      runs <128> if 2 > 1
 *
 * So a variable is a register of dc. A parameter or a local is the top
 * of its register's stack (S pushes and L pops, so recursion comes for
 * free). A function, an if's body or a loop is a macro in a register,
 * run by x or by a comparison. State keeps the registers given out and
 * the macros entered, and the grammar's actions write the commands.
 *
 *     the text --> Lexer --> Parser --> dc's commands --> Dc --> Num
 *                            (State)    (printed with -c)
 *
 * design:
 * A small language compiled to another program's input was the way
 * of the Unix room in those years, once yacc (Stephen Johnson, 1973)
 * made a grammar cheap: eqn to troff (Kernighan and Cherry, 1975),
 * ratfor to Fortran (Kernighan), bc to dc. The hard part is written
 * once, in the program underneath; the language on top is a grammar
 * and a few lines for each action. Jon Bentley's "Little Languages"
 * (Communications of the ACM, 1986) is the essay on it. Its history
 * is told with dc's, in mini-dc's CLI.mli.
 *
 * The command line: its usage and a few examples are [help] in CLI.ml,
 * which is what mini-bc -h prints.
 *
 * bc compiles each statement to dc's commands as it reads it, and dc
 * runs them; -c prints the commands instead. bc reads the files in
 * turn, then the standard input. With -l, it reads the library before
 * them (s, c, a, l, e, j). An error is reported by dc: bc compiles it
 * to commands that print [file:line message].
 *
 * Not bc's: dc is not another program at the end of a pipe (/bin/dc)
 * but mini-dc's machine in this one, which is given each statement's
 * commands as soon as bc has them. The library is in the program, not
 * in a file (/sys/lib/bclib). And bc.y's if, while and for are Plan
 * 9's, which principia's bc.y has broken. *)

type caps = < Dc.caps; Cap.stderr >

val main : < caps; .. > -> string array -> Exit.t
