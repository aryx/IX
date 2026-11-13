(* The four kinds of git objects, parsed (git9's Object, its Cinfo
 * and Tinfo, and pack.c's parsecommit and parsetree).
 *
 * An object on disk is "KIND SIZE\000CONTENT", and it is named by the
 * hash of exactly that. A tree's content is its entries, each one
 * "MODE NAME\000" followed by 20 raw bytes. A commit's content is text:
 *
 *    tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904
 *    parent 1f7a7a472abf3dd9643fd615f6da379c4acb3e3a     (0 or more)
 *    author Ori <ori@eigenstate.org> 1600000000 +0000
 *    committer Ori <ori@eigenstate.org> 1600000000 +0000
 *                                                        (a blank line)
 *    the message
 *
 * [print (parse kind s) = s] holds for every object that C git writes
 * with canonical modes. (A tree entry's 100664, from old gits, prints
 * as 100644; git9's save normalizes the same way.) A commit's other
 * headers (gpgsig, encoding, mergetag) are kept as they are, whereas
 * git9 drops a signature (deliberate difference 3).
 *
 * A blob is a file's bytes and nothing else, not even its name: the
 * name and the mode are in the tree that points to it. A tag names
 * another object, with a message. (CLI.mli draws how they point to
 * each other.)
 *
 * design:
 * A commit is a snapshot, not a change. It names the whole tree as
 * it was, and what the commit changed is computed when asked, by
 * comparing its tree with its parent's. Two trees with the same hash
 * are the same, so the comparison goes down only where they differ
 * (Query.changes, Log's filter). Nothing records that a file was
 * renamed or copied: git guesses it afterwards from blobs that are
 * alike. The systems before git stored the changes and rebuilt the
 * versions. Here the versions are stored, and how to keep them small
 * is a separate matter, left to Pack. *)

module Kind : sig
  type t = Blob | Tree | Commit | Tag
  val to_string : t -> string
  val of_string : string -> t option
end

type mode = File | Exec | Dir | Link | Submodule

type entry = { mode : mode; name : string; hash : Hash.t }

(* a signature: "Name <email>", the seconds since the epoch, and a
 * zone such as "+0100" *)
type person = { id : string; time : int; tz : string }

type commit = {
  tree : Hash.t;
  parents : Hash.t list;
  author : person;
  committer : person;
  extra : string;    (* the other headers, verbatim, each line ending in \n *)
  msg : string;      (* all that is after the blank line *)
}

type t = Blob of string | Tree of entry list | Commit of commit | Tag of string

exception Corrupt of string

val kind : t -> Kind.t
val parse : Kind.t -> string -> t
val print : t -> string
val hash : t -> Hash.t

val mode_bits : mode -> int

(* git's order of a tree's entries. They are sorted by name, and a
 * directory's name is compared as if it ended with '/' (so "a.c" <
 * "a/" < "a0"). A file and a directory of the same name are not equal,
 * and the file comes first (git9's entcmp). *)
val compare_entries : entry -> entry -> int

(* git9's notion of time is the seconds plus the zone's offset, so
 * that "1600000000 +0100" is 1600003600 (parseauthor). History is
 * ordered by it. *)
val local_time : person -> int

(* the message as git9 shows it, with its leading white space dropped *)
val message : commit -> string
