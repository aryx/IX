(* TinyKernel's files: a tree of ML values, the image's files, /dev,
 * the disk's (TinyKernelFS) and unions of them, looked up by a path's
 * names; and what a process's descriptor can be, an open file.
 *
 *     top ── Union ── Disk (0, 1)              the disk's root
 *               ├──── Dir: boot (root), dump   the image's, the snapshots
 *               └──── root: Dir                 bin, src, examples, lib,
 *                       └── dev: Tty Screen     dev
 *                                Pointer Speaker
 *
 * plan9-is-cleaner:
 * the devices are files, /dev/draw, /dev/mouse, /dev/audio, as Plan 9's
 * are: a program opens and writes them, and a window system gives its
 * windows' programs files of the same names; and the tree a path starts
 * from is a union, Plan 9's bind -a, not a mount table.
 *)

(* A directory is a list of names in the order they were made; the
 * console is a node too, /dev/console, and the screen, the mouse and
 * the speaker, /dev/draw, /dev/mouse and /dev/audio, and the processes,
 * /dev/ps, a line each, made when it is read (the programs are
 * in /bin, examples to look at in /examples). A file of the image is
 * read where the image has it (its address, its size) until it is
 * written: the programs, a megabyte of them, are then not the
 * collector's to copy at each collection (old: each a string, Data; a
 * collection was 3 million instructions).
 * A file or a directory on the disk (TinyKernelFS.ml) is a tree and an
 * inode's number: tree 0 is the live one, the others are the snapshots.
 * A union is several directories seen as one, as Plan 9's bind -a makes:
 * a name is looked up in each in turn, and what is made goes in the
 * first. A file written in memory is its bytes and its size, the bytes
 * doubled when a write goes past them (old: a string, made again at
 * each write: a database that grows by appends took a second for each
 * statement, tiny-db's) *)
type node =
  | Dir of (string * node) list ref
  | Data of data
  | Rom of int * int
  | Tty
  | Screen
  | Pointer
  | Speaker
  | Ps
  | Disk of int * int
  | Union of node list
and data = { mutable dbytes : bytes; mutable dsize : int; mutable dtime : int }

(* a pipe: the bytes written not yet read (512 at most), its readers'
 * and its writers' descriptors (a read of an empty pipe with no writer
 * left is its end) *)
type pipe =
  { mutable buf : string; mutable readers : int; mutable writers : int }

(* an open file: a node (its offset, whether it is written), a pipe's
 * end, the console, a connection to the screen, a box's end. The
 * collector frees them; only pipes count their ends, as a reader must
 * learn that no writer is left, and a connection its descriptors, as
 * its images are not the collector's *)
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
(* (listing: a directory's entries, made at its read from the start,
 * and the reads after take theirs from it) *)
and opened = { node : node; mutable off : int; writes : bool;
               mutable listing : string option }
and drawing = { conn : TinyKernelGraphics.conn; mutable refs : int }

(* a box: a pipe that keeps only what was last written, and whether it
 * was read since (the mouse is a place, not its history: a reader that
 * is late finds where it is, and a writer never waits). Peek reads it,
 * Post writes it; the kernel's own is the mouse, a window system's are
 * its windows' mice *)
and box = { mutable last : string; mutable fresh : bool; mutable posters : int }

(* a link to another machine (plan_tiny_network.md): so far an echo's.
 * What is written is sent there as a question, and a read gives an
 * answer's bytes, whole, in the order they came; a link has a number,
 * which its questions carry and their answers bring back *)
and link = {
  peer : string;
  lid : int;
  mutable asked : int;
  mutable heard : string list;
  mutable holders : int;
}

(* a connection to a program of another machine (TinyKernelNetwork.ml's IL):
 * a write is a message, which arrives once and in order or is sent
 * again; a read gives one whole, 0 when the other end is done; and its
 * descriptors, the last one's close saying the end *)
and call = { il : TinyKernelNetwork.il; mutable callers : int }

(* a voice of the speaker (an open of /dev/audio): where in the samples its
 * next one goes *)
and voice = { mutable ahead : int }

(* a process traced by another, its tracer (debug: plan_tiny_debugger.md):
 * their pids, the breakpoints (an address and the word that was there),
 * what is said to the tracer and not yet read, and the tracer's
 * descriptors on it; whether it stops at its calls (trace), the call
 * it is stopped before or let in (-1: none), the call whose end it
 * waits for, to stop then (-1: none); whether it runs one instruction
 * and stops (a step), and the breakpoint it runs the word of, the 0
 * written again after (-1: none); whether its children are traced too
 * (trace -f) *)
and trace = {
  tpid : int;
  tracer : int;
  mutable stops : (int * int) list;
  mutable said : string list;
  mutable watchers : int;
  mutable calls : bool;
  mutable call : int;
  mutable ret : int;
  mutable step : bool;
  mutable over : int;
  mutable follow : bool;
}

(* a file in memory, of a string's bytes *)
val data : string -> data

(* The image's files (and /dev), and the tree a path starts from: the
 * same with no disk; with one, a union, the disk's root first *)
val root : node
val top : node ref

(* [names cwd path]: a path's names from the root (".", ".." removed by
 * the text, as Plan 9's cleanname) *)
val names : string list -> string -> string list

val is_dir : node -> bool

(* the node at a path's names from a node, if any *)
val walk : node -> string list -> node option

(* the directory a path's last name is in (where it would be made) and
 * that name *)
val dir_of : string list -> (node * string) option

(* a number as 4 bytes, little-endian (a directory's entries') *)
val word : int -> string

(* [entry name node]: the 80 bytes of a directory's entry for it (its
 * name, its type, its links, its size, its date), which ls reads *)
val entry : string -> node -> string

(* /dev/ps's lines (TinyKernelProcs's): a process's pid, its parent's,
 * its state, its memory in KB, its command line *)
val ps_hook : (unit -> string) ref

(* what a node holds, a directory's entries for one *)
val contents : node -> string

(* the files the image carries after the kernel, from that address *)
val load : int -> unit
