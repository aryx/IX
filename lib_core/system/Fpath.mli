(* ix: a file's path. Inspired by fpath, Daniel Bünzli's library
 * (https://erratique.ch/software/fpath): its names, its types and its
 * behaviour, for the part ix's programs use, written again here in a
 * few lines. Bundled here just for mini-ml, which has no fpath to link:
 * dune's builds of ix take the real library (this directory is not
 * dune's), and tests/modern/paths.ml holds this one to its answers.
 *
 * A path is a string that is not empty, its segments between /; one
 * ending in / names a directory. *)

type t

(* a path of a string (// is one /); Invalid_argument for "" *)
val v : string -> t
val to_string : t -> string
val pp : Format.formatter -> t -> unit

(* p / seg: a segment added; p // q: q under p, or q when it is absolute *)
val ( / ) : t -> string -> t
val ( // ) : t -> t -> t
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
