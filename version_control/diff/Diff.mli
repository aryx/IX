(* Differential file comparison. This is principia's diff (9front's),
 * whose -u output is what git/diff prints (diffreg.c, diffio.c).
 *
 * The algorithm is Harold Stone's, as the C's comment calls it (Hunt
 * and McIlroy's diff). The lines are hashed, and the common prefix and
 * suffix are set aside. The lines of the second file are sorted by
 * hash into equivalence classes. Then [stone] walks the first file.
 * For each k, it keeps the k-candidate: the smallest line of the
 * second file that ends a common subsequence of length k, found by a
 * binary search. The longest common subsequence is then read back
 * from the last candidate's chain. That gives J, where J.(i) is the
 * line of the second file matched to line i of the first, or 0. A
 * match that the hash made up is broken by comparing the lines
 * ("jackpot").
 *
 *   first:  a b c d          J = [1; 0; 3; 4]    2c2
 *   second: a B c d e                            < b
 *                                                ---
 *                                                > B
 *                                                4a5
 *                                                > e
 *
 * The output formats are:
 * - the default (above);
 * - -e, an ed script, with the last change first;
 * - -f, forward;
 * - -n, with the file names;
 * - -c, with 3 lines of context, where hunks whose contexts overlap
 *   are merged;
 * - -a, with the whole file as context;
 * - -u, unified.
 * A last line without a newline is followed by "\ No newline at end
 * of file" (as in 9front; 9base's diff prints a newline instead).
 *
 * These are kept as the C has them: a line longer than 4,095 bytes is
 * compared by its first 4,095 bytes (the C then also seeks by those
 * lengths when printing, which is not kept); a line whose hash is 0
 * ends the file; the first file's last line is not checked again
 * against the hash.
 *
 * cs-history:
 * diff is Doug McIlroy's, written at Bell Labs in the first half of
 * the 1970s, with James Hunt for the algorithm. The difficulty then
 * was memory, with two files of a few thousand lines on a PDP-11,
 * hence the hashes in place of the lines. An early use was to keep
 * versions as ed scripts (-e gives what to type in ed to make the
 * second file from the first), besides seeing what you had changed.
 * In 1985, Larry Wall's patch made diff's output something to send. A
 * change to a program became a text in a mail, and it could be
 * applied even when the file had moved a little since, thanks to the
 * lines of context. Free software was developed this way for twenty
 * years, and a git commit is still shown, and mailed, as a unified
 * diff.
 *
 * modern:
 * GNU diff and git use Eugene Myers's algorithm (1986). It finds the
 * shortest edit script as a shortest path in the grid of the two
 * files, in time proportional to the files' size times the number of
 * differences. So it is fast when the files are close, which is the
 * common case. The time of Hunt and McIlroy's algorithm depends
 * instead on the number of pairs of equal lines, and it is slow on
 * files with many blank or repeated lines. git has two more
 * algorithms (patience, histogram) that look first for the lines that
 * are unique in both files, to give hunks that a person reads better.
 *
 * References: E. W. Myers, "An O(ND) Difference Algorithm and Its
 * Variations" (Algorithmica, 1986);
 * J. W. Hunt and M. D. McIlroy, "An Algorithm for
 * Differential File Comparison" (Bell Labs CSTR 41, 1976);
 * diffreg.c's own comment, checked. *)

type whitespace = Exact | Collapse (* -b *) | Strip (* -w *)

type mode = Normal | Ed | Forward | Numbered | Context | All | Unified

(* the lines as the C reads them: each with its newline, if any *)
type file = { name : string; lines : string array }

(* a file's lines, or None if it looks binary: its first 1,024 bytes,
 * decoded as UTF-8, have a NUL or a character from 0x80 to 0xa0 *)
val read : whitespace -> string -> string -> file option

type t

val compute : whitespace -> file -> file -> t

(* the output; with [header], "diff [-MODE] A B" is printed first, as
 * -m and directory diffs do *)
val output : header:bool -> mode -> t -> string

val differ : t -> bool

(* the changes in merge3's order: the first and last lines of the
 * first file's range, and those of the second file's. A range with
 * x > y is empty. *)
type change = { oldx : int; oldy : int; newx : int; newy : int }

val changes_backward : t -> change list

val lines0 : t -> string array
val lines1 : t -> string array

(* the C's fetch: lines a..b of a file, bounded by [maxb], each one
 * after a prefix *)
val fetch : Buffer.t -> string array -> maxb:int -> int -> int -> string -> unit
