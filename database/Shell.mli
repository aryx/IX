(* The shell, which runs chidb's commands and SQL, one line at a time.
 *
 * A line starting with . is a command (.open .parse .opt .dbmrun
 * .headers .mode .explain .help). A command is recognized when the word
 * starts with its name's letters, so .openx is .open. Anything else is
 * SQL, which runs on the open database. Rows are printed separated by |
 * (.mode list) or in columns of 10 characters (.mode column). .explain
 * on turns on both the headers and the columns, which is how the
 * program of an EXPLAIN reads well:
 *
 *      addr       opcode     p1         p2         p3         p4
 *      ---------- ---------- ---------- ---------- ---------- ----------
 *               0 Integer             2          0          0
 *               2 CreateTabl          4          0          0
 *
 * (CreateTable is cut to 10 characters, as chidb's %-10.10s does.)
 * The messages are chidb's, on the same streams as chidb's: "SQL syntax
 * error." and the errors of a statement go to standard output, and the
 * others to standard error. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

type t

val create : caps -> t

(* returns false, after chidb's message, if the file can't be opened *)
val open_db : t -> string -> bool

(* handles one line of input, which is not empty *)
val handle : t -> string -> unit

val close : t -> unit
