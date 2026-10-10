(* Packs: many objects in one file, most stored as deltas against
 * others, and an index to find them (git9's pack.c: readpacked,
 * searchindex; indexpack and writepack in phase 7).
 *
 *   .pack:  "PACK" | version 2 | count | entry ... | SHA-1 of the above
 *   entry:  type and size (3 bits, then 7-bit groups) | zlib stream
 *           an OFS delta first says how far back its base is,
 *           a REF delta its base's hash
 *   .idx:   "\377tOc" | version 2 | fanout[256] | hashes, sorted |
 *           CRCs | 31-bit offsets (top bit: an index into) 64-bit
 *           offsets | the pack's SHA-1 | the index's SHA-1
 *
 * fanout[b] counts the hashes whose first byte is at most b, so a
 * lookup is a binary search in [fanout[b-1], fanout[b]). A pack's
 * entries have no lengths: each ends where its zlib stream does.
 *
 * design:
 * Compression apart from history. Loose, a version of a file is a
 * whole file deflated, and a source tree of some years would be
 * many times its size. RCS and SCCS save space in the model itself:
 * a file's versions are a chain of differences, and reading an old
 * one applies them in turn. In git the model is whole snapshots
 * (Object), and a pack is free to store any object as a difference
 * from any other that looks like it, whether or not one came from
 * the other: Packer chooses by likeness (the same kind, the same
 * path, close dates), Delta is the difference, and a reader that follows the
 * chain gets back the same bytes, checked by their hash. Packs came
 * to git some months after the loose objects, with nothing above
 * the store to change.
 *
 * The same file is also what goes over the network (Proto): a fetch
 * is a pack made for what the other side lacks.
 *
 * References: git's Documentation/gitformat-pack.txt (from memory),
 * the formats; git9's pack.c, the reader followed. *)

type t

(* the pack beside the given .idx *)
val open_idx : < Cap.open_in; .. > -> Fpath.t -> t

val mem : t -> Hash.t -> bool

(* the object, its deltas applied; a REF delta's base may be anywhere:
 * [base] finds it *)
val read : t -> base:(Hash.t -> (Object.Kind.t * string) option) -> Hash.t -> (Object.Kind.t * string) option

val hashes : t -> Hash.t list

(* the .idx files of a repository's .git *)
val all : Fpath.t -> Fpath.t list

(* an object in a pack being written: whole, or a delta against
 * another object, named by its hash (git9 writes REF deltas only) *)
type entry = Whole of Object.Kind.t * string | Ref_delta of Hash.t * Delta.t

(* the pack's bytes, its SHA-1 at the end *)
val write : entry list -> string

(* the index of a pack's bytes (git9's indexpack): the entries read
 * one after the other, each ending where its zlib stream ends; deltas
 * resolved in passes until all are, a REF delta's base in the pack or,
 * for a thin pack, from [base]; the .idx v2 of the result *)
val index : string -> base:(Hash.t -> (Object.Kind.t * string) option) -> string

(* the hex name a pack is saved under, from its trailing SHA-1 *)
val name : string -> string
