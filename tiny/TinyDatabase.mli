(* A tiny relational database, in one file, whose query language is the
 * relational algebra itself. mini-chidb (database/) is chidb, faithfully:
 * SQL compiled to a register machine over B-trees of fixed pages,
 * changed in place. This keeps the ideas and takes the other roads; its
 * statements, by example, are [help] below (help at its prompt, and
 * the start of tiny-db -h):
 *
 * - {b A query is a pipeline of the algebra's operators}, read left to
 *   right as a Unix pipe: a table, then where (sigma), select (pi,
 *   with computed columns), join (the natural join), group (with count,
 *   sum, min, max), sort, take. SQL's SELECT ... FROM ... WHERE is this
 *   pipeline written in a fixed order; here the order is the user's,
 *   and each stage's columns are the previous stage's output.
 * - {b The tree is copy-on-write}: a node, once written, never changes.
 *   An insertion writes the path from a new leaf to a new root, at the
 *   end of the file, and a statement commits by writing its new
 *   catalog there and its offset in the file's header, one small write.
 *   So every statement is atomic (a crash before the header's write
 *   leaves the previous state whole), nodes can be cached without
 *   invalidation, and readers of an old root would see a consistent old
 *   database (not used here). The price: the file grows; nothing is
 *   reused, as in an append-only log. Nodes are values written by hand
 *   (an int in 8 bytes, a list its length then its elements; it was
 *   Marshal), of any size, not fixed pages: fixed pages are for
 *   changing in place.
 * - {b Evaluation pulls rows through the stages} (a Seq per stage, the
 *   iterator model), the first where stage choosing an access path by
 *   its shape: a key range on the table, a range on an index, or a
 *   scan; explain prints the choice. Joins hash the right table.
 * - Keys are values, lists of them compared lexicographically: a
 *   table's tree is keyed by [key column], an index's by [value; key],
 *   so an index entry is unique and a range on the value is a range on
 *   the tree. Deletion removes the entry and does not rebalance: a
 *   node may be left underfull, even empty, and searches stay right.
 *
 * The file, and the only bytes of it ever written twice:
 *
 *     0     tinydb1 and a newline     the magic, 8 bytes
 *     8     the catalog's offset      8 bytes: written by each commit
 *     16    a length, a value         what was appended, each 8 bytes
 *     ...   a length, a value         of length then a node or a
 *     ...   a length, a value         catalog
 *
 * A catalog is the tables: for each its name, its columns, which one
 * is the key, the offset of its tree's root, and its indexes' roots.
 * A node is a leaf (at most 16 keys with their rows) or an inner node
 * (separators, and its children's offsets). So a database is the tree
 * of offsets under the header's 8 bytes, and an insert in the second
 * leaf of a table makes another tree that shares the first leaf:
 *
 *     header ---> catalog ---> root            before
 *                              /   \
 *                          leaf1   leaf2
 *
 *     header -.   catalog ---> root            after: the old tree is
 *             |                /   \           whole, and nothing
 *             |            leaf1   leaf2       names its catalog
 *             |              |
 *             '-> catalog' -> root'
 *                                \
 *                               leaf2'
 *
 *     the file:  leaf1 leaf2 root catalog | leaf2' root' catalog'
 *
 * What is right of the bar is the statement's, appended; the header
 * is written after it. A crash before that write leaves three values
 * that nothing reaches. A table of n rows costs an insert the height
 * of its tree in nodes, each of up to 16 entries written again: that
 * is the growth.
 *
 * Kept from chidb: tables with a key, int and text columns, indexes,
 * joins, a file that outlives the program. Added: delete, update
 * (set), group and the aggregates, sort, take, computed columns, and
 * the atomic statement. Dropped: SQL, NULL, the machine and its
 * programs, the 1,024-byte pages and SQLite's file format.
 *
 * The test: TinyDatabase_test.sh runs pipelines through it and the
 * equivalent SQL through SQLite (Python's sqlite3), rows compared.
 *
 * Exercises, each cheap because nodes never change:
 * - transactions of several statements: begin ... commit, the header
 *   written only at commit (and rollback: forget the catalog in
 *   memory); about 10 lines, since a statement is already one;
 * - time travel: each catalog also records the offset of the one it
 *   replaces, and books @ 3 reads the table as it was three commits
 *   ago; the old roots are all still in the file;
 * - compaction: copy the live trees into a new file, then rename it
 *   over the old one; the rename is atomic too, and the file stops
 *   growing forever;
 * - readers beside a writer: a reader keeps the root it started with,
 *   a snapshot, with no lock (LMDB's design);
 * - rebalancing on delete: merge an underfull node with a sibling.
 *
 * Where it stands: mini-chidb is the other road at each fork (SQL, a
 * compiler to a machine's programs, pages of 1,024 bytes changed in
 * place); the two read well side by side. A file that only grows and
 * one small write that commits is TinyVCS's store too (its objects
 * file and head), and a statement's rows pulled through stages are
 * Seq's, the shell's pipe inside one process. Under it are four calls
 * of the kernel: open, lseek, read, write (FS and Unix); it never
 * asks for the write to reach the disk (no fsync), so atomic here is
 * against the program's death, not the machine's.
 *
 * cs-history:
 * Edgar Codd's papers at IBM San Jose (1970 to 1972) gave the model,
 * tables with no pointers between them, and two languages for it: an
 * algebra of operators on whole tables, and a calculus that says what
 * is wanted and not how. IBM's System R (from 1974) built the second
 * as SEQUEL, later SQL; Berkeley's Ingres (Michael Stonebraker) built
 * QUEL, by most accounts the cleaner language. SQL won with IBM's
 * products and the 1986 standard. The algebra stayed inside: a
 * large SQL system turns a query into a tree of its operators and
 * runs that (SQLite and mini-chidb turn it into a program for a small
 * machine: Codegen, Dbm). Here the user writes the tree, which for a
 * pipeline is a list.
 *
 * comeback:
 * Never writing over a page is System R's first recovery scheme,
 * shadow pages (Raymond Lorie, 1977): a transaction writes new pages
 * and commits by swapping a page table. It was given up for the log
 * written ahead (a change's record forced to the disk first, the
 * pages in place later), which keeps a table's pages next to each
 * other and commits with one sequential write: what every large
 * system does since. It came back where simplicity and readers that
 * never wait matter more: CouchDB's files, LMDB (Howard Chu, 2011),
 * and the file systems ZFS and btrfs.
 *
 * others:
 * A query as a pipeline is how people write them outside SQL: the
 * shell's grep, sort, uniq and head on lines, R's dplyr, the log
 * tools' languages (Splunk's, Microsoft's Kusto), PRQL, and since
 * 2024 a pipe syntax proposed for SQL itself by Google (from memory).
 * The complaint they answer is SQL's order: SELECT is written first
 * and runs nearly last.
 *
 * References: R. Bayer and E. McCreight, "Organization and Maintenance
 * of Large Ordered Indices" (Acta Informatica, 1972; from memory), the
 * B-tree; O. Rodeh, "B-trees, Shadowing, and Clones" (ACM Transactions
 * on Storage, 2008; from memory), copy-on-write B-trees, the design of
 * LMDB and btrfs; G. Graefe, "Volcano -- An Extensible and Parallel
 * Query Evaluation System" (IEEE TKDE, 1994; from memory), the
 * iterator model; E. F. Codd, "A Relational Model of Data for Large
 * Shared Data Banks" (CACM, 1970; from memory), the algebra. *)

(* the open file with its tables; a line, parsed *)
type db
type stmt

(* one statement, done: a table made, rows added, a query planned,
 * run stage after stage and printed *)
val exec : < Cap.stdout; .. > -> db -> stmt -> unit

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr; .. > -> int
