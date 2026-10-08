(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Errors.mli *)

exception Error of string

let enonexist = "file does not exist"
let ebadsharp = "unknown device in # filename"
let enotdir = "not a directory"
let eisdir = "file is a directory"
let eperm = "permission denied"
let ebadusefd = "inappropriate use of fd"
let ebadarg = "bad arg in system call"
let ebadfd = "fd out of range or not open"
let enofd = "no free file descriptors"
let ebadexec = "exec header invalid"
let enovmem = "virtual memory allocation failed"
let esoverlap = "segments overlap"
let enegoff = "negative i/o offset"
let egreg = "jmk added reentrancy for threads"
let eexist = "file already exists"
let enocreate = "mounted directory forbids creation"
let eunmount = "not mounted"
let eismtpt = "is a mount point"
let enochild = "no living children"
let ehungup = "i/o on hungup channel"
let edirseek = "seek in directory"
let eisstream = "seek on a stream"
let eshortstat = "stat buffer too small"
let ebadstat = "malformed stat buffer"
let einuse = "device or object already in use"
let ebadctl = "bad process or channel control request"

(* %#q: quoted as rc quotes, a quote doubled (short names only: the
 * C's elision of a long one's prefix is not here yet) *)
let nameerror name err =
  let b = Buffer.create 64 in
  Buffer.add_char b '\'';
  for i = 0 to String.length name - 1 do
    if name.[i] = '\'' then Buffer.add_char b '\'';
    Buffer.add_char b name.[i]
  done;
  Buffer.add_string b "' ";
  Buffer.add_string b err;
  raise (Error (Buffer.contents b))

(*****************************************************************************)
(* Files: qids, directory entries, open modes, channels *)
(*****************************************************************************)
