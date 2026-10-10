(* mini-bc: Plan 9's bc, the calculator with the usual notation, on
 * numbers of any size. It computes nothing: it is a compiler, from a
 * language that looks like C to dc's commands, and dc (mini-dc's
 * machine, Dc) does the arithmetic. What mini-bc -c prints:
 *
 *     a + b * c          lalblc*+ps.
 *
 *                        la lb lc   the three registers' values pushed
 *                        * +        multiplied, added
 *                        p s.       printed, and put away in register .
 *
 *     define f(x) {      [Sxlxlx*Lxs. 1QLxs.0 1Q]s<6>
 *      return (x*x)
 *     }                  a macro kept in f's register (<6>: f is the
 *                        sixth letter): the argument pushed on x's own
 *                        stack (Sx), x*x, the x of before back (Lx),
 *                        and out of one macro (1Q); or 0 at the end
 *     f(12)              12 l<6>xps.
 *
 *     if (1 < 2) 7       [ 7 ]s<128>
 *                        1  2 ><128>      run <128> if 2 > 1
 *
 * So a variable is a register of dc, a parameter or a local the top
 * of its register's stack (S pushes, L pops: recursion for free), a
 * function, an if's body or a loop a macro in a register, run by x
 * or by a comparison. State has the registers given and the macros
 * entered; the grammar's actions write the commands.
 *
 *     the text --> Lexer --> Parser --> dc's commands --> Dc --> Num
 *                            (State)    (-c: printed)
 *
 * design:
 * A small language compiled to another program's input was the way
 * of the Unix room in those years, once yacc (Stephen Johnson, 1973)
 * made a grammar cheap: eqn to troff (Kernighan and Cherry, 1975),
 * ratfor to Fortran (Kernighan), bc to dc. The hard part is written
 * once, in the program underneath; the language on top is a grammar
 * and a few lines an action. Jon Bentley's "Little Languages"
 * (Communications of the ACM, 1986) is the essay on it. Its history
 * is told with dc's, in mini-dc's CLI.mli.
 *
 * The command line: its usage and a few examples are [help] in CLI.ml,
 * what mini-bc -h prints.
 *
 * bc compiles each statement to dc's commands as it is read, and dc
 * runs them: -c prints the commands instead. The files in turn, then
 * the standard input; -l: the library before them (s, c, a, l, e, j).
 * An error is said by dc, as bc compiles it to: [file:line message]
 * printed.
 *
 * Not bc's: dc is not another program at the end of a pipe (/bin/dc)
 * but mini-dc's machine in this one, given each statement's commands
 * when bc has them; the library is in the program, not a file
 * (/sys/lib/bclib). And bc.y's if, while and for are Plan 9's, which
 * principia's bc.y has broken. *)

type caps = < Dc.caps; Cap.stderr >

val main : < caps; .. > -> string array -> Exit.t
