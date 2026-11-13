(* mini-chidb: a relational database in one file. It is the twin of
 * chidb, the teaching database of the University of Chicago, which is
 * itself SQLite cut down to what a course can build. Here is the way a
 * statement goes down, and the way the rows come back:
 *
 *     SELECT name FROM t WHERE n > 100;
 *        |
 *        |  Sql (Lexer, Parser)
 *        v
 *     Ast: Project([name], Select(n > int 100, Table(t)))
 *        |                         the relational algebra, as a tree
 *        |  Optimizer              pushes a selection under a join
 *        |  Codegen                uses Schema: t's root page, its
 *        v                         columns, its indexes
 *     Bytecode: Integer, OpenRead, Rewind, Column, Le, ResultRow,
 *        |      Next, Close, Halt  a program (Dbm.mli shows it whole)
 *        |  Dbm                    the machine, with registers and
 *        v                         cursors
 *     Cursor --> Btree --> Pager --> the file
 *     a place    a table   pages of 1,024 bytes
 *     in a       or an
 *     tree       index     (Record: a row as bytes in a leaf)
 *
 * Shell is the prompt around it (with .parse, .opt and .explain, which
 * show the output of each stage). Dbmfile reads programs for the
 * machine that are written by hand, for its tests. Two halves meet at
 * the bytecode. Above it is a compiler, for a language that says what
 * is wanted. Below it is a storage engine that knows nothing of SQL,
 * only keys and records in trees. It is a compiler's passes and a file
 * system's layers (like the kernel's, over its disk's blocks) in some
 * 2,400 lines (its .ml, .mll and .mly files, without the tests).
 *
 * cs-history:
 * Edgar Codd proposed the relational model at IBM in 1970. The data is
 * tables of values and nothing else, with no pointer from one record to
 * another, and a query says which rows are wanted, not how to reach
 * them. The databases of the day (IBM's IMS, which was a hierarchy, and
 * the CODASYL network model) were programmed by following pointers, so
 * a change of the layout broke the programs. Two projects, both from
 * 1973-74, showed that the model could be made fast. One was System
 * R at IBM San Jose, whose language SEQUEL (Donald Chamberlin and
 * Raymond Boyce, 1974) became SQL. The other was Ingres at Berkeley
 * (Michael Stonebraker and Eugene Wong), whose language was QUEL.
 * Oracle sold the first SQL system in 1979, before IBM did. The
 * division above comes from System R: its RDS (the language and its
 * optimizer) sat over its RSS (the storage), with a small interface
 * between them.
 *
 * cs-history:
 * SQLite (D. Richard Hipp, 2000) put the whole of it in a library.
 * There is no server and no administrator: a database is a file that a
 * program opens. Compiling a statement to a program for a virtual
 * machine (the VDBE) is SQLite's own design. Its file format has not
 * changed since version 3 (2004), and it is now in every phone and
 * every browser. chidb (Borja Sotomayor) keeps that file format and
 * that machine, cut down, so that the students of a course can write
 * the B-tree, the machine and the compiler themselves.
 *
 * why-study:
 * What is missing here is what makes a database hard, and you can see
 * where it would go. There are no transactions: no journal and no
 * lock, so a crash in the middle of an insertion leaves a tree half
 * split (Pager.mli says where SQLite handles this). UPDATE and DELETE
 * are not compiled, so no page is ever freed and no node is ever
 * merged. The optimizer has no cost model (Codegen.mli). Most of a
 * real database's code is about those three things.
 *
 * The command line is chidb's. [help] in CLI.ml is what mini-chidb
 * --help prints; -h, as in chidb, prints only the usage line.
 *
 * References: E. F. Codd, "A Relational Model of Data for Large
 * Shared Data Banks" (Communications of the ACM, 1970); M. M.
 * Astrahan et al., "System R: Relational Approach to Database
 * Management" (ACM Transactions on Database Systems, 1976), the
 * architecture; D. Chamberlin and R. Boyce, "SEQUEL: A Structured
 * English Query Language" (1974); B. Sotomayor and A. Shaw, "chidb:
 * Building a Simple Relational Database System from Scratch"
 * (SIGCSE, 2016); sqlite.org's "Architecture of SQLite", which has the
 * same picture with all its boxes; plan_db.md. *)

val main : < Shell.caps; Cap.argv; .. > -> int
