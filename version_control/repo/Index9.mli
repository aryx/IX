(* .git/INDEX9 is git9's staging file. It is text, with a line for each
 * path, and the last line of a path wins. walk.c and save.c read it,
 * the scripts append to it, and walk rewrites it.
 *
 *   A NOQID 0 new.c                     added (git/add)
 *   R NOQID 0 old.c                     to be removed (git/rm)
 *   T 1a2b3.1600000000123456.4d2 644 lib/a.c   tracked, and how it
 *                                       looked when last seen clean
 *
 * The second field is a Plan 9 qid (path, version, type), which
 * changes when the file does. On Linux its stand-in is the inode, the
 * modification time in microseconds and the size, written
 * "INODE.MTIME.SIZE" in hex, decimal and hex. NOQID, or a mode of 0,
 * means "compare the bytes". A file changed twice within a clock tick
 * keeps its time, so walk does not record the fingerprint of a file
 * modified in the last two seconds. (git calls the problem "racy git",
 * and answers it by comparing the bytes of a file as new as its
 * index.) U, untracked, is dropped when the file is rewritten.
 *
 * others:
 * git's index is a third copy of the tree, between the files and
 * the commit. It is a binary file of every tracked path with its
 * blob's hash, and add writes the blob at once. So you may commit a
 * part of what you changed, but you must know which of three states a
 * file is in (hence the two diffs and the two resets). git9's index is
 * a list of which paths are tracked, with no content: a commit takes
 * the files as they are on disk when it is made (Save). There is less
 * to learn, and you cannot commit half a file. *)

type state = Added | Removed | Tracked | Untracked

type qid = Noqid | Qid of { ino : int; mtime : int; size : int }

type entry = { state : state; qid : qid; mode : int; path : string; order : int }

exception Corrupt of int

val letter : state -> char

(* sorted by path, then by line; the last entry of a path is its state *)
val read : < Cap.open_in; .. > -> Fpath.t -> entry list option

(* writes the last entry of each path, without the U ones, through
 * INDEX9.new and a rename *)
val write : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> entry list -> unit

(* appends lines such as "A NOQID 0 path" *)
val append : < Cap.open_in; Cap.open_out; .. > -> Fpath.t -> (state * string) list -> unit

val qid_of_stats : Unix.stats -> qid
