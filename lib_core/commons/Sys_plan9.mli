(* Plan 9's own calls, for an ix program that also runs there
 * ([Sys.os_type] is "Plan9": see plan_rio.md). These are the calls
 * that OCaml's Unix has no name for. There are two files: this
 * directory's file is for every other system, where each function
 * does what it can; ../system/plan9/'s file is for Plan 9
 * (mkfiles/mkconfig's P9DIR).
 *
 * What is here is what makes Plan 9 itself: a process's namespace,
 * and the calls that build it. Each process has its own table of
 * what a name means. The table starts as a copy of its parent's, or
 * is shared with the parent (rfork chooses). bind and mount change
 * that table, and nothing on a disk:
 *
 *     bind caps "/usr/glenda/bin/rc" "/bin" mafter
 *
 *     /bin, before:   [ /arm/bin ]
 *     /bin, after:    [ /arm/bin | /usr/glenda/bin/rc ]     a union: a
 *                       name is looked for in each, in that order
 *
 *     mount caps fd "/n/remote" mrepl ""
 *
 *     /n/remote/x  -->  a 9P message on fd  -->  whoever serves fd:
 *                       a disk's file system, a program, a machine
 *
 * Where it stands: it is used for the shell's children and their
 * status (Process); by mini-rio, which gives each window a namespace
 * of its own with its own /dev/cons; by the utilities bind, mount and
 * unmount; and by those that read a directory as Plan 9 has it (ls,
 * cp, mv, chmod). [dir] is also the entry that the 9P library packs
 * and serves (P9_wire, P9_server). The kernel's side of these calls
 * is in mini-9pi.
 *
 * plan9-is-cleaner:
 * In Unix there is one table of mounts for the whole machine, and only
 * root changes it. So what a program sees is arranged by variables
 * and conventions around it: $PATH for where the commands are,
 * $DISPLAY for which screen, $TMPDIR. In Plan 9 a process arranges
 * its own tree:
 * commands are in /bin because the binaries for this machine and
 * the user's scripts were bound there (rc's path is /bin and the
 * current directory), and the screen is /dev/draw because the
 * window system mounted itself there for that window. It needs no
 * privilege, since nobody else sees the change.
 *
 * plan9-is-cleaner:
 * rfork is one call with a bit for each thing that a child may share
 * or get a copy of. Unix has fork (everything copied), vfork, and a
 * threads library for shared memory. Linux's clone is the same
 * design, inspired by rfork. Linux's namespaces, of which containers
 * are made, are this per-process table coming back ten to twenty
 * years later (2002 to 2013), one kind at a time.
 *
 * plan9-is-cleaner:
 * A process ends with words, not a number, and the parent reads them
 * as they are ([last_words], rc's $status). Exit explains this.
 *
 * References: Rob Pike, Dave Presotto, Ken Thompson, Howard Trickey
 * and Phil Winterbottom, "The Use of Name Spaces in Plan 9" (1992);
 * fork(2), bind(2), stat(2) and exits(2) of Plan 9's manual;
 * namespace(4) for the tree a user starts with. *)

(* For a child that was waited for (given its pid): its last words, as
 * the kernel gives them ("ls 12: no such file"), which rc keeps as
 * $status. It is "" when the child had none, and on another system. *)
val last_words : int -> string
(* And the time the child took, in milliseconds: in the program, in the
 * kernel for it, and from its start to its end. These are zeros on
 * another system. *)
val last_times : int -> int * int * int

(* The process ends with these words, or with none ("") when all went
 * well. On another system it ends with 0 or 1. *)
val exits : string -> 'a

(* [rfork caps flags]: Plan 9's fork, which says what the child shares
 * with its parent and what it gets a copy of. It returns 0 in the
 * child, and the child's pid in the parent. The flags are:
 *  - [rfproc]: make a new process (without it, the caller itself
 *    changes);
 *  - [rffdg]: a copy of the descriptors;
 *  - [rfnameg]: a copy of the namespace (its binds and mounts are then
 *    its own, as for a window's /dev);
 *  - [rfenvg]: a copy of the environment;
 *  - [rfnoteg]: a note group of its own (so an interrupt is for it
 *    alone).
 * On another system it is fork. *)
val rfproc : int
val rffdg : int
val rfnameg : int
val rfenvg : int
val rfnoteg : int
(* (and [rfnowait]: the parent will not wait for this child) *)
val rfnowait : int
val rfork : < Cap.fork; .. > -> int -> int

(* The namespace. The flag of bind and mount says where the new
 * directory goes in the union of the old one (it replaces it, or goes
 * before or after it), and whether files are created there. *)
val mrepl : int
val mbefore : int
val mafter : int
val mcreate : int
val mcache : int

(* [bind caps name old flag]: old now also shows name. It raises
 * Unix_error when the kernel refuses (with the kernel's words, in
 * Unix.error_message), and on another system (ENOSYS). *)
val bind : < Cap.bind; .. > -> string -> string -> int -> unit

(* [mount caps fd old flag spec]: old is now the tree that a 9P server
 * serves on fd, and spec says which tree is asked of the server. There
 * is no authentication (as with mount's -n). *)
val mount : < Cap.mount; .. > -> Unix.file_descr -> string -> int -> string -> unit

(* [unmount caps name old]: what was bound or mounted on old is no
 * longer there. With a name, only that member of old's union goes. *)
val unmount : < Cap.mount; .. > -> string option -> string -> unit

(* A file's entry in its directory, as 9P has it. It has:
 *  - its names (uid, gid, and muid, the last one who wrote it);
 *  - the device that serves it (its letter and its number);
 *  - its qid, the file's identity for the server (a path, a version,
 *    a type);
 *  - its mode in two parts (the top byte, with [dmdir]..., and the
 *    nine permission bits);
 *  - its times and its length.
 * On another system it comes from Unix's stat: the device is 'M', and
 * the owners' numbers stand for their names. *)
type dir = {
  name : string; uid : string; gid : string; muid : string;
  dev_type : char; dev : int;
  qid_path : int64; qid_vers : int64; qid_type : int;
  mode_type : int; perm : int;
  atime : float; mtime : float; length : int;
}
(* The bits of mode_type (and of qid_type too): a directory, an
 * append-only file, a file that only one may open at a time, an
 * authentication file, a temporary file *)
val dmdir : int
val dmappend : int
val dmexcl : int
val dmauth : int
val dmtmp : int

(* They raise Unix_error when they fail *)
val dirstat : < Cap.readdir; .. > -> string -> dir
(* The entries of a directory *)
val dirread : < Cap.readdir; .. > -> string -> dir list
(* Whether it is a symbolic link (Linux has them; dirstat tells what
 * the link points to, so a walk of a tree must ask). Never true on
 * Plan 9, which has bind in their place. *)
val is_link : < Cap.readdir; .. > -> string -> bool
(* Whether it is neither a file nor a directory, after following links:
 * a pipe, a device or a socket (on Linux), where an open or a read may
 * wait forever. Never true on Plan 9 yet, whose devices are files in
 * /dev. *)
val is_device : < Cap.readdir; .. > -> string -> bool

(* Each of these changes one thing of a file's entry (with 9P's wstat,
 * where the rest of the entry is marked unchanged). They raise
 * Unix_error when the server refuses.
 *  - [rename caps path name] changes its name, in the directory it is
 *    in (moving it to another directory is a copy, which mv does);
 *  - [chmod caps path mode_type perm] changes the two parts of its
 *    mode, as in dir;
 *  - [set_mtime caps path secs] changes when it was last written. *)
val rename : < Cap.open_out; .. > -> string -> string -> unit
val chmod : < Cap.open_out; .. > -> string -> int -> int -> unit
val set_mtime : < Cap.open_out; .. > -> string -> float -> unit
