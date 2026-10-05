(* A file server's loop (plan_rio.md, stage 5; Plan 9's lib9p, the part
 * a simple server asks): 9P's requests read from a descriptor, the fids
 * kept here, each request given to the file system's functions, the
 * response written. One request at a time.
 *
 * A file system is functions on its own files ('f: a file or a
 * directory of its tree, as it finds it). One that refuses raises
 * [Error] with the words the client gets (Rerror). *)

exception Error of string

type 'f fs = {
  (* the root of the tree asked (the user, the tree's name: mount's spec) *)
  attach : string -> string -> 'f;
  (* one name down from a directory (".." is up) *)
  walk : 'f -> string -> 'f;
  (* its entry: its qid is there *)
  stat : 'f -> Sys_plan9.dir;
  (* opened with this mode (OREAD 0, OWRITE 1, ORDWR 2, OTRUNC 16...) *)
  opened : 'f -> int -> unit;
  (* a file's bytes: an offset, a count *)
  read : 'f -> int -> int -> string;
  (* a directory's entries *)
  entries : 'f -> Sys_plan9.dir list;
  (* bytes written at an offset: how many *)
  write : 'f -> int -> string -> int;
  (* a new file in a directory: its name, permissions (the top byte's
   * DMDIR for a directory, as a mode's), open mode *)
  create : 'f -> string -> int -> int -> 'f;
  remove : 'f -> unit;
  wstat : 'f -> Sys_plan9.dir -> unit;
  (* a fid of it let go *)
  clunk : 'f -> unit;
}

(* a file system that only reads: these refuse *)
val read_only : string
val no_write : 'f -> int -> string -> int
val no_create : 'f -> string -> int -> int -> 'f
val no_remove : 'f -> unit
val no_wstat : 'f -> Sys_plan9.dir -> unit

(* the requests of the descriptor served, to its end *)
val serve : 'f fs -> Unix.file_descr -> unit

(* [post caps name]: a pipe, one end posted as /srv/name (Plan 9's: a
 * program mounts it), the other returned, to serve *)
val post : < Cap.open_out; .. > -> string -> Unix.file_descr
