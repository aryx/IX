(* The command line: its usage and a few examples are [help] in CLI.ml,
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
