(* Fpath, lib_core/system/'s subset (see Stdlib.mli), itself Daniel
 * Bünzli's fpath's: a file's path, a type of its own, so that a file's
 * name and a text are not passed one for the other. A path is a string
 * that is not empty, its segments between /; one ending in / names a
 * directory. Fpath_.Operators has the shorter names: / and !! *)
type t

(* a path of a string (// is one /); Invalid_argument for "" *)
val v : string -> t
val to_string : t -> string

(* p / seg: a segment added; p // q: q under p, or q when it is absolute *)
val add_seg : t -> string -> t
val append : t -> t -> t

(* the last segment that is not empty (a/b/ gives b/); the path without
 * it, a directory (a/b gives a/, a gives ./) *)
val base : t -> t
val parent : t -> t

(* the extension: what follows the last segment's last dot, the dot
 * with it, when the dot is not the segment's first character. Whether
 * it is e; the path with e in its place, or added; without it *)
val has_ext : string -> t -> bool
val set_ext : string -> t -> t
val rem_ext : t -> t
