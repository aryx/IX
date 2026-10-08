(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Sysfile.mli *)

open Types
open Errors
open Usermem

let bit16sz = 2

let sysopen (p : proc) name m =
  let mode = Kchan.mode_of_int m in
  let c = Kchan.namec p name in
  let c = Kchan.named name (fun () -> Kchan.open_ c mode) in
  try Kchan.fdalloc p c with e -> Kchan.close c; raise e

let syscreate (p : proc) name m perm =
  let c = Kchan.create p name (Kchan.mode_of_int (m land lnot 0x1000)) perm in
  try Kchan.fdalloc p c with e -> Kchan.close c; raise e

let sysclose (p : proc) fd =
  let c = Kchan.fdtochan p fd None in
  p.fgrp.fds.(fd) <- None;
  Kchan.close c;
  0

let syspread (p : proc) fd buf n off =
  if n < 0 then raise (Error ebadarg);
  let c = Kchan.fdtochan p fd (Some Oread) in
  if c.qid.typ = Qt_dir then begin
    (match off with Some o when o <> c.offset -> raise (Error edirseek) | _ -> ());
    (* a directory is read in several reads, by position. #p's entries
     * are taken once, at the first, and kept until the end: asked again
     * at each read they shifted when a process started in an earlier
     * slot in between, and ps listed a process twice (bugs/ix.md). The
     * others' are asked at each read, as before: a mounted directory's
     * are 9P messages, and how many there are shows (plumber's two
     * processes take turns, tests/session-d).
     * old: let s, k = Dev.dirread (Kchan.dirs c) c.dri n in *)
    if c.dri = 0 || c.dev <> 'p' then c.snap <- Kchan.dirs c;
    let s, k = Dev.dirread c.snap c.dri n in
    if k = 0 then c.snap <- [];
    user_write p buf s;
    c.dri <- c.dri + k;
    c.offset <- c.offset + String.length s;
    String.length s
  end else begin
    let s = (Dev.find c.dev).Dev.read c n (match off with Some o -> o | None -> c.offset) in
    user_write p buf s;
    if off = None then c.offset <- c.offset + String.length s;
    String.length s
  end

let syspwrite (p : proc) fd buf n off =
  if n < 0 then raise (Error ebadarg);
  let s = user_read p buf n in
  let c = Kchan.fdtochan p fd (Some Owrite) in
  if c.qid.typ = Qt_dir then raise (Error eisdir);
  let m = (Dev.find c.dev).Dev.write c s (match off with Some o -> o | None -> c.offset) in
  if off = None then c.offset <- c.offset + m;
  m

let sysseek (p : proc) ret fd lo hi typ =
  let c = Kchan.fdtochan p fd None in
  if c.dev = '|' then raise (Error eisstream);
  let o = if hi = -1 && lo < 0 then lo else match offset lo hi with Some o -> o | None -> -1 in
  let off =
    match typ with
    | 0 -> if c.qid.typ = Qt_dir && o <> 0 then raise (Error eisdir); o
    | 1 -> if c.qid.typ = Qt_dir then raise (Error eisdir); c.offset + o
    | 2 -> if c.qid.typ = Qt_dir then raise (Error eisdir); ((Dev.find c.dev).Dev.stat c).d_length + o
    | _ -> raise (Error ebadarg) in
  if off < 0 then raise (Error enegoff);
  c.offset <- off;
  c.dri <- 0;
  user_write p ret (Machine.le32 off ^ Machine.le32 0);
  0

let sysdup (p : proc) fd nfd =
  let c = Kchan.fdtochan p fd None in
  Kchan.incref c;
  if nfd = -1 then (try Kchan.fdalloc p c with e -> Kchan.close c; raise e)
  else begin Kchan.fdalloc_at p nfd c; nfd end

(* one attach (a new pipe), its two ends walked from it *)
let syspipe (p : proc) addr =
  let d = Kchan.namec p "#|" in
  let dev = Dev.find d.dev in
  let end_ name = let c = Kchan.clone d in c.qid <- dev.Dev.walk d c name; c.cname <- "#|/" ^ name; c in
  let c0 = Kchan.open_ (end_ "data") (Kchan.mode_of_int 2) in
  let c1 = Kchan.open_ (end_ "data1") (Kchan.mode_of_int 2) in
  let fd0 = Kchan.fdalloc p c0 in
  let fd1 = try Kchan.fdalloc p c1 with e -> p.fgrp.fds.(fd0) <- None; Kchan.close c0; Kchan.close c1; raise e in
  user_write p addr (Machine.le32 fd0 ^ Machine.le32 fd1);
  0

let sysfd2path (p : proc) fd buf n = ignore (user_snprint p buf n (Kchan.fdtochan p fd None).cname); 0

(* a stat's entry named by the path's last element (dirsetname), into
 * the user's buffer: all of it, or its size alone when it does not fit *)
let stat_out (p : proc) (c : chan) buf n =
  if n < bit16sz then raise (Error eshortstat);
  let d = (Dev.find c.dev).Dev.stat c in
  let name = if c.cname = "/" then "/" else Kchan.basename c.cname in
  let e = Dev.encode { d with d_name = name } in
  if String.length e > n then begin user_write p buf (String.sub e 0 bit16sz); bit16sz end
  else begin user_write p buf e; String.length e end

let sysstat (p : proc) name buf n =
  let ch = Kchan.namec p name in
  let r = try stat_out p ch buf n with e -> Kchan.clunk ch; raise e in
  Kchan.clunk ch;
  r

let sysfstat (p : proc) fd buf n = stat_out p (Kchan.fdtochan p fd None) buf n

let wstat (p : proc) (c : chan) buf n =
  let d = Dev.decode (user_read p buf n) in
  (Dev.find c.dev).Dev.wstat c d;
  n

let syswstat (p : proc) name buf n = wstat p (Kchan.namec_nomount p name) buf n
let sysfwstat (p : proc) fd buf n = wstat p (Kchan.fdtochan p fd None) buf n

let sysremove (p : proc) name =
  let c = Kchan.namec_nomount p name in
  (Dev.find c.dev).Dev.remove c;
  0

let syschdir (p : proc) name =
  let c = Kchan.namec p name in
  if c.qid.typ <> Qt_dir then raise (Error enotdir);
  p.dot <- c;
  0

(*****************************************************************************)
(* The namespace *)
(*****************************************************************************)

let sysbind (p : proc) newname oldname flag =
  if flag land lnot 7 <> 0 || flag land 3 = 3 then raise (Error ebadarg);
  let newc = Kchan.namec p newname in
  let old = Kchan.namec_nomount p oldname in
  Kchan.bind p.pgrp newc old flag;
  0

(* mount (bindmount): the server on fd attached (devmnt), its root bound
 * at old; MCACHE (0x10) accepted, no cache here *)
let sysmount (p : proc) fd oldname flag aname =
  if flag land lnot 0x17 <> 0 || flag land 3 = 3 then raise (Error ebadarg);
  let c = Kchan.fdtochan p fd (Some Ordwr) in
  let root = Devmnt.attach c aname in
  let old = Kchan.namec_nomount p oldname in
  root.cname <- old.cname;
  Kchan.bind p.pgrp root old (flag land 7);
  root.devno

let sysunmount (p : proc) newaddr oldname =
  let old = Kchan.namec_nomount p oldname in
  let newc = if newaddr = 0 then None else Some (Kchan.namec p (user_string p newaddr maxpath)) in
  Kchan.unmount p.pgrp newc old;
  0
