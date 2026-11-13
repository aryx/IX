(* The compiler, which turns a statement into a program for the machine
 * (chidb's codegen.c).
 *
 * Each shape of statement has its own program. It uses chidb's
 * registers, cursors and order of instructions, because EXPLAIN prints
 * them:
 *
 *   - CREATE TABLE and CREATE INDEX insert a row into the schema table
 *     (and, for an index, scan its table to fill it);
 *   - INSERT puts the row's record into its table, then a (value,
 *     primary key) pair into each of the table's indexes;
 *   - SELECT from one table is a scan, where each conjunct of the WHERE
 *     is a jump over the row when it is false (for col > v, "if col <=
 *     v, skip"). When the WHERE is one comparison, or a range c > a AND
 *     c < b, on an indexed column, it is instead a seek in the index and
 *     a walk from there;
 *   - SELECT from a NATURAL JOIN of two tables is nested loops. Each
 *     side is scanned or seeked as a single table would be, and the
 *     pairs that agree on the shared columns are kept.
 *
 * The WHERE must be made of conjuncts `column OP literal` (where OP is
 * one of < <= = >= >, either way round), and the literal must have the
 * column's type. Anything else is refused (with Invalid, which the
 * shell prints as "SQL syntax error."). The choice between a scan and a
 * seek is made by the shape of the WHERE, not by a cost.
 *
 * A jump names a label, placed where chidb patches an address, and one
 * pass numbers the instructions and resolves the labels.
 *
 * road-not-taken:
 * Should it use a scan or an index, and which table of a join comes
 * first? Here the shape of the WHERE decides, and the tables are taken
 * in the order of the text. The other way began with System R's
 * optimizer (Selinger's paper, below). The database keeps statistics
 * (the rows of a table, the distinct values of an index), each way of
 * running the query gets an estimated cost in pages read, and the
 * cheapest one wins; the orders of the joins are searched by dynamic
 * programming. That is what let SQL say what is wanted and not how to
 * get it, and every large database has done it since. With two tables
 * and no statistics kept, there is nothing to estimate from.
 *
 * design:
 * The compiler of a query language is an ordinary compiler, and a
 * small one. There are no types to infer beyond a column's, no
 * registers to allocate (a new one is taken each time), loops come
 * only from the FROM, and jumps are resolved by labels, as in an
 * assembler. What it has that other compilers do not is the choice
 * above.
 *
 * References: P. G. Selinger et al., "Access Path Selection in a
 * Relational Database Management System" (SIGMOD, 1979), which
 * chooses a scan or an index by estimated cost: the road not taken;
 * chidb's assignment_codegen and assignment_opt pages
 * (docs/chidb-website/chidb/, checked), which are the specification. *)

type program = {
  code : int Bytecode.instr array;
  columns : string list;      (* the result's column names *)
  schema_change : bool;       (* a CREATE, so the schema must be read again *)
}

(* a statement that chidb's compiler refuses (CHIDB_EINVALIDSQL) *)
exception Invalid

val compile : Schema.item list -> Ast.t -> program
