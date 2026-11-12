(* TinyKernel's files: a tree of ML values, looked up by the names of a
 * path. The tree combines the files carried in the boot image, /dev,
 * the disks' files (KFS), and unions of directories. This module also
 * defines what a process's descriptor can refer to: an open file.
 *
 *     top ── Union ── Disk (fs, 0, 1)          the first disk's root
 *               ├──── Dir: boot (root),        the image's files,
 *               │          dump,               the snapshots,
 *               │          src (Disk (fs2, 0, 1))  the second disk's root
 *               └──── root: Dir                the image's files: bin,
 *                       └── dev: Tty Screen    examples, lib, and dev
 *                                Pointer Speaker
 *
 * plan9-is-cleaner:
 * As in Plan 9, the devices are files (/dev/draw, /dev/mouse,
 * /dev/audio) that a program opens and writes, and a window system
 * gives its windows' programs files with the same names. The tree a
 * path starts from is a union, like Plan 9's bind -a, not a mount
 * table.
 *)

(* Devices are nodes too: /dev/console (Tty), /dev/draw, /dev/mouse,
 * /dev/audio, and /dev/ps, made when it is read. A file of the image
 * (Rom: address, size) is read in place until written, so the collector
 * does not copy the megabyte of programs. A Disk file is a tree (0 the
 * live one) and an inode. A union is directories seen as one, as by
 * Plan 9's bind -a: a lookup tries each in turn, a new file goes in the
 * first. Data's bytes double when a write goes past them. *)
type node =
  | Dir of (string * node) list ref
  | Data of data
  | Rom of int * int
  | Tty
  | Screen
  | Pointer
  | Speaker
  | Ps
  | Disk of KFS.fs * KFS.tree * KFS.inode
  | Union of node list
and data = { mutable dbytes : bytes; mutable dsize : int; mutable dtime : int }

(* At most 512 bytes in buf. A read of an empty pipe with no writer is
 * the end of file. *)
type pipe =
  { mutable buf : string; mutable readers : int; mutable writers : int }

(* The collector frees open files, so most do not count descriptors. A
 * pipe counts its ends, as a reader must learn that no writer is left;
 * a draw connection does too, as its images are outside the heap. *)
type file =
  | Open of opened
  | Reader of pipe
  | Writer of pipe
  | Console
  | Draw of drawing
  | Peek of box
  | Post of box
  | Link of link
  | Call of call
  | Voice of voice
  | Trace of trace
(* [listing]: a directory's entries, made by a read at offset 0. *)
and opened = { node : node; mutable off : int; writes : bool;
               mutable listing : string option }
and drawing = { conn : KGraphics.conn; mutable refs : int }

(* A box keeps only what was last written, and whether it was read
 * since: a mouse is a position, not a history, so a late reader finds
 * where it is now and a writer never waits. The kernel's box is the
 * mouse; a window system's boxes are its windows' mice. *)
and box = { mutable last : string; mutable fresh : bool; mutable posters : int }

(* A link to an echo server (plan_tiny_network.md). A write sends a
 * question, a read gives one whole answer. Questions carry lid, and
 * answers bring it back. *)
and link = {
  peer : string;
  lid : int;
  mutable asked : int;
  mutable heard : string list;
  mutable holders : int;
}

(* A connection by KNetwork's IL. A read gives one whole message, or 0
 * when the other end is done; closing the last descriptor tells it. *)
and call = { il : KNetwork.il; mutable callers : int }

(* An open of /dev/audio; ahead is the sample where its next sound goes. *)
and voice = { mutable ahead : int }

(* A process traced by the debugger (plan_tiny_debugger.md). [stops]
 * are breakpoints with the word each replaced. [call] is the call it is
 * stopped before or was let into; [ret] the call whose end it stops at.
 * [over] is the breakpoint whose original word it runs; the 0 goes back
 * after. [follow]: its children are traced too (trace -f). *)
and trace = {
  tpid : int;
  tracer : int;
  mutable stops : (int * int) list;
  mutable said : string list;
  mutable watchers : int;
  mutable calls : bool;
  mutable call : int option;
  mutable ret : int option;
  mutable step : bool;
  mutable over : int option;
  mutable follow : bool;
}

val data : string -> data

(* [top] is where a path starts: root (the image's files and /dev), or
 * with a disk a union with the disk's root first. *)
val root : node
val top : node ref

(* [names cwd path] removes "." and ".." from the text alone, as Plan
 * 9's cleanname does. *)
val names : string list -> string -> string list

val is_dir : node -> bool

val walk : node -> string list -> node option

(* The directory where a path's last name is (or would be made). *)
val dir_of : string list -> (node * string) option

(* 4 bytes, little-endian, as in a directory's entries. *)
val word : int -> string

(* The 80-byte entry ls reads: name, type, links, size and date. *)
val entry : string -> node -> string

(* Set by KProcs: a line per process with pid, parent, state, KB, command. *)
val ps_hook : (unit -> string) ref

(* For a directory, its entries. *)
val contents : node -> string

(* [load a] reads the files the image carries after the kernel, at a. *)
val load : int -> unit
