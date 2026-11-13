(* The small programs of a system (cat, ls, wc and the others) are
 * written here in one file and built into one executable.
 *
 * {b One executable, many names.} tiny-utils wc f runs wc, and so does
 * a link named wc (as in BusyBox, Bruce Perens, 1995). Each utility is
 * a row of a table: its name, its usage, and a function from its
 * arguments to its exit status.
 *
 * {b Most utilities are filters}: each is a function over the bytes of
 * the input, which arrive in pieces. cat prints each piece. wc counts, and
 * carries over from one piece to the next whether it is inside a word.
 * xd carries over the bytes of a line it has not finished. tee also
 * writes each piece to its files. Opening the named files (or reading
 * the standard input when there are none) and reporting a file that
 * cannot be opened is written once, in [each_input]. A piece is
 * printed as soon as it is read, so cat at the console, or in a pipe,
 * does not wait for the end:
 *
 *     files named, or stdin     each_input            the utility
 *     f1 ----------------------> opens it, reads it --> runs a step on
 *     f2 (cannot be opened) -->  in pieces of 8 KB      each piece, and
 *                                prints                 prints at once;
 *                                "wc: f2: reason",      then handles the
 *                                and the status is 1    end of each file
 *
 * twin:
 * m-ix's utilities/ has one program per file, each a faithful copy of
 * Plan 9's, with its options and its quirks. This file is what remains
 * when compatibility is dropped: once most options are gone, most of
 * each program is what it has in common with the others, and that can
 * be written once.
 *
 * The originals are in principia's utilities/, written in Plan 9's C
 * (files/cat.c, misc/wc.c, byte/xd.c, text/grep/...), and we know them
 * through m-ix's twins. ln has neither an original nor a twin: Plan 9
 * has no second name for a file, while tiny-kernel's file tree has hard
 * links (ls -l counts them). So ln is ours, three lines over
 * TinyLibSystem.link. ps is ours too: Plan 9's ps reads the status file
 * in each process's directory of /proc, while tiny-kernel gives a
 * single file, /dev/ps, with a line per process, which ps puts in
 * columns.
 *
 * kept:
 * We keep the twins' output where it costs nothing: wc's columns, xd's
 * lines, du's kilobytes, cmp's messages, ls's sorted names.
 *
 * dropped:
 * It drops most options (each utility keeps the one or two that carry
 * its idea), UTF-8 (wc counts bytes), floating point in seq, most of
 * ls -l (tiny-kernel has no owners, modes or times, so it shows only a
 * file's kind, links and size), and the wording of each program's
 * errors, which here are all "tool: file: reason". The plan, and what was found
 * along the way, is in docs/plans/done/plan_tiny_utilities.md.
 *
 * twist:
 * The utilities that walk a file tree share one fold, where each twin
 * walks the tree its own way (Plan 9's du.c and rm.c each have their
 * own recursion). [fold caps path f] calls f with the path, whether it
 * is a directory, its size, and a function that, when called, folds the
 * entries in name order. The moment when f calls that function decides
 * the order:
 *
 *     walk     prints the path, then calls it          pre-order
 *     du       calls it, sums its results with the     post-order
 *              path's own size, then prints the sum
 *     rm -r    calls it, then removes the path         post-order
 *     ls       does not call it, so it lists one level only
 *
 * context:
 * The same file runs on two systems. Like TinyShell.ml, it uses only
 * TinyLibSystem (TinyLibSystem.mli) and the pure functions of the
 * standard library, so it is both tiny-kernel's utils and the host's
 * tiny-utils.
 *
 * exercises:
 * - run the utilities in tiny-shell's own process (as BusyBox's NOFORK
 *   applets do), so that a pipeline of them is not limited by
 *   tiny-kernel's eight processes.
 *)

type caps =
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr;
    Cap.kill; Cap.clock; Cap.exit; Cap.env >

(* [each_input caps tool files f] calls f on each named file, or on
 * stdin when none is named. The result is the exit status: 1 when a
 * file could not be opened. *)
val each_input :
  < Cap.open_in; Cap.stdin; Cap.stderr; .. > ->
  string -> Fpath.t list -> (Chan.i -> unit) -> int

(* [fold caps path f] calls f path is_directory size entries, where
 * entries () folds over a directory in name order. *)
val fold :
  < Cap.open_in; Cap.readdir; .. > ->
  Fpath.t -> (Fpath.t -> bool -> int -> (unit -> 'a list) -> 'a) -> 'a

(* argv.(0) names the utility when it is run through a link. *)
val main : < caps; .. > -> string array -> Exit.t
