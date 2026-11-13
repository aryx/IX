(* The repository a command runs in is the nearest directory, from the
 * current one up, that holds .git/HEAD (git9's findrepo and gitinit). *)

type t = {
  root : Fpath.t;       (* the work tree *)
  rel : int;            (* how many levels below root the command ran *)
  cwd : string;         (* that directory, relative to root, "" at root *)
  store : Store.t;
}

exception Not_a_repository

val find : Store.caps -> t

(* a repository at a known root *)
val at : Store.caps -> Fpath.t -> t

(* Plan 9's cleanname: "./a//b/../c" becomes "a/c", "" and "./" become
 * ".", and a leading ".." stays *)
val cleanname : string -> string

(* a command's path argument, made relative to the root and cleaned,
 * as git9's programs do: "./CWD/ARG", or an absolute path inside the
 * root. It is None for a path outside the root. *)
val relative : t -> string -> string option
