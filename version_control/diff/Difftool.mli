(* The commands diff and merge3 (diff.c, diffdir.c, util.c, merge3.c).
 * They take files or directories, and "-" for the standard input. A
 * file that is not a regular one (/dev/null) is read whole. Their
 * usage is in [diff_help] and [merge3_help] in Difftool.ml, which
 * --help prints.
 *
 * For directories, the entries of both are sorted. An entry on only
 * one side prints "Only in d: x" (in the default and -n formats only).
 * A subdirectory is compared with -r, and otherwise prints "Common
 * subdirectories: a and b". A file compared with a directory is
 * compared with the file of the same name in it. Binary files print
 * "binary files a b differ", and, as in the C, count as no change. *)

type caps = < Cap.stdout; Cap.stderr; Cap.stdin; Cap.open_in; Cap.argv >

val diff_main : < caps; .. > -> int
val merge3_main : < caps; .. > -> int
