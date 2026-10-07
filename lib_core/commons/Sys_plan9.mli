(* Plan 9's own, for a program of ix's that also runs there
 * ([Sys.os_type] is "Plan9": plan_rio.md): what OCaml's Unix has no
 * name for. Two files: this directory's, for every other system, where
 * a function says what it can; and ../system/plan9/'s, Plan 9's
 * (mkfiles/mkconfig's P9DIR). *)

(* a child waited for (its pid): its last words as the kernel gives
 * them ("ls 12: no such file"), which rc keeps as $status; "" when it
 * had none, and on another system *)
val last_words : int -> string
(* and the time it took, in milliseconds: in the program, in the kernel
 * for it, from its start to its end; zeros on another system *)
val last_times : int -> int * int * int

(* the process ends, with these words; none ("") when all went well.
 * On another system, with 0 or 1. *)
val exits : string -> 'a

(* [rfork caps flags]: Plan 9's fork, which says what the child shares
 * with its parent and what it gets a copy of: 0 in the child, its pid
 * in the parent. With [rfproc] a new process (without, the caller
 * itself changes); [rffdg] a copy of the descriptors, [rfnameg] of the
 * namespace (its binds and mounts are then its own: a window's /dev),
 * [rfenvg] of the environment; [rfnoteg] a note group of its own (an
 * interrupt for it alone). On another system: fork. *)
val rfproc : int
val rffdg : int
val rfnameg : int
val rfenvg : int
val rfnoteg : int
(* (and [rfnowait]: the parent will not wait for this child) *)
val rfnowait : int
val rfork : < Cap.fork; .. > -> int -> int

(* The namespace. bind's and mount's flag: where the new directory goes
 * in the old one's union (it replaces it, or goes before or after), and
 * whether files are created there. *)
val mrepl : int
val mbefore : int
val mafter : int
val mcreate : int
val mcache : int

(* [bind caps name old flag]: old is now also name. Unix_error when the
 * kernel refuses (its words: Unix.error_message), and on another
 * system (ENOSYS). *)
val bind : < Cap.bind; .. > -> string -> string -> int -> unit

(* [mount caps fd old flag spec]: old is now the tree served on fd by a 9P
 * server, spec the tree asked of it. No authentication (mount's -n). *)
val mount : < Cap.mount; .. > -> Unix.file_descr -> string -> int -> string -> unit

(* [unmount caps name old]: what was bound or mounted on old is no
 * longer there; with a name, only that one of old's union *)
val unmount : < Cap.mount; .. > -> string option -> string -> unit

(* A file's entry in its directory, as 9P has it: its names (the last
 * who wrote it), the device that serves it (its letter and number),
 * its qid (the file's identity for the server: a path, a version, a
 * type), its mode in two parts (the top byte: [dmdir]...; the nine
 * permission bits), its times and its length. On another system, from
 * Unix's stat: the device 'M', the owners' numbers as names. *)
type dir = {
  name : string; uid : string; gid : string; muid : string;
  dev_type : char; dev : int;
  qid_path : int64; qid_vers : int64; qid_type : int;
  mode_type : int; perm : int;
  atime : float; mtime : float; length : int;
}
(* mode_type's bits (qid_type's too): a directory, an append-only file,
 * one open once at a time, an authentication file, a temporary one *)
val dmdir : int
val dmappend : int
val dmexcl : int
val dmauth : int
val dmtmp : int

(* Unix_error when they fail *)
val dirstat : < Cap.readdir; .. > -> string -> dir
(* a directory's entries *)
val dirread : < Cap.readdir; .. > -> string -> dir list

(* One thing of a file's entry changed (9P's wstat, the rest of the
 * entry said unchanged); Unix_error when the server refuses.
 * [rename caps path name]: its name, in the directory it is in (another
 * directory is a copy: mv's); [chmod caps path mode_type perm]: its
 * mode's two parts, as dir's; [set_mtime caps path secs]: when it was
 * last written. *)
val rename : < Cap.open_out; .. > -> string -> string -> unit
val chmod : < Cap.open_out; .. > -> string -> int -> int -> unit
val set_mtime : < Cap.open_out; .. > -> string -> float -> unit
