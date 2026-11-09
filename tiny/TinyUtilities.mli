(* The small programs of a system, cat, ls, wc and the others, in one
 * file and one executable.
 *
 * {b One executable, many names.} tiny-utils wc f runs wc, and so does
 * a link named wc (BusyBox, Bruce Perens, 1995). A utility is a row of
 * a table: its name, its usage, and a function from its arguments to
 * its exit status.
 *
 * {b Most utilities are filters}: a function over the bytes of its
 * input, which arrive in pieces. cat prints each piece; wc counts, and
 * carries "inside a word" from a piece to the next; xd carries the
 * bytes of a line it has not finished; tee writes each piece to its
 * files too. Opening the files named, or reading the standard input
 * when none is, and reporting a file that cannot be opened, is done
 * once, by [each_input]. A piece is printed as soon as it is read, so
 * cat at the console, or in a pipe, does not wait for the end:
 *
 *     files named, or stdin     each_input            the utility
 *     f1 ----------------------> opened, read in -----> step on each
 *     f2 (cannot be opened) -->  pieces of 8 KB         piece, printed
 *                                "wc: f2: reason",      at once; the
 *                                the status is now 1    end of each file
 *
 * {b The others walk a file tree}, and they are one fold: [fold caps path f]
 * calls f with the path, whether it is a directory, its size, and a
 * function that folds its entries, in name order, when it is called.
 * When f calls it decides the order:
 *
 *     walk     prints the path, then calls it          pre-order
 *     du       calls it, sums its results with the     post-order
 *              path's own size, then prints the sum
 *     rm -r    calls it, then removes the path         post-order
 *     ls       does not call it: one level only
 *
 * twin:
 * m-ix's utilities/ has a program per file, each a faithful copy of
 * Plan 9's, with its options and its quirks. This file is what remains
 * when compatibility is dropped: once most options are gone, what the
 * programs have in common is most of each one, and it can be written
 * once.
 *
 * The originals are principia's utilities/, Plan 9's C (files/cat.c,
 * misc/wc.c, byte/xd.c, text/grep/...), known here through m-ix's
 * twins. ln has neither: Plan 9 has no second name for a file, and
 * tiny-kernel's tree has (ls -l counts them), so ln is ours, three
 * lines over TinyLibSystem.link. ps is ours too: Plan 9's reads a
 * directory a process in /proc, its status file; tiny-kernel gives one
 * file, /dev/ps, a line a process, which ps puts in columns.
 *
 * kept:
 * Of the twins, their output is kept, where it costs nothing: wc's
 * columns, xd's lines, du's kilobytes, cmp's messages, ls's sorted
 * names.
 *
 * dropped:
 * Most options (each utility keeps the one or two that carry its idea),
 * UTF-8 (wc counts bytes), floating point in seq, most of ls -l
 * (tiny-kernel has no owners, modes or times: it is a file's kind,
 * links and size), and the wording of each program's errors: here they
 * are all "tool: file: reason". The plan, and what was found on the
 * way: docs/plans/done/plan_tiny_utilities.md.
 *
 * context:
 * The same file on two systems: as TinyShell.ml, it names only
 * TinyLibSystem (TinyKernel/host/TinyLibSystem.mli) and the pure
 * functions of the standard library, so it is tiny-kernel's utils and
 * the host's tiny-utils.
 *)

type caps =
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr;
    Cap.kill; Cap.clock; Cap.exit; Cap.env >

(* [each_input caps tool files f]: f on a channel open on each file
 * named, or on the standard input's when no file is named; the channel
 * says which, its origin. A file that cannot be opened is
 * reported, and the result, the exit status, is then 1 *)
val each_input :
  < Cap.open_in; Cap.stdin; Cap.stderr; .. > ->
  string -> Fpath.t list -> (Chan.i -> unit) -> int

(* [fold caps path f]: f path is_directory size entries, where entries ()
 * folds each entry of a directory (none for a file), in name order *)
val fold :
  < Cap.open_in; Cap.readdir; .. > ->
  Fpath.t -> (Fpath.t -> bool -> int -> (unit -> 'a list) -> 'a) -> 'a

(* the program: its arguments (its name first, the utility's when it
 * is run by a link named after one) to how it ends *)
val main : < caps; .. > -> string array -> Exit.t
