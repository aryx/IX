(* The command line: its usage, flags and a few examples are [help] in
 * CLI.ml, what mini-rc -h prints (-h and --help, not rc's flags).
 *
 * rc does not start in C: it runs a script, rcmain, which reads the
 * profile if asked, then the -c command, the file, or the terminal
 * (plan9port's rcmain, embedded here as it is in 9base; -m reads
 * another):
 *
 *     mini-rc script a b     *=(script a b); . rcmain -> . $*
 *     mini-rc -c 'cmd'       cflag=cmd; . rcmain -> eval $cflag
 *     mini-rc                . rcmain -> . -i /dev/stdin, with a prompt
 *                           if the input is a terminal, or with -i
 *
 * The environment is read first (functions included), then the flags
 * are set as variables flag reads, and $status is rc's exit code:
 * "" 0, a number that number, anything else 1. *)

type caps = < Eval.caps; Cap.argv; Cap.exit; Cap.stdout >

val main : < caps; .. > -> string array -> int
