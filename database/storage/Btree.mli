(* The B-trees, which store a table or an index as a tree of pages.
 *
 * Each node is one page. It has a header, the offsets of its cells in
 * key order, free space, and the cells, packed from the end of the
 * page:
 *
 *      | header | cell offsets -->    free space    <-- cells |
 *
 * A table's leaves hold its rows by primary key. Its internal nodes
 * hold a key and a child for each cell (the child holds the keys <=
 * that key), and a right child for the rest. An index's nodes hold
 * (indexed value, primary key) pairs, and its internal nodes also have
 * a child for each pair. Insertion works as in chidb: a full child is
 * split before the insertion descends into it (its lower half, with
 * the median for a leaf, goes to a new page, and the median is
 * promoted into the parent). A full root is copied to a new page and
 * split there, so that the root keeps its page number, which the
 * schema records. Here is a table t with rows of about 50 bytes
 * (checked on chidb, with rows (i, "name number i padded to be
 * longer")):
 *
 *      20 rows:  page 2: leaf [1 .. 20]
 *      21 rows:  page 2: internal [(4, 11)] right 3
 *                page 4: leaf [1 .. 11]       page 3: leaf [12 .. 21]
 *
 * Pages are bytes that are read, changed in place and written back, in
 * chidb's order. A split leaves the old cells' bytes in the free space
 * of the page it reinitializes, and only that way are the files the
 * same as chidb's byte for byte (the plan, decision 2).
 *
 * cs-history:
 * The B-tree is a tree made for a disk. A binary tree of a million keys
 * is twenty levels deep, and when the nodes are on a disk, each level
 * costs a read, a movement of the arm. Rudolf Bayer and Edward
 * McCreight (at Boeing's research laboratory; the paper is from 1972)
 * made a node the size of what the disk reads at once, and filled it
 * with keys. Here an internal page of 1,024 bytes has room for about a
 * hundred children (a cell is 8 bytes and its offset 2, and the header
 * is 12), so a hundred times a hundred leaves of twenty rows, which
 * makes 200,000 rows, are three reads away. The tree also grows at the
 * root, by splits, so all the leaves stay at the same depth without a
 * rebalancing pass. They never said what the B stands for.
 *
 * terminology:
 * B-tree and B+-tree. In a B-tree, a key and its data are in whatever
 * node holds the key, internal or leaf. In a B+-tree, all the data is
 * in the leaves, and the internal nodes hold only copies of keys to
 * find the way, so they can hold more of them. A table here is a
 * B+-tree (the rows are in the leaves), and an index is a plain B-tree
 * (its internal entries are entries of the index, met between their
 * children). Comer's survey gives both names.
 *
 * design:
 * Splitting on the way down. The textbook insertion goes down to a
 * leaf and splits it if it is full, which may fill the parent, and so
 * on back up, so it must remember its path. If every full node met on
 * the way down is split, the parent always has room for the key that a
 * split promotes. The insertion is then one pass with no path kept, at
 * the price of a split now and then that was not needed yet.
 *
 * others:
 * A B-tree changes pages in place, anywhere in the file. A
 * log-structured merge tree (O'Neil and others, 1996; LevelDB,
 * RocksDB) only appends sorted runs and merges them later, which makes
 * writes cheaper and reads dearer. Most file systems keep their
 * directories or their extents in B-trees too.
 *
 * References: R. Bayer and E. McCreight, "Organization and
 * Maintenance of Large Ordered Indexes" (Acta Informatica, 1972), the
 * B-tree; D. Comer, "The Ubiquitous B-Tree" (ACM Computing Surveys,
 * 1979), the survey, which names the B+-tree; SQLite's file format,
 * "B-tree Pages", which has the four page types and cell layouts used
 * here (checked, through chidb's fileformat page). *)

type t

(* the kind of a tree, and the level of a node in it *)
type tree = Table | Index
type level = Leaf | Internal

(* a cell, by the page it is in; keys are unsigned 32-bit numbers *)
(* There is one constructor for each page type, so that a field cannot
 * be read through the wrong page type, as it could in chidb's
 * BTreeCell, a type byte and a union of four structs. *)
type cell =
  | Table_leaf of { key : int; data : Bytes.t }
  | Table_internal of { key : int; child : int }        (* keys <= key *)
  | Index_leaf of { key : int; pkey : int }
  | Index_internal of { key : int; pkey : int; child : int }   (* keys < key *)

type node = {
  page : Pager.page;
  mutable tree : tree;
  mutable level : level;
  mutable free_offset : int;
  mutable n_cells : int;
  mutable cells_offset : int;
  mutable right_page : int;        (* Internal only *)
}

(* the key a cell is ordered by *)
val key : cell -> int

(* a file whose header is not chidb's (CHIDB_ECORRUPTHEADER) *)
exception Corrupt_header

(* a node's type byte that is none of the four *)
exception Bad_node of int

(* an insertion whose key is already there (CHIDB_EDUPLICATE) *)
exception Duplicate

(* opens the file, and writes a new header and an empty schema table
 * on page 1 if it has none; raises Corrupt_header if its header is not
 * chidb's *)
val open_file : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> t
val close : t -> unit
val pager : t -> Pager.t

val get_node : t -> int -> node
val write_node : t -> node -> unit

(* allocates a new page with an empty node of that kind, and returns
 * its number *)
val new_node : t -> tree -> level -> int
val get_cell : node -> int -> cell

(* every cell of the tree at [root], in key order (an index's internal
 * cells come between the cells of their children), and the kind of
 * the tree *)
val cells : t -> int -> tree * cell list

(* the row with this key, in the table at [root] *)
val find : t -> int -> int -> Bytes.t option

val insert_in_table : t -> int -> int -> Bytes.t -> unit
val insert_in_index : t -> int -> int -> int -> unit
