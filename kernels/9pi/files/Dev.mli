(* Plan 9's devices (Dev, devtab, dev.c): each a record of functions on
 * channels, found by its letter ('#c' the console). A system call on a
 * file is its device's function on the file's channel. Also what most
 * devices share: a fixed tree of files (Dirtab, devgen), and the
 * directory entry's machine-independent form (convD2M, convM2D: what
 * stat, a directory's read and 9P carry).
 *
 *     the table (Main fills it)          a channel   { dev = 'c'; ... }
 *     '/' root   'c' cons   'e' env          |
 *     'p' proc   'k' sys    '|' pipe         | Dev.find c.dev
 *     'd' dup    'P' arch   'M' mnt          v
 *     's' srv    'i' draw   'm' mouse    { name = "cons";
 *     'S' sd     'l' ether  'I' ip         attach; walk; clone; clunk;
 *     'u' usb    'F' Kdos   'x' Kfs        stat; dirs; open_; create;
 *                                          read; write; remove; wstat;
 *                                          close }
 *
 * A device is a small file server inside the kernel: it has a tree
 * of its own, names it itself, and answers for each of its files.
 * Most are a dozen lines over [default] and the fixed tree below:
 * Devpipe is the one to read first, then Devenv (files that come and
 * go), then Devproc (a tree computed from the processes).
 *
 * The functions are 9P's messages, one for one (P9): attach, walk,
 * open, create, read, write, clunk, remove, stat, wstat. That is the
 * design. Devmnt, the device 'M', fills the record with functions
 * that send each as a message to a program and wait for its answer;
 * so a file served by a program anywhere and a file computed by the
 * kernel are the same thing to Kchan and Sysfile, which only ever
 * call this record.
 *
 * An entry on the wire (stat, a directory's read, 9P's Rstat), the
 * sizes in bytes, numbers the low byte first:
 *
 *     size[2] type[2] dev[4] qid.type[1] qid.vers[4] qid.path[8]
 *     mode[4] atime[4] mtime[4] length[8]
 *     name[s] uid[s] gid[s] muid[s]           s: a length[2], the bytes
 *
 * 41 bytes and four strings: 49 at least. The owner is a name, not a
 * number: no table of users must be the same on two machines.
 *
 * plan9-is-cleaner:
 * No ioctl. Unix's devices are files for their data and, for all the
 * rest, a call beside the file: ioctl(fd, request, arg), a number
 * and a structure per device and per request, thousands by now, none
 * of which passes through a pipe, a shell or a network. Here what is
 * not data is another file, written text: "rawon" to consctl
 * (Devcons), "part dos 8192 131072" to a disk's ctl (Devsd), "kill"
 * to a process's ctl (Devproc), "connect 10.0.2.2!80" to a
 * connection's (Devip). echo is then the configuration tool for
 * everything, a script can do what a C program was needed for, and
 * a device on another machine is driven the same way.
 *
 * plan9-is-cleaner:
 * No device nodes. In Unix the kernel's table of drivers is indexed
 * by a number, and a file of a disk (made by mknod, by root, in
 * /dev) carries two numbers that say which driver and which unit:
 * the name is a convention, the numbers must match the kernel, and a
 * /dev that is stale lies. Here the driver serves its own names, and
 * /dev is only where a process chose to bind them (Kchan).
 *
 * others:
 * Unix's tables, cdevsw and bdevsw (character and block devices:
 * open, close, read, write, ioctl, and strategy for the blocks), are
 * where this record comes from. xv6 keeps the least of it: devsw, a
 * read and a write, with the console its one entry. Linux's
 * file_operations has some thirty functions, and each file system,
 * not only each device, fills one: there the generality is in the
 * kernel's interface, here in the protocol.
 *
 * References: intro(3) of the Plan 9 manual (the devices), stat(5)
 * (the entry's bytes). principia's Kernel.nw (dev.c, devtab). Rob
 * Pike and others, "Plan 9 from Bell Labs" (1995), for why
 * everything is a file server. *)

open Types
open Errors

