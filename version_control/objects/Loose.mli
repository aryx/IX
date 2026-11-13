(* Loose objects are one file per object, .git/objects/ce/013625030...,
 * holding "KIND SIZE\000CONTENT" deflated (git9's readloose and
 * writeobj).
 *
 * A file is written once and never changed, since its name is its
 * content's hash. It is written to a temporary name and then renamed,
 * so a reader never sees half an object. *)

val path : Fpath.t -> Hash.t -> Fpath.t

(* reads from the .git directory; None if the object is absent *)
val read : < Cap.open_in; .. > -> Fpath.t -> Hash.t -> (Object.Kind.t * string) option

(* writes the object unless it is present, and returns its hash *)
val write : < Cap.open_out; Cap.env; .. > -> Fpath.t -> Object.Kind.t -> string -> Hash.t

(* the hashes of all loose objects *)
val all : Fpath.t -> Hash.t list
