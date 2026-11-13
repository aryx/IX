(* A repository's objects, wherever they are: in packs first, then in
 * loose files (git9's readobject and readidxobject, and its object
 * cache).
 *
 * The packs are opened when they are first needed, and again when an
 * object is not found, since a fetch may have added a pack (git9's
 * refreshpacks). *)

(* (The clock is for a file's time in a walk and for waiting on a lock;
 * env is for a temporary file's name, made from the pid.) *)
type caps = < Cap.open_in; Cap.open_out; Cap.clock; Cap.env >

type t = {
  caps : caps;
  git : Fpath.t;          (* the .git directory *)
  mutable packs : Pack.t list option;
  cache : (Hash.t, Object.t) Hashtbl.t;
}

exception Missing of Hash.t

val open_git : caps -> Fpath.t -> t

val read_raw : t -> Hash.t -> (Object.Kind.t * string) option
val read : t -> Hash.t -> Object.t   (* or Missing *)
val mem : t -> Hash.t -> bool
val write : t -> Object.t -> Hash.t

(* the unique object whose hex name starts with the prefix; the prefix
 * must have at least 8 digits, as git9's expandprefix wants *)
val expand : t -> string -> Hash.t option

(* all objects, loose then packed (git9's ols.c) *)
val all : t -> Hash.t list

(* forgets the packs, after one is added or removed *)
val refresh : t -> unit

(* checks a pack's bytes (its trailing SHA-1), indexes them, and saves
 * them as .git/objects/pack/HASH.pack and .idx, git9's names. It
 * returns the hash. A pack already there is left as it is, with git9's
 * warning. *)
val add_pack : t -> warn:(string -> unit) -> string -> string
