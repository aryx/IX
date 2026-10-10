(* An object's name: the SHA-1 of its type, size and content (git9's
 * Hash, 20 bytes).
 *
 *   of_object "blob" "hello\n" = hash of "blob 6\000hello\n"
 *                              = ce013625030ba8dba906f756967f9e9ca394464a
 *
 * (checked with git hash-object). Equal content has one name,
 * wherever it is and whoever wrote it: that is git's first idea.
 *
 * What follows from a name that is the content's hash: a file kept
 * in a thousand commits is stored once; two repositories know what
 * the other lacks by comparing names (Get, Send); an object read
 * back is checked by hashing it; and nothing can be changed in
 * place, since the changed bytes would have another name.
 *
 * cs-history:
 * Hashes that hold hashes are Ralph Merkle's trees (1979), made for
 * signatures: signing the root signs all the leaves. Plan 9 had the
 * idea for storage before git: Venti (Sean Quinlan and Sean Dorward,
 * 2002) is an archival server where a block is written once and
 * asked for by its SHA-1, and a file system's nightly snapshot is a
 * tree of such blocks whose root is one hash. Monotone, a version
 * control system of 2003, named its files and trees so, and git
 * took the idea from it.
 *
 * modern:
 * SHA-1 was broken as a hash for signatures in 2017: two different
 * PDF files with one SHA-1 were published (SHAttered, by CWI
 * Amsterdam and Google), at the cost of years of processor time.
 * git answered by detecting the known attack's pattern as it
 * hashes, and by a second format of repository on SHA-256; nearly
 * all repositories are still SHA-1, as git9's and this one's are. *)

type t = Sha1.t

(* 40 zeros: git's "no object" (a branch created or deleted, on the
 * wire) *)
val zero : t

val of_object : string -> string -> t

val to_hex : t -> string
val of_hex : string -> t
val is_hex : string -> bool
val compare : t -> t -> int
