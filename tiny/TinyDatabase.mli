(* A tiny relational database, in one file, whose query language is the
 * relational algebra itself. The full-size version in ix, mini-chidb
 * (database/), is a faithful copy of chidb: it compiles SQL to a
 * program for a register machine, which works on B-trees made of
 * fixed-size pages that are changed in place. This one keeps the same
 * ideas but takes the other road at each choice. Its statements are
 * shown by example in [help] below (which is also what help prints at
 * its prompt, and the start of what tiny-db -h prints):
 *
 * - {b A query is a pipeline of the operators of the algebra}, read
 *   from left to right like a Unix pipe: a table, then where (sigma),
 *   select (pi, with computed columns), join (the natural join), group
 *   (with count, sum, min, max), sort, and take. SQL's
 *   SELECT ... FROM ... WHERE is the same pipeline written in a fixed
 *   order; here the user chooses the order, and the columns of each
 *   stage are the output of the previous one.
 * - {b The tree is copy-on-write}: once a node is written, it never
 *   changes. An insertion writes a new leaf and the path from it up to
 *   a new root at the end of the file. A statement then commits by
 *   writing its new catalog there too, and storing the offset of that
 *   catalog in the header of the file, which is one small write. As a
 *   result, every statement is atomic (a crash before the header is
 *   written leaves the previous state intact), nodes can be cached
 *   without ever being invalidated, and a reader holding an old root
 *   would see a consistent old database (this is not used here). The
 *   price is that the file only grows: nothing is ever reused, as in an
 *   append-only log. Nodes are values serialized by hand (an int takes
 *   8 bytes, a list is its length followed by its elements; this used
 *   to be done with Marshal). They can have any size; fixed-size pages
 *   are only needed when you change pages in place.
 * - {b Evaluation pulls rows through the stages} (one Seq per stage:
 *   the iterator model). The first where stage chooses an access path
 *   depending on its shape: a key range on the table, a range on an
 *   index, or a full scan; the explain command prints that choice. A
 *   join builds a hash table of the right-hand table.
 * - Keys are values, or lists of values compared lexicographically. The
 *   tree of a table is keyed by [key column], and the tree of an index
 *   by [value; key], so each index entry is unique and a range on the
 *   value is a range in the tree. Deletion removes the entry but does
 *   not rebalance the tree: a node may be left underfull, even empty,
 *   and searches still work correctly.
 *
 * Here is the layout of the file. The catalog offset is the only part
 * that is ever written twice:
 *
 *     0     tinydb1 and a newline     the magic number, 8 bytes
 *     8     the catalog's offset      8 bytes, rewritten by each commit
 *     16    a length, a value         what was appended: each entry
 *     ...   a length, a value         is a length (8 bytes) followed
 *     ...   a length, a value         by a node or a catalog
 *
 * A catalog describes the tables: for each table, its name, its
 * columns, which column is the key, the offset of the root of its tree,
 * and the roots of its indexes. A node is either a leaf (at most 16
 * keys with their rows) or an inner node (separator keys and the
 * offsets of its children). So a database is a tree of offsets hanging
 * from the 8 bytes of the header. Inserting into the second leaf of a
 * table creates a new tree that shares the first leaf with the old one:
 *
 *     header ---> catalog ---> root            before
 *                              /   \
 *                          leaf1   leaf2
 *
 *     header -.   catalog ---> root            after: the old tree is
 *             |                /   \           still intact, but no
 *             |            leaf1   leaf2       header points to its
 *             |              |                 catalog anymore
 *             '-> catalog' -> root'
 *                                \
 *                               leaf2'
 *
 *     the file:  leaf1 leaf2 root catalog | leaf2' root' catalog'
 *
 * Everything right of the bar was appended by the statement, and the
 * header is written only after that. A crash before the header is
 * written leaves three values in the file that nothing points to. In a
 * table of n rows, an insert rewrites as many nodes as the tree is
 * high, each with up to 16 entries: that is how fast the file grows.
 *
 * What is kept from chidb: tables with a key, int and text columns,
 * indexes, joins, and a file that outlives the program. What is added:
 * delete, update (set), group and the aggregate functions, sort, take,
 * computed columns, and atomic statements. What is dropped: SQL, NULL,
 * the register machine and its programs, the 1,024-byte pages, and
 * SQLite's file format.
 *
 * The test, TinyDatabase_test.sh, runs pipelines through this database
 * and the equivalent SQL through SQLite (Python's sqlite3), and
 * compares the resulting rows.
 *
 * Exercises, all cheap because nodes never change:
 * - transactions of several statements: begin ... commit, where the
 *   header is written only at commit (and rollback just forgets the
 *   catalog in memory); about 10 lines, since a single statement is
 *   already a transaction;
 * - time travel: each catalog also records the offset of the catalog
 *   it replaces, and books @ 3 reads the table as it was three commits
 *   ago; all the old roots are still in the file;
 * - compaction: copy the live trees into a new file, then rename it
 *   over the old one; the rename is atomic too, and the file no longer
 *   grows forever;
 * - readers running beside a writer: a reader keeps the root it
 *   started with, as a snapshot, without any lock (LMDB's design);
 * - rebalancing on delete: merge an underfull node with a sibling.
 *
 * Where it stands: mini-chidb takes the other road at each fork (SQL,
 * a compiler to programs for a machine, 1,024-byte pages changed in
 * place), and the two read well side by side. A file that only grows,
 * plus one small write to commit, is also how TinyVCS stores things
 * (its objects file and its head). Pulling the rows of a statement
 * through stages is what Seq does; it is the shell's pipe, inside a
 * single process. Underneath, the database uses only four kernel
 * calls: open, lseek, read, and write (through FS and Unix). It never
 * asks for the data to actually reach the disk (no fsync), so
 * "atomic" here means safe if the program dies, not if the machine
 * does.
 *
 * cs-history:
 * Edgar Codd's papers at IBM San Jose (1970 to 1972) introduced the
 * model, tables with no pointers between them, and two languages for
 * it: an algebra of operators on whole tables, and a calculus that
 * says what is wanted rather than how to get it. IBM's System R (from
 * 1974) implemented the calculus as SEQUEL, later renamed SQL;
 * Berkeley's Ingres (Michael Stonebraker) implemented QUEL, by most
 * accounts the cleaner language. SQL won, thanks to IBM's products and
 * the 1986 standard. The algebra survived inside the systems: a large
 * SQL database turns a query into a tree of algebra operators and runs
 * that tree (SQLite and mini-chidb instead turn it into a program for a
 * small machine: see Codegen and Dbm). Here the user writes the tree
 * directly, and for a pipeline that tree is just a list.
 *
 * comeback:
 * Never writing over a page was System R's first recovery scheme,
 * shadow pages (Raymond Lorie, 1977): a transaction writes new pages
 * and commits by swapping a page table. It was abandoned for the
 * write-ahead log, where the record of a change is forced to disk first
 * and the pages are updated in place later. That keeps the pages of a
 * table next to each other and commits with one sequential write, and
 * every large system has worked this way since. Shadowing came back
 * where simplicity, and readers that never wait, matter more: in
 * CouchDB's files, in LMDB (Howard Chu, 2011), and in the ZFS and
 * btrfs file systems.
 *
 * others:
 * Writing a query as a pipeline is how people write queries outside
 * SQL: the shell's grep, sort, uniq and head on lines of text, R's
 * dplyr, the languages of log tools (Splunk's, Microsoft's Kusto),
 * PRQL, and, since 2024, a pipe syntax for SQL itself proposed by
 * Google. The complaint they all answer is SQL's order: SELECT is
 * written first but runs nearly last.
 *
 * References:
 *  - R. Bayer and E. McCreight, "Organization and Maintenance of Large
 *    Ordered Indexes" (Acta Informatica, 1972): the B-tree
 *  - O. Rodeh, "B-trees, Shadowing, and Clones" (ACM Transactions on
 *    Storage, 2008): copy-on-write B-trees, the design behind LMDB
 *    and btrfs
 *  - G. Graefe, "Volcano -- An Extensible and Parallel Query Evaluation
 *    System" (IEEE TKDE, 1994): the iterator model
 *  - E. F. Codd, "A Relational Model of Data for Large Shared Data
 *    Banks" (CACM, 1970): the algebra
 *)

(* the open file with its tables; a line, parsed *)
type db
type stmt

(* one statement, done: a table made, rows added, a query planned,
 * run stage after stage and printed *)
val exec : < Cap.stdout; .. > -> db -> stmt -> unit

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr; .. > -> int
