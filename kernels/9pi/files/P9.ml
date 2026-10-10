(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* 9P2000, the file protocol (principia's fcall.h, convS2M/convM2S), as
 * xix's Protocol_9P designs it: a message is its tag and a request (T)
 * or a response (R), each a variant. Here the client's half: requests
 * encoded, responses decoded (devmnt). Offsets, counts, fids and qid
 * paths are ints (the Pi1's 31 bits: no file past 1GB).
 *
 * Thirteen requests, each with its response, or Rerror and a string.
 * A fid is a number the client chooses to name a file of the
 * server's from then on; a tag, a number it chooses to name a
 * request, so that answers may come in any order. What the kernel
 * sends for a program that reads a file of a mounted FAT (the fids'
 * and tags' numbers are an example's):
 *
 *     mount /srv/dos /mnt/fat          once, for the connection:
 *       T Version 8216 "9P2000"          R Version 8216 "9P2000"
 *       T Attach fid 1, no afid, "pad"   R Attach qid     1: the root
 *
 *     fd = open("/mnt/fat/config.txt", OREAD)
 *       T Walk 1 -> 2, no names          R Walk           2: the root too
 *       T Walk 1 -> 3, "config.txt"      R Walk [qid]     3: the file
 *       T Clunk 2                        R Clunk
 *       T Open 3, OREAD                  R Open qid
 *     read(fd, buf, 100)
 *       T Read 3, offset 0, count 100    R Read (the bytes)
 *     close(fd)
 *       T Clunk 3                        R Clunk
 *
 * The walk from 1 to 2 is Kchan's clone of the mounted channel, the
 * walk's own copy of the directory it is in: a fid is never moved,
 * a new one is walked from it, and the one no longer needed is
 * clunked. The server keeps, for each fid, where it is and whether
 * it is open; the offset is the client's, sent with each read.
 *
 * Who speaks it in ix: Devmnt is the kernel's client; the servers
 * are programs, on lib_networking's P9_server (mini-dossrv for a
 * FAT, mini-rio for its windows' files).
 *
 * cs-history:
 * 9P is Plan 9's one protocol: what the kernel says to a file
 * server on a disk, to a window system, to another machine. The
 * first editions' 9P had fixed-size messages and names of 28 bytes;
 * 9P2000, the fourth edition's (2002), is the one here: strings with
 * a length, a walk of several names in one message, a size the two
 * sides agree on first (Version), authentication as a file (Auth)
 * rather than fields of the attach.
 *
 * others:
 * NFS (Sun, 1984), Unix's remote files, has no open and no close: a
 * server remembers nothing of its clients, each request carries a
 * file handle and an offset, and a server that restarts is not
 * noticed. The price is everything that needs the server to know
 * who has what: a file removed while open, a lock, a device whose
 * read depends on who reads. 9P keeps state, a fid from walk to
 * clunk, because its files are mostly not files of a disk.
 *
 * modern:
 * 9P outlived its system as the simplest way to show one system's
 * files to another: Linux mounts it (v9fs, since 2005), QEMU serves
 * a host's directory to its guest with it over virtio, and Windows
 * reaches its Linux subsystem's files with it (from memory).
 *
 * References: intro(5) of the Plan 9 manual, then one page a
 * message: the whole protocol in a dozen pages. Rob Pike and others,
 * "Plan 9 from Bell Labs" (1995). Russel Sandberg and others,
 * "Design and Implementation of the Sun Network Filesystem" (USENIX
 * Summer 1985), for the other way. *)

(* (No P9.mli: the module is the messages' types; their bytes are
 * P9_wire's.) *)

open Types
open Errors

type fid = int
type tag = int
type perm = int

module Request = struct
  type t =
    | Version of int * string
    | Auth of fid * string * string
    | Attach of fid * fid option * string * string
    | Walk of fid * fid * string list
    | Open of fid * int
    | Create of fid * string * perm * int
    | Read of fid * int * int
    | Write of fid * int * string
    | Clunk of fid
    | Remove of fid
    | Stat of fid
    | Wstat of fid * dir
    | Flush of tag
end

module Response = struct
  type t =
    | Version of int * string
    | Auth of qid
    | Attach of qid
    | Error of string
    | Walk of qid list
    | Open of qid * int
    | Create of qid * int
    | Read of string
    | Write of int
    | Clunk
    | Remove
    | Stat of dir
    | Wstat
    | Flush
end

type message_type = T of Request.t | R of Response.t

(* xix's {tag; typ}: mtyp, as a qid has a typ (ocaml-light's records
 * are not told apart by their type) *)
type message = { tag : tag; mtyp : message_type }

(* NOTAG, NOFID; IOHDRSZ (a read's or write's header) *)
let notag = 0xffff
(* ~0: -1, as a 32-bit word (Machine.le32 writes its low 32 bits) *)
let nofid = -1
let io_header_size = 24
