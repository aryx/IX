(* The B-trees: a table, or an index, as a tree of pages.
 *
 * Each node is one page: a header, the offsets of its cells in key
 * order, free space, and the cells, packed from the end of the page:
 *
 *      | header | cell offsets -->    free space    <-- cells |
 *
 * A table's leaves hold its rows by primary key, its internal nodes
 * a key and a child each (the child holds the keys <= that key) and a
 * right child for the rest; an index's nodes hold (indexed value,
 * primary key) pairs, its internal nodes with a child each. Inserting
 * is chidb's: a full child is split before it is descended into (its
 * lower half, median included for a leaf, to a new page, the median
 * promoted into the parent), and a full root is copied to a new page
 * and split there, so that the root keeps its page number, which the
 * schema records. A table t with rows of about 50 bytes (checked on
 * chidb, rows (i, "name number i padded to be longer")):
 *
 *      20 rows:  page 2: leaf [1 .. 20]
 *      21 rows:  page 2: internal [(4, 11)] right 3
 *                page 4: leaf [1 .. 11]       page 3: leaf [12 .. 21]
 *
 * Pages are bytes, read and changed in place and written back, in
 * chidb's order: a split keeps the old cells' bytes in the free space
 * of the page it reinitializes, and the files are chidb's byte for
 * byte only so (the plan, decision 2).
 *
 * cs-history:
 * A tree made for a disk. A binary tree of a million keys is twenty
 * levels deep, and when the nodes are on a disk each level is a
 * read, a movement of the arm. Rudolf Bayer and Edward McCreight
 * (Boeing's research laboratory; the paper is of 1972) made the node
 * the size of what the disk reads at once and filled it with keys:
 * here an internal page of 1,024 bytes has room for about a hundred
 * children (a cell is 8 bytes and its offset 2, the header 12), so
 * a hundred times a hundred leaves of twenty rows, 200,000 rows, are
 * three reads away. And the tree grows at the root, by splits, so
 * all the leaves stay at one depth with no rebalancing pass. What
 * the B is for, they did not say.
 *
 * terminology:
 * B-tree and B+-tree. In the first, a key and its data are in
 * whatever node the key is, internal or leaf; in the B+-tree all the
 * data is in the leaves, and the internal nodes hold only copies of
 * keys to find the way, so they hold more of them. A table here is a
 * B+-tree (the rows in the leaves), an index a plain B-tree (its
 * internal entries are entries of the index, met between their
 * children): Comer's survey has both names.
 *
 * design:
 * Splitting on the way down. The textbook insertion goes down to a
 * leaf, and if the leaf is full splits it, which may fill the
 * parent, and so on back up: it must remember its path. Splitting
 * every full node met going down means the parent always has room
 * for the key a split promotes: one pass, no path kept, at the
 * price of a split now and then that was not needed yet.
 *
 * others:
 * A B-tree changes pages in place, anywhere in the file. A
 * log-structured merge tree (O'Neil and others, 1996; LevelDB,
 * RocksDB) only appends sorted runs and merges them later: cheaper
 * writes, dearer reads. Most file systems keep their directories or
 * their extents in B-trees too.
 *
 * References: R. Bayer and E. McCreight, "Organization and
 * Maintenance of Large Ordered Indices" (Acta Informatica, 1972; from
 * memory), the B-tree; D. Comer, "The Ubiquitous B-Tree" (ACM Computing
 * Surveys, 1979; from memory), where a table B-tree is his B+-tree
 * (data in the leaves) and an index B-tree the plain one; SQLite's
 * file format, "B-tree Pages", whose four page types and cell layouts
 * these are (checked, through chidb's fileformat page). *)

type t

(* the kind of a tree, and the level of a node in it *)
type tree = Table | Index
type level = Leaf | Internal

(* a cell, by the page it is in; keys are unsigned 32-bit numbers *)
(* old: chidb's BTreeCell, a type byte and a union of four structs,
 * whose fields could be read through the wrong page type *)
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

(* the file, with a new header and an empty schema table on page 1
 * if it has none; Corrupt_header if its header is not chidb's *)
val open_file : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> t
val close : t -> unit
val pager : t -> Pager.t

val get_node : t -> int -> node
val write_node : t -> node -> unit

(* a new page, an empty node of that kind; its number *)
val new_node : t -> tree -> level -> int
val get_cell : node -> int -> cell

(* every cell of the tree at [root], in key order (an index's internal
 * cells between their children's), and the tree's kind *)
val cells : t -> int -> tree * cell list

(* the row of this key, in the table at [root] *)
val find : t -> int -> int -> Bytes.t option

val insert_in_table : t -> int -> int -> Bytes.t -> unit
val insert_in_index : t -> int -> int -> int -> unit
