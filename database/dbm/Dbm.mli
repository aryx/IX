(* The database machine, which is what SQL is compiled to (chidb's DBM,
 * modeled after SQLite's VDBE).
 *
 * Numbered registers hold values, and numbered cursors walk B-trees. A
 * program is a list of instructions, run from the first one until the
 * end or a Halt; each instruction either jumps or goes on to the next.
 * Here is SELECT name FROM t WHERE n > 100, as EXPLAIN prints it
 * (checked on chidb):
 *
 *      0  Integer     2  0  0      r0 := 2               t's root page
 *      1  OpenRead    0  0  3      cursor 0 on it, 3 columns
 *      2  Integer   100  1  0      r1 := 100
 *      3  Rewind      0  9  0      to the first row; if none, go to 9
 *      4  Column      0  2  2      r2 := its column 2
 *      5  Le          1  8  2      if r2 <= r1, go to 8   (the WHERE, negated)
 *      6  Column      0  1  3      r3 := its column 1
 *      7  ResultRow   3  1  0      a row of 1 register from r3
 *      8  Next        0  4  0      the next row; if there is one, go to 4
 *      9  Close       0  0  0
 *     10  Halt        0  0  0
 *
 * ResultRow hands a row to the caller, and the machine resumes after
 * it. A comparison jumps when the register named third compares that
 * way with the one named first: [Le] jumps if r2 <= r1.
 *
 * design:
 * Why a machine? A statement becomes a value, a program, which can be
 * kept and run again (a prepared statement), printed (EXPLAIN, above,
 * shows the plan the database chose, and you read it as you read
 * assembly), and stopped. At ResultRow the machine returns with a row,
 * and all its state is in the registers, the cursors and the number of
 * the next instruction, so the caller asks for the next row when it
 * wants it. Also, the storage is hidden behind a dozen instructions on
 * cursors (Rewind, Next, Column, Seek, Insert), which are all that a
 * compiler needs to know of a B-tree.
 *
 * others:
 * Most databases do not compile to bytecode. They keep the algebra's
 * tree and make each operator an iterator with one method, next, which
 * asks its children for a row; a join's next calls the next of its two
 * inputs (Goetz Graefe's Volcano, 1994). The loop of instructions 3 to
 * 8 above then becomes a chain of calls for each row. The newer
 * analytic systems compile a query to machine code, or pass rows by
 * the thousand, to get rid of those calls for each row; SQLite's
 * bytecode sits in between.
 *
 * evolution:
 * SQLite's machine first had a stack of values, as the Java machine's
 * bytecode has. It has had registers since version 3.5.5 (2008), and
 * chidb follows that: an instruction names where its operands are, so
 * a value used twice is not pushed twice.
 *
 * References: SQLite's VDBE ("The SQLite Bytecode Engine",
 * sqlite.org), of which chidb's machine is a subset, with 37 opcodes
 * out of about 180 (checked, chidb's docs/claude_notes/notes_sqlite.txt);
 * chidb's assignment_dbm page (docs/chidb-website/chidb/), which
 * specifies the opcodes. *)

open Bytecode

(* the instruction with its jump target changed *)
val map_jump : ('a -> 'b) -> 'a instr -> 'b instr

val to_row : int instr -> row

(* raises Invalid_argument for an unknown opcode or for a String
 * without its p4 *)
val of_row : row -> int instr

(* raised by an Insert or IdxInsert of a key that is already there
 * (CHIDB_ECONSTRAINT) *)
exception Constraint

type t
type step = Row | Done

val create : Btree.t -> int instr array -> t

(* runs until a ResultRow (Row) or the end (Done) *)
val step : t -> step

(* the registers of the last ResultRow *)
val result_row : t -> value list

(* the registers that were written, with their numbers *)
val registers : t -> (int * value) list

(* how many registers the machine has (at least 10, and one past the
 * highest written, as with chidb's array), and the value of one of
 * them *)
val n_registers : t -> int
val register : t -> int -> value

(* a value as .dbmrun prints it: NULL, 42, "text", (n bytes); it prints
 * nothing for Unspecified *)
val show_value : value -> string
