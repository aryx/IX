(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* 9P2000, Plan 9's file protocol (principia's fcall.h), as xix's
 * Protocol_9P designs it and mini-9pi's kernel has it
 * (kernels/9pi/files/P9: the client's half, with the kernel's types): a
 * message is its tag and a request (T) or a response (R), each a
 * variant. For a program: a file server (P9_server), or a client. A
 * file's entry is Sys_plan9's dir, as a program gets it from the
 * kernel. Offsets, counts and fids are ints (arm's 31 bits: no file
 * past 1 GB).
 *
 * Thirteen requests, and they are the whole interface of a Plan 9
 * system to a file: what open, read, write and stat become when the
 * file is not the kernel's own. cat /mnt/wsys/label, the file served
 * by another program over a pipe, the kernel (its Devmnt) speaking
 * for cat:
 *
 *     kernel (the client)                 the file server
 *     Tversion 8216 "9P2000"      --->    once, when the pipe is mounted
 *                                 <---    Rversion 8216 "9P2000"
 *     Tattach fid 0, user, ""     --->    fid 0 is now the tree's root
 *                                 <---    Rattach, the root's qid
 *     Twalk fid 0, new fid 1,
 *           ["label"]             --->    open's part: the name looked up
 *                                 <---    Rwalk, a qid for each name
 *     Topen fid 1, OREAD          --->
 *                                 <---    Ropen
 *     Tread fid 1, offset 0       --->    cat's read
 *                                 <---    Rread, 5 bytes
 *     Tread fid 1, offset 5       --->
 *                                 <---    Rread, no byte: the end
 *     Tclunk fid 1                --->    cat's close
 *                                 <---    Rclunk
 *
 * Three numbers carry it. A *fid* is the client's name for a file it
 * is looking at, chosen by the client (a file descriptor's other
 * end: Twalk makes one, Tclunk forgets it); the server only keeps a
 * table of them. A *qid* is the server's name for the file itself:
 * two fids are the same file if their qids are, and the version in
 * it changes when the file does, which is what a cache needs. A *tag*
 * names a request, so that answers may come back in any order and a
 * request may be given up (Tflush names the tag): a read of a
 * keyboard can wait for an hour while other requests go by.
 *
 * There is no Terror: a server answers any request with Rerror and
 * the words of what went wrong, a string and not a number (errno),
 * so a new server needs no entry in anyone's table of errors.
 *
 * Where it stands: the windows' file server (a window's /dev/cons,
 * /dev/mouse and the rest are files rio serves) and the DOS file
 * system's (Dossrv) are P9_server's functions; on the other side
 * mini-9pi's kernel turns a system call on a mounted file into these
 * messages. The two halves have each their own types and
 * meet in the bytes (P9_wire here, the kernel's own there).
 *
 * plan9-is-cleaner:
 * Unix grew a system call, or a family of them, for each new kind of
 * thing: ioctl for devices, sockets for the network, ptrace for
 * processes, and a protocol apart for remote files (NFS, 1984) that
 * only files could use. Plan 9 has this one protocol, and makes
 * everything a tree of files served by it: the network (/net), the
 * processes (/proc), the screen and the mouse, a window. A program
 * on another machine uses any of them by mounting them, because 9P
 * runs over any stream that keeps bytes in order: a pipe here, TCP
 * between machines.
 *
 * cs-history:
 * 9P is as old as Plan 9 (Bell Labs; shown in 1990, released in
 * 1992). 9P2000, with the fourth edition (2002), is the revision
 * every implementation speaks: longer names, a message's size agreed
 * at the start (Tversion), authentication moved out of the protocol
 * into a file read and written (Tauth's fid).
 *
 * modern:
 * It outlived its system as the simple way to show a host's files to
 * a guest: Linux has had a 9P client since 2005 (v9fs), QEMU serves
 * directories to its virtual machines with it (virtio-9p), and
 * Windows reaches a Linux subsystem's files through a 9P server.
 * Each wanted Unix's semantics on top, hence the dialects 9P2000.u
 * and 9P2000.L; this is the plain one.
 *
 * (No P9.mli: the module is the messages' types; their bytes are
 * P9_wire's.)
 *
 * References: intro(5) of the Plan 9 manual, the protocol as a
 * whole, and the pages after it, one per message; Rob Pike, Dave
 * Presotto, Ken Thompson, Howard Trickey and Phil Winterbottom, "The
 * Use of Name Spaces in Plan 9" (1992), why one protocol; principia's
 * fcall.h. *)

type fid = int
type tag = int
(* a creation's permissions: the nine bits, and the top byte of 9P's 32
 * (DMDIR: a directory) at bits 16 on, where an int of 31 bits has room *)
type perm = int

(* a file's identity for its server: a number, the file's version, and
 * its type (Sys_plan9.dmdir...: the top byte of a mode) *)
type qid = { path : int64; vers : int64; qtype : int }

module Request = struct
  type t =
    | Version of int * string               (* the largest message, "9P2000" *)
    | Auth of fid * string * string
    | Attach of fid * fid option * string * string   (* the root's fid, the authentication's, the user, the tree *)
    | Walk of fid * fid * string list       (* from a fid, to a new one, down these names *)
    | Open of fid * int
    | Create of fid * string * perm * int
    | Read of fid * int * int               (* at an offset, a count *)
    | Write of fid * int * string
    | Clunk of fid
    | Remove of fid
    | Stat of fid
    | Wstat of fid * Sys_plan9.dir
    | Flush of tag
end

module Response = struct
  type t =
    | Version of int * string
    | Auth of qid
    | Attach of qid
    | Error of string
    | Walk of qid list
    | Open of qid * int                     (* and the largest read or write, 0: any *)
    | Create of qid * int
    | Read of string
    | Write of int
    | Clunk
    | Remove
    | Stat of Sys_plan9.dir
    | Wstat
    | Flush
end

type message_type = T of Request.t | R of Response.t
type message = { tag : tag; mtyp : message_type }

(* NOTAG, NOFID; IOHDRSZ (a read's or write's header) *)
let notag = 0xffff
let nofid = -1
let io_header_size = 24

let qid_of (d : Sys_plan9.dir) = { path = d.qid_path; vers = d.qid_vers; qtype = d.qid_type }
