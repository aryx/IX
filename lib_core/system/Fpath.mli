(* ix: the path of a file. This is inspired by fpath, the library of
 * Daniel Bünzli (https://erratique.ch/software/fpath). It has fpath's
 * names, types and behaviour, for the part that ix's programs use,
 * written again here in a few lines. It is bundled here just for
 * mini-ml, which has no fpath to link. dune's builds of ix take the
 * real library (this directory is not dune's), and tests/modern/paths.ml
 * checks that this one gives the same answers.
 *
 * A path is a string that is not empty, with its segments separated by
 * /. A path that ends in / names a directory. *)

type t

(* Makes a path from a string (// becomes one /). It raises
 * Invalid_argument for "". *)
val v : string -> t
val to_string : t -> string
val pp : Format.formatter -> t -> unit

(* p / seg adds a segment to p. p // q is q under p, or q itself when q
 * is absolute. *)
val ( / ) : t -> string -> t
val ( // ) : t -> t -> t
val add_seg : t -> string -> t
val append : t -> t -> t

(* base is the last segment that is not empty (a/b/ gives b/). parent is
 * the path without that segment, as a directory (a/b gives a/, and a
 * gives ./). *)
val base : t -> t
val parent : t -> t

(* The extension is what follows the last dot of the last segment, with
 * the dot, when that dot is not the first character of the segment.
 * has_ext tells whether the extension is e. set_ext puts e in the
 * extension's place, or adds it. rem_ext removes the extension. *)
val has_ext : string -> t -> bool
val set_ext : string -> t -> t
val rem_ext : t -> t
