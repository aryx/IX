(* mini-chidb: a relational database in one file, chidb's twin (the
 * teaching database of the University of Chicago, itself SQLite cut
 * to what a course can build). A statement's way down, and the rows'
 * way back:
 *
 *     SELECT name FROM t WHERE n > 100;
 *        |
 *        |  Sql (Lexer, Parser)
 *        v
 *     Ast: Project([name], Select(n > int 100, Table(t)))
 *        |                         the relational algebra, a tree
 *        |  Optimizer              a selection pushed under a join
 *        |  Codegen                with Schema: t's root page, its
 *        v                         columns, its indexes
 *     Bytecode: Integer, OpenRead, Rewind, Column, Le, ResultRow,
 *        |      Next, Close, Halt  a program (Dbm.mli has it whole)
 *        |  Dbm                    the machine: registers, cursors
 *        v
 *     Cursor --> Btree --> Pager --> the file
 *     a place    a table   pages of 1,024 bytes
 *     in a       or an
 *     tree       index     (Record: a row as bytes in a leaf)
 *
 * Shell is the prompt around it (and .parse, .opt, .explain, which
 * show each stage's output); Dbmfile, a program for the machine
 * written by hand, for its tests. Two halves meet at the bytecode:
 * above it is a compiler, of a language that says what is wanted;
 * below it a storage engine that knows nothing of SQL, only keys and
 * records in trees. A compiler's passes and a file system's layers
 * (the kernel's, over its disk's blocks) in some 2,500 lines.
 *
 * cs-history:
 * Edgar Codd's relational model (IBM, 1970): the data as tables of
 * values and nothing else, no pointer from a record to another, and
 * a query that says which rows are wanted, not how to reach them.
 * The databases of the day (IBM's IMS, a hierarchy; the CODASYL
 * network model) were programmed by following pointers, and a
 * change of the layout broke the programs. Two projects showed the
 * model could be made fast, both from 1973-74: System R at IBM San
 * Jose, whose language SEQUEL (Donald Chamberlin and Raymond Boyce,
 * 1974) became SQL, and Ingres at Berkeley (Michael Stonebraker and
 * Eugene Wong), whose language was QUEL. Oracle sold the first SQL
 * system in 1979, before IBM did. The division above is System R's:
 * its RDS, the language and its optimizer, over its RSS, the
 * storage, with a small interface between.
 *
 * cs-history:
 * SQLite (D. Richard Hipp, 2000) put the whole of it in a library:
 * no server and no administrator, a database is a file that a
 * program opens. Its statement compiled to a program for a virtual
 * machine (the VDBE) is its own design; its file format has not
 * changed since version 3 (2004), and it is now in every phone and
 * every browser. chidb (Borja Sotomayor) keeps that file format and
 * that machine, cut down, for the students of a course to write the
 * B-tree, the machine and the compiler themselves.
 *
 * why-study:
 * What is not here is what makes a database hard, and one sees
 * where it would go. No transaction: no journal, no lock, so a
 * crash in the middle of an insertion leaves a tree half split
 * (Pager.mli says where SQLite does it). No UPDATE nor DELETE
 * compiled, so no page is ever freed and no node merged. No cost in
 * the optimizer (Codegen.mli). Most of a real database's code is
 * those three.
 *
 * The command line, chidb's: [help] in CLI.ml, what mini-chidb
 * --help prints (-h, chidb's, its usage line only).
 *
 * References: E. F. Codd, "A Relational Model of Data for Large
 * Shared Data Banks" (Communications of the ACM, 1970); M. M.
 * Astrahan et al., "System R: Relational Approach to Database
 * Management" (ACM Transactions on Database Systems, 1976), the
 * architecture; D. Chamberlin and R. Boyce, "SEQUEL: A Structured
 * English Query Language" (1974); B. Sotomayor and A. Shaw, "chidb:
 * Building a Simple Relational Database System from Scratch"
 * (SIGCSE, 2016); sqlite.org's "Architecture of SQLite", the same
 * picture with all its boxes; plan_db.md. *)

val main : < Shell.caps; Cap.argv; .. > -> int
