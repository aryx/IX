(* mini-git CMD args: git9's programs and scripts, git/CMD on Plan 9, as
 * subcommands of one executable; how: [help] in CLI.ml, what mini-git
 * -h prints. *)

type caps = < Store.caps; Cap.stdout; Cap.stderr; Cap.argv; Cap.fork; Cap.exec; Cap.wait >

val main : < caps; .. > -> int
