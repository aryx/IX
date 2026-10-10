(* Differential file comparison: principia's diff (9front's), whose
 * -u git/diff prints (diffreg.c, diffio.c).
 *
 * The algorithm is Harold Stone's, as the C's comment calls it (Hunt
 * and McIlroy's diff): lines are hashed; the common prefix and suffix
 * set aside; the lines of the second file sorted by hash into
 * equivalence classes; then [stone] walks the first file keeping, for
 * each k, the k-candidate with the smallest line of the second file
 * ending a common subsequence of length k -- a binary search each --
 * so that the longest common subsequence is read back from the last
 * candidate's chain. That gives J, J.(i) the line of the second file
 * matched to line i of the first, or 0; a match the hash made up is
 * broken by comparing the lines ("jackpot").
 *
 *   first:  a b c d          J = [1; 0; 3; 4]    2c2
 *   second: a B c d e                            < b
 *                                                ---
 *                                                > B
 *                                                4a5
 *                                                > e
 *
 * The output formats: the default (above), -e (an ed script, last
 * change first), -f (forward), -n (with the file names), -c (3 lines
 * of context, hunks whose contexts overlap merged), -a (the whole file
 * as context), -u (unified). A last line without a newline is
 * followed by "\ No newline at end of file" (9front's; 9base's diff
 * prints a newline instead).
 *
 * Kept as the C has them: a line longer than 4,095 bytes is compared
 * by its first 4,095 (the C then also seeks by those lengths when
 * printing, which is not kept); a line whose hash is 0 ends the file;
 * the first file's last line is not re-checked against the hash.
 *
 * cs-history:
 * diff is Doug McIlroy's, at Bell Labs in the first half of the
 * 1970s, with James Hunt for the algorithm; the difficulty then was
 * memory, two files of a few thousand lines on a PDP-11, hence the
 * hashes in place of the lines. An early use was to keep versions
 * as ed scripts (-e: what to type in ed to make the second file
 * from the first), besides seeing what one had changed. In 1985 Larry Wall's
 * patch made its output something to send: a change to a program
 * became a text in a mail, applied even when the file had moved a
 * little since, thanks to the lines of context. Free software was
 * developed so for twenty years, and a git commit is still shown,
 * and mailed, as a unified diff.
 *
 * modern:
 * GNU diff and git use Eugene Myers's algorithm (1986): the
 * shortest edit script as a shortest path in the grid of the two
 * files, in time proportional to the files' size times the number
 * of differences, so fast when the files are close, which is the
 * common case. Hunt and McIlroy's depends on the number of pairs of
 * equal lines instead, and is slow on files with many blank or
 * repeated lines. git has two more (patience, histogram) that look
 * for lines unique in both files first, for hunks a person reads
 * better.
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

(* a file's lines, or None if it looks binary (a NUL or a character
 * 0x80-0xa0 in its first 1,024 bytes, decoded as UTF-8) *)
val read : whitespace -> string -> string -> file option

type t

val compute : whitespace -> file -> file -> t

(* the output; [header] prints "diff [-MODE] A B" first, as -m and
 * directory diffs do *)
val output : header:bool -> mode -> t -> string

val differ : t -> bool

(* the changes in merge3's order: first line of the first file's
 * range, last, and the second's; a range with x > y is empty *)
type change = { oldx : int; oldy : int; newx : int; newy : int }

val changes_backward : t -> change list

val lines0 : t -> string array
val lines1 : t -> string array

(* the C's fetch: lines a..b of a file bounded by [maxb], each after a
 * prefix *)
val fetch : Buffer.t -> string array -> maxb:int -> int -> int -> string -> unit