(* a device: its letter (a byte of mini-9pi's channels), its letter as
 * the user names it (a rune: '#Ι' kbin's is U+0399, its byte a private
 * one), ... *)
type t = {
  dc : char;
  drune : int;
  name : string;
  (* a channel on the device's root; the spec after "#c" *)
  attach : string -> chan;
  (* [walk c nc name]: one step from a directory c to nc (c's copy): the
   * name's qid ("..": the parent's), or Error *)
  walk : chan -> chan -> string -> qid;
  (* [clone c nc]: nc, c's copy, made a file of its own (devmnt: a new
   * fid); an unopened channel dropped (devmnt: its fid clunked) *)
  clone : chan -> chan -> unit;
  clunk : chan -> unit;
  (* the file's entry; a directory's entries *)
  stat : chan -> dir;
  dirs : chan -> dir list;
  (* the channel opened: itself, or another (#s's posted channel, #d's
   * descriptor) *)
  open_ : chan -> mode -> chan;
  (* [create c name mode perm]: c, a directory, becomes the new file,
   * opened *)
  create : chan -> string -> mode -> int -> unit;
  (* [read c n off]: at most n bytes at off (not a directory's: dirs);
   * [write c s off]: how many *)
  read : chan -> int -> int -> string;
  write : chan -> string -> int -> int;
  remove : chan -> unit;
  (* the entry changed (its name, its length, its mode...) *)
  wstat : chan -> dir -> unit;
  close : chan -> unit;
}

(* a device (its letter, its name: "cons") whose every function fails
 * (Eperm), but close: the base the devices override *)
val default : char -> string -> t

(* the devices, and one by its letter (Error: '#x' unknown) *)
val register : t -> unit
val find : char -> t

(* a device by the rune of its letter; a letter's rune; a rune in UTF-8 *)
val find_rune : int -> t

(* a registered device's letter made a rune *)
val set_rune : char -> int -> unit
val rune_of : char -> int
val utf8 : int -> string
val all : unit -> t list

(* [attach dc devno qid]: a new channel on a device's file (devattach) *)
val attach : char -> int -> qid -> chan

(* the kernel's owner (eve: the hostowner, #k/hostowner); when it was
 * made (kerndate: its devices' files' times, the bootdir's header) *)
val eve : string ref
val kerndate : int ref

(* the time now (seconds(): 9pi's clock starts at 0, the boot) *)
val seconds : (unit -> int) ref
(* the clock: the seconds since 1970 at the kernel's start, 0 until
 * /dev/time is written (9pi's time is then seconds()); and the time
 * now for a file written (from the kernel's date until the clock is set) *)
val epoch : int ref
val now : unit -> int

(* an entry of a device's file (devdir: made at kerndate, read now,
 * eve's): [mkdir c name qid length perm] *)
val mkdir : chan -> string -> qid -> int -> int -> dir

(*****************************************************************************)
(* A fixed tree (Dirtab, devgen) *)
(*****************************************************************************)

(* a file: its name, qid, length and rwx bits *)
type dirtab = { dname : string; dqid : qid; dlength : int; dperm : int }

(* [tree name entries parent]: a device's walk, stat, dirs, open from
 * its directories' entries (by the directory's qid path) and each
 * file's parent directory (by its qid path); its root's name ("#c") *)
val tab_walk : (int -> dirtab list) -> (int -> qid) -> chan -> chan -> string -> qid
val tab_stat : string -> (int -> dirtab list) -> (int -> qid) -> chan -> dir
val tab_dirs : (int -> dirtab list) -> chan -> dir list

(* the checks of devopen: a directory opened for reading only *)
val tab_open : chan -> mode -> chan

(*****************************************************************************)
(* The machine-independent entry *)
(*****************************************************************************)

(* convD2M; convM2D (Error ebadstat). The 32-bit fields that are
 * unsigned (times, the qid's path and version, the device) are their low
 * 31 bits: a time since 2004 is past 2^30, a Pi1 int's (u31) *)
val encode : dir -> string
val decode : string -> dir
val u31 : int -> string
val getu31 : string -> int -> int

(* a directory's entries from index [dri], as many whole ones as fit in
 * n bytes (devdirread): the bytes, how many *)
val dirread : dir list -> int -> int -> string * int

(* %q: quoted as rc would read it, when it needs to be *)
val quote : string -> string
