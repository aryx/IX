(* The small programs of a system, cat, ls, wc and the others, in one
 * file and one executable.
 *
 * m-ix's utilities/ has a program per file,
 * each a faithful copy of Plan 9's, with its options and its quirks.
 * This file is what remains when compatibility is dropped: once most
 * options are gone, what the programs have in common is most of each
 * one, and it can be written once.
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
 * {b The others walk a file tree}, and they are one fold: [fold path f]
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
 * {b The same file on two systems.} As TinyShell.ml, it names only
 * TinyLibSystem (TinyLibHost/TinyLibSystem.mli) and the pure functions
 * of the standard library. So dune builds it for the host, and tiny-ml
 * builds it for tiny-kernel, with TinyLibStd.ml and the kernel's
 * TinyLibSystem.ml.
 *
 * What is kept of the twins is their output, where it costs nothing:
 * wc's columns, xd's lines, du's kilobytes, cmp's messages, ls's
 * sorted names. So the test (tests/TinyUtilities_test.sh) runs each
 * utility and its twin, mini-wc, mini-xd..., on the same arguments,
 * and compares what they print and their exit status.
 *
 * What is dropped: most options (each utility keeps the one or two that
 * carry its idea), UTF-8 (wc counts bytes), floating point in seq, the
 * long format of ls (tiny-kernel has no owners, modes or times), and
 * the wording of each program's errors: here they are all "tool: file:
 * reason". The plan, and what was found on the way:
 * docs/plans/done/plan_tiny_utilities.md.
 *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr >

(* [each_input caps tool files f]: f on each file named, as its name
 * and a descriptor open on it, or on "" and the standard input when no
 * file is named. A file that cannot be opened is reported, and the
 * result, the exit status, is then 1 *)
val each_input : caps -> string -> string list -> (string -> int -> unit) -> int

(* [fold path f]: f path is_directory size entries, where entries ()
 * folds each entry of a directory (none for a file), in name order *)
val fold : string -> (string -> bool -> int -> (unit -> 'a list) -> 'a) -> 'a

val main : Cap.all_caps -> int
