(* Plan 9's devices (Dev, devtab, dev.c). Each device is a record of
 * functions on channels, found by its letter ('#c' is the console). A
 * system call on a file is its device's function on the file's
 * channel. This module also has what most devices share: a fixed tree
 * of files (Dirtab, devgen), and the machine-independent form of a
 * directory entry (convD2M, convM2D), which is what stat, a
 * directory's read and 9P carry.
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
 * A device is a small file server inside the kernel: it has a tree of
 * its own, names its files itself, and answers for each of them. Most
 * devices are a dozen lines over [default] and the fixed tree below.
 * Devpipe is the one to read first, then Devenv (files that come and
 * go), then Devproc (a tree computed from the processes).
 *
 * The functions are 9P's messages, one for one (P9): attach, walk,
 * open, create, read, write, clunk, remove, stat and wstat. That is the
 * design. Devmnt, the device 'M', fills the record with functions that
 * send each one as a message to a program and wait for its answer. So
 * a file served by a program anywhere and a file computed by the
 * kernel are the same thing to Kchan and Sysfile, which only ever call
 * this record.
 *
 * Here is an entry on the wire (for stat, a directory's read, or 9P's
 * Rstat), with the sizes in bytes and the numbers the low byte first:
 *
 *     size[2] type[2] dev[4] qid.type[1] qid.vers[4] qid.path[8]
 *     mode[4] atime[4] mtime[4] length[8]
 *     name[s] uid[s] gid[s] muid[s]           s: a length[2], the bytes
 *
 * That is 41 bytes and four strings, so 49 bytes at least. The owner is
 * a name, not a number, so no table of users must be the same on two
 * machines.
 *
 * plan9-is-cleaner:
 * There is no ioctl. Unix's devices are files for their data and, for
 * all the rest, a call beside the file: ioctl(fd, request, arg), with
 * a number and a structure per device and per request, thousands by
 * now, none of which passes through a pipe, a shell or a network. Here
 * what is not data is another file, where text is written: "rawon" to
 * consctl (Devcons), "part dos 8192 131072" to a disk's ctl (Devsd),
 * "kill" to a process's ctl (Devproc), "connect 10.0.2.2!80" to a
 * connection's ctl (Devip). echo is then the configuration tool for
 * everything, a script can do what a C program was needed for, and a
 * device on another machine is driven the same way.
 *
 * plan9-is-cleaner:
 * There are no device nodes. In Unix the kernel's table of drivers is
 * indexed by a number, and a file of a disk (made by mknod, by root,
 * in /dev) carries two numbers that say which driver and which unit.
 * The name is a convention, the numbers must match the kernel, and a
 * /dev that is stale lies. Here the driver serves its own names, and
 * /dev is only where a process chose to bind them (Kchan).
 *
 * others:
 * Unix's tables, cdevsw and bdevsw (for character and block devices:
 * open, close, read, write, ioctl, and strategy for the blocks), are
 * where this record comes from. xv6 keeps the least of it: devsw has a
 * read and a write, and the console is its one entry. Linux's
 * file_operations has some thirty functions, and each file system, not
 * only each device, fills one: there the generality is in the kernel's
 * interface, here it is in the protocol.
 *
 * References: intro(3) of the Plan 9 manual (the devices), stat(5)
 * (the entry's bytes). principia's Kernel.nw (dev.c, devtab). Rob
 * Pike and others, "Plan 9 from Bell Labs" (1995), for why
 * everything is a file server. *)

open Types
open Errors

(* a device. [dc] is its letter, a byte in mini-9pi's channels; [drune]
 * is its letter as the user names it, a rune (kbin's '#Ι' is U+0399,
 * and its byte is a private one); ... *)
