(* The commands diff and merge3 (diff.c, diffdir.c, util.c, merge3.c):
 * files or directories, "-" for standard input, a file that is not a
 * regular one (/dev/null) read whole. Their usage: [diff_help] and
 * [merge3_help] in Difftool.ml, what --help prints.
 *
 * Directories: the entries of both, sorted; "Only in d: x" for one
 * side's (default and -n formats only); a subdirectory with -r, or
 * "Common subdirectories: a and b"; a file against a directory: the
 * file of the same name in it. Binary files: "binary files a b differ",
 * and, as in the C, no change counted. *)

type caps = < Cap.stdout; Cap.stderr; Cap.stdin; Cap.open_in; Cap.argv >

val diff_main : < caps; .. > -> int
val merge3_main : < caps; .. > -> int
