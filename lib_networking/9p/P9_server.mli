(* A file server's loop (plan_rio.md, stage 5; Plan 9's lib9p, the part
 * a simple server asks): 9P's requests read from a descriptor, the fids
 * kept here, each request given to the file system's functions, the
 * response written. One request at a time (but a read answered later:
 * [Later]).
 *
 * A file system is functions on its own files ('f: a file or a
 * directory of its tree, as it finds it). One that refuses raises
 * [Error] with the words the client gets (Rerror).
 *
 * What is done here so that a file system need not: the table of
 * fids (a walk makes one, a clunk forgets it; one in use, unknown or
 * not open is refused before the file system hears of it), a walk of
 * several names made of [walk]s of one, a directory read as whole
 * entries from [entries] with the offsets a client may ask, a read's
 * count cut to the message size agreed, the requests that wait. A
 * program's read of a file, down to the function that answers it:
 *
 *     cat /dev/label                      in a window
 *        | read(fd)                       a system call
 *     mini-9pi's kernel: the file is a mounted one (its Devmnt)
 *        | Tread fid, offset, count       on the pipe posted in /srv
 *     [request]: the fid's 'f found in the table
 *        | fs.read f offset count         the program's own function
 *     Rread, the bytes                    back the same way
 *
 * Where it stands: mini-rio's files (its Fileserver: 'f a window and
 * one of its devices) and the DOS file system's (Dossrv: 'f a file of
 * the FAT) are two records of these functions. rio does not call
 * [serve]: it has a mouse and a keyboard to listen to as well, so it
 * makes a server and gives it each request as it comes ([make],
 * [request]).
 *
 * reframe:
 * A window system is a file server. A window is a directory with a
 * cons to read the keyboard from and write text to, a mouse, a label
 * and a few more; a program in a window opens /dev/cons as it would
 * on the bare machine, and gets the window's, because that directory
 * was mounted there for it. So a program needs no library to run in
 * a window, a window system can run in a window of another (it finds
 * the same files it would find at boot), and a program on another
 * machine draws here once the files are mounted there. This is Rob
 * Pike's design for 8 1/2 (1991), kept by rio.
 *
 * others:
 * Unix came to the same place by another way. A file system outside
 * the kernel was first done by pretending to be an NFS server on the
 * same machine (the automounters of the late 1980s); FUSE (in Linux
 * since 2005) is a kernel module for it, whose table of operations
 * (getattr, open, read, readdir...) is this record. But there the
 * kernel resolves a path itself and asks about one name at a time
 * with its own numbers for files; there is no walk and no fid, and
 * the protocol stays between one kernel and its helper, not something
 * to send to another machine.
 *
 * References: 9p(2), Plan 9's lib9p (the Srv structure, a function
 * per request, and its file trees, not taken here); Rob Pike, "8 1/2,
 * the Plan 9 Window System" (USENIX Summer 1991), and "Rio: Design of
 * a Concurrent Window System" (slides, 2000); the
 * intro(5) page for what each request must do. *)

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
  (* a new file in a directory: its name, permissions (the nine bits,
   * and 9P's top byte at bits 16 on: [Sys_plan9.dmdir lsl 16] for a
   * directory; an int of 31 bits has no bit 31), open mode *)
  create : 'f -> string -> int -> int -> 'f;
  remove : 'f -> unit;
  wstat : 'f -> Sys_plan9.dir -> unit;
  (* a fid of it let go; whether it was open *)
  clunk : 'f -> bool -> unit;
}

(* a file system that only reads: these refuse *)
val read_only : string
val no_write : 'f -> int -> string -> int
val no_create : 'f -> string -> int -> int -> 'f
val no_remove : 'f -> unit
val no_wstat : 'f -> Sys_plan9.dir -> unit

(* the requests of the descriptor served, to its end *)
val serve : 'f fs -> Unix.file_descr -> unit

(* The same, for a program that has its own loop (a window system: its
 * requests come among other events): a server made with the function
 * that sends a response's bytes, then each request's bytes given to
 * it ([P9_wire.read]'s, or a message cut out of what a Source gave). *)
type 'f t
val make : 'f fs -> (string -> unit) -> 'f t
val request : 'f t -> string -> unit

(* A read that cannot be answered now (the console's, before a line is
 * typed): [read] raises [Later register], and register is given the
 * function to call with the bytes, when there are some. It says
 * whether they were sent: false when no one waits for them any more
 * (the read was flushed, its process interrupted or ended, or its file
 * closed), and then they are for another reader. A write too may be
 * answered later ([write] raises it: a window that holds its output):
 * the function is then called with "" when the bytes are taken. *)
exception Later of ((string -> bool) -> unit)

(* [post caps name]: a pipe, one end posted as /srv/name (Plan 9's: a
 * program mounts it), the other returned, to serve *)
val post : < Cap.open_out; .. > -> string -> Unix.file_descr