type t = {
  dc : char;
  drune : int;
  name : string;
  (* gives a channel on the device's root; its argument is the spec
   * after "#c" *)
  attach : string -> chan;
  (* [walk c nc name] makes one step from a directory c to nc (c's
   * copy). It returns the name's qid (for "..", the parent's), or
   * raises Error. *)
  walk : chan -> chan -> string -> qid;
  (* [clone c nc] makes nc, c's copy, a file of its own (for devmnt, a
   * new fid). [clunk] drops an unopened channel (devmnt clunks its
   * fid). *)
  clone : chan -> chan -> unit;
  clunk : chan -> unit;
  (* [stat] gives the file's entry; [dirs] a directory's entries *)
  stat : chan -> dir;
  dirs : chan -> dir list;
  (* opens the channel, and returns it or another one (#s's posted
   * channel, #d's descriptor) *)
  open_ : chan -> mode -> chan;
  (* [create c name mode perm]: c, a directory, becomes the new file,
   * opened *)
  create : chan -> string -> mode -> int -> unit;
  (* [read c n off] reads at most n bytes at off (not for a directory,
   * which has dirs). [write c s off] returns how many bytes it wrote. *)
  read : chan -> int -> int -> string;
  write : chan -> string -> int -> int;
  remove : chan -> unit;
  (* changes the entry (its name, its length, its mode...) *)
  wstat : chan -> dir -> unit;
  close : chan -> unit;
}

(* a device (given its letter and its name, such as "cons") whose every
 * function fails (Eperm), except close, clone and clunk, which do
 * nothing. It is the base that the devices
 * override. *)
val default : char -> string -> t

(* [register] adds a device; [find] finds one by its letter (Error when
 * '#x' is unknown) *)
val register : t -> unit
val find : char -> t

(* [find_rune] finds a device by the rune of its letter; [rune_of]
 * gives a letter's rune; [utf8] writes a rune in UTF-8 *)
val find_rune : int -> t

(* makes a registered device's letter a rune *)
val set_rune : char -> int -> unit
val rune_of : char -> int
val utf8 : int -> string
val all : unit -> t list

(* [attach dc devno qid] makes a new channel on a device's file
 * (devattach) *)
val attach : char -> int -> qid -> chan

(* [eve] is the kernel's owner (the hostowner, #k/hostowner).
 * [kerndate] is when the kernel was made; it is the time of its
 * devices' files, and is in the bootdir's header. *)
val eve : string ref
val kerndate : int ref

(* the time now (seconds(): 9pi's clock starts at 0, at the boot) *)
val seconds : (unit -> int) ref
(* [epoch] is the clock: the seconds since 1970 at the kernel's start.
 * It is 0 until /dev/time is written (9pi's time is then seconds()).
 * [now] is the time now, for a file written; it counts from the
 * kernel's date until the clock is set. *)
val epoch : int ref
val now : unit -> int

(* [mkdir c name qid length perm] makes an entry for a device's file
 * (devdir). The file was made at kerndate, is read now, and is eve's. *)
val mkdir : chan -> string -> qid -> int -> int -> dir

(*****************************************************************************)
(* A fixed tree (Dirtab, devgen) *)
(*****************************************************************************)

(* a file, with its name, qid, length and rwx bits *)
type dirtab = { dname : string; dqid : qid; dlength : int; dperm : int }

(* a device's walk, stat, dirs and open, made from its directories'
 * entries (found by the directory's qid path) and from each file's
 * parent directory (found by the file's qid path). tab_stat also takes
 * the name of the device's root ("#c"). *)
val tab_walk : (int -> dirtab list) -> (int -> qid) -> chan -> chan -> string -> qid
val tab_stat : string -> (int -> dirtab list) -> (int -> qid) -> chan -> dir
val tab_dirs : (int -> dirtab list) -> chan -> dir list

(* the checks of devopen: a directory may be opened only for reading *)
val tab_open : chan -> mode -> chan

(*****************************************************************************)
(* The machine-independent entry *)
(*****************************************************************************)

(* [encode] is convD2M; [decode] is convM2D (Error ebadstat). The
 * 32-bit fields that are unsigned (times, the qid's path and version,
 * the device) keep their low 31 bits (u31), because a time since 2004
 * is past 2^30, the limit of a Pi1's int. *)
val encode : dir -> string
val decode : string -> dir
val u31 : int -> string
val getu31 : string -> int -> int

(* [dirread dirs dri n] encodes a directory's entries from index [dri],
 * as many whole ones as fit in n bytes (devdirread). It returns the
 * bytes and how many entries they hold. *)
val dirread : dir list -> int -> int -> string * int

(* %q: quotes a string as rc would read it, when it needs to be *)
val quote : string -> string
