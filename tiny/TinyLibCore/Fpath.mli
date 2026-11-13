(* Fpath: a subset of lib_core/system/'s module (see Stdlib.mli), which
 * is itself a subset of Daniel Bünzli's fpath. A file's path has a type
 * of its own, so that a file's name and a text cannot be passed one for
 * the other. A path is a string that is not empty, with its segments
 * separated by /; a path that ends in / names a directory.
 * Fpath_.Operators has the shorter names / and !!. *)
type t

(* [v s] is the path of a string (// counts as one /); it raises
 * Invalid_argument for "" *)
val v : string -> t
val to_string : t -> string

(* p / seg adds a segment to p; p // q is q under p, or q itself when it
 * is absolute *)
val add_seg : t -> string -> t
val append : t -> t -> t

(* [base] is the last segment that is not empty (a/b/ gives b/).
 * [parent] is the path without it, as a directory (a/b gives a/, and a
 * gives ./). *)
val base : t -> t
val parent : t -> t

(* The extension is what follows the last dot of the last segment,
 * including the dot, when that dot is not the segment's first
 * character. [has_ext e p] says whether p's extension is e; [set_ext e
 * p] is p with e in place of its extension, or added; [rem_ext p] is p
 * without its extension. *)
val has_ext : string -> t -> bool
val set_ext : string -> t -> t
val rem_ext : t -> t
