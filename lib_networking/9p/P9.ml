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
 * (No P9.mli: the module is the messages' types; their bytes are
 * P9_wire's.) *)

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
