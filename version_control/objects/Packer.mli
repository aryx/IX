(* Packer packs the objects that the other side lacks (git9's
 * writepack: readmeta, pickdeltas, genpack), for a push, for a
 * server's reply to a fetch, and for repack.
 *
 * Which objects: the commits reachable from [heads] and not from
 * [have] (Query.twixt), each with its tree, its subtrees and its
 * blobs, less what the tips of [have] already hold. Which deltas: the
 * objects are sorted so that likely bases are near each other (by
 * kind, by a hash of their path, by date), and each one is tried
 * against the ten before it (git9's window). Chains are kept under
 * 128, and a delta is kept when it saves more than 32 bytes on git9's
 * estimate. The objects are written in date order, newest first, with
 * each delta chain together, as REF deltas. *)

val pack : Store.t -> heads:Hash.t list -> have:Hash.t list -> string

(* git9's murmurhash2 (util.c), 32 bits *)
val murmurhash2 : string -> int
