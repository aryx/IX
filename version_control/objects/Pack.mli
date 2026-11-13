(* A pack holds many objects in one file, most of them stored as
 * deltas against others, and an index to find them (git9's pack.c:
 * readpacked, searchindex; indexpack and writepack in phase 7).
 *
 *   .pack:  "PACK" | version 2 | count | entry ... | SHA-1 of the above
 *   entry:  type and size (3 bits, then 7-bit groups) | zlib stream
 *           an OFS delta first says how far back its base is,
 *           a REF delta gives its base's hash
 *   .idx:   "\377tOc" | version 2 | fanout[256] | hashes, sorted |
 *           CRCs | 31-bit offsets | 64-bit offsets | the pack's SHA-1 |
 *           the index's SHA-1
 *
 * A 31-bit offset with its top bit set is an index into the 64-bit
 * offsets. fanout[b] counts the hashes whose first byte is at most b,
 * so a lookup is a binary search in [fanout[b-1], fanout[b]). A pack's
 * entries have no lengths: each one ends where its zlib stream does.
 *
 * design:
 * Compression is kept apart from history. As a loose object, a version
 * of a file is a whole file deflated, and a source tree of some years
 * would be many times its size. RCS and SCCS save space in the model
 * itself: a file's versions are a chain of differences, and reading
 * an old one applies them in turn. In git the model is whole
 * snapshots (Object), and a pack is free to store any object as a
 * difference from any other object that looks like it, whether or not
 * one came from the other. Packer chooses by likeness (the same kind,
 * the same path, close dates), Delta is the difference, and a reader
 * that follows the chain gets back the same bytes, checked by their
 * hash. Packs came to git some months after the loose objects, and
 * nothing above the store had to change.
 *
 * The same file is also what goes over the network (Proto): a fetch
 * gets a pack made for what the other side lacks.
 *
 * References: git's gitformat-pack(5), for the formats; git9's pack.c,
 * the reader followed here. *)

type t

(* the pack beside the given .idx *)
val open_idx : < Cap.open_in; .. > -> Fpath.t -> t

val mem : t -> Hash.t -> bool

(* the object, with its deltas applied. A REF delta's base may be
 * anywhere, and [base] finds it. *)
val read : t -> base:(Hash.t -> (Object.Kind.t * string) option) -> Hash.t -> (Object.Kind.t * string) option

val hashes : t -> Hash.t list

(* the .idx files of a repository's .git *)
val all : Fpath.t -> Fpath.t list

(* an object in a pack being written. It is whole, or a delta against
 * another object named by its hash (git9 writes only REF deltas). *)
type entry = Whole of Object.Kind.t * string | Ref_delta of Hash.t * Delta.t

(* the pack's bytes, with its SHA-1 at the end *)
val write : entry list -> string

(* the index of a pack's bytes (git9's indexpack). The entries are
 * read one after the other, each ending where its zlib stream ends.
 * The deltas are resolved in passes until all of them are; a REF
 * delta's base is in the pack or, for a thin pack, comes from [base].
 * The result is the .idx, version 2. *)
val index : string -> base:(Hash.t -> (Object.Kind.t * string) option) -> string

(* the hex name a pack is saved under, from its trailing SHA-1 *)
val name : string -> string
