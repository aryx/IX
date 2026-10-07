(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See ../../commons/Sys_plan9.mli: Plan 9's. Each function a system
 * call by its number (libc's sys.h), through Unix's (Unix.plan9_call:
 * the error it raises has the kernel's words). *)

let i (n : int) = Obj.repr n
let s (x : string) = Obj.repr x
let z = Obj.repr 0

let last_words = Unix.last_words
let last_times = Unix.last_times

(* (what is in the channels' buffers first: exit's own way) *)
let exits words =
  if words = "" then exit 0
  else begin
    do_at_exit ();
    ignore (Unix.plan9_call "exits" "" 3 [| s words; z; z; z; z; z |]);
    exit 1
  end

let rfnameg = 1 and rfenvg = 2 and rffdg = 4 and rfnoteg = 8 and rfproc = 16 and rfnowait = 64
let rfork (_ : < Cap.fork; .. >) flags = Unix.plan9_call "rfork" "" 1 [| i flags; z; z; z; z; z |]

let mrepl = 0 and mbefore = 1 and mafter = 2 and mcreate = 4 and mcache = 16
let bind (_ : < Cap.bind; .. >) name old flag = ignore (Unix.plan9_call "bind" name 20 [| s name; s old; i flag; z; z; z |])
(* (the second argument: the authentication's descriptor, none) *)
let mount (_ : < Cap.mount; .. >) (fd : Unix.file_descr) old flag spec =
  ignore (Unix.plan9_call "mount" old 21 [| Obj.repr fd; i (-1); s old; i flag; s spec; z |])
(* (no name: a nil pointer) *)
let unmount (_ : < Cap.mount; .. >) name old =
  ignore (Unix.plan9_call "unmount" old 22 [| (match name with Some n -> s n | None -> z); s old; z; z; z; z |])

type dir = {
  name : string; uid : string; gid : string; muid : string;
  dev_type : char; dev : int;
  qid_path : int64; qid_vers : int64; qid_type : int;
  mode_type : int; perm : int;
  atime : float; mtime : float; length : int;
}
let dmdir = 0x80 and dmappend = 0x40 and dmexcl = 0x20 and dmauth = 0x08 and dmtmp = 0x04

(* An entry at o in b, and where the next one is: its size (2 bytes,
 * not counting them), the device's type (2) and number (4), the qid
 * (its type 1, version 4, path 8), the mode (4), the two times (4
 * each), the length (8), then four strings, each its length (2) and
 * its bytes. A number of 32 bits by its halves: arm's int has 31. *)
let entry b o =
  let u16 k = Bytes.get_uint16_le b (o + k) in
  let u32 k = u16 k + (u16 (k + 2) lsl 16) in
  let seconds k = float_of_int (u16 k) +. (float_of_int (u16 (k + 2)) *. 65536.0) in
  let str k = let n = u16 k in Bytes.sub_string b (o + k + 2) n, k + 2 + n in
  let name, k = str 41 in
  let uid, k = str k in
  let gid, k = str k in
  let muid, _ = str k in
  { name; uid; gid; muid; dev_type = Char.chr (u16 2 land 0xff); dev = u32 4;
    qid_type = Char.code (Bytes.get b (o + 8)); qid_vers = Int64.logand (Int64.of_int32 (Bytes.get_int32_le b (o + 9))) 0xffffffffL; qid_path = Bytes.get_int64_le b (o + 13);
    mode_type = Char.code (Bytes.get b (o + 24)); perm = u16 21 land 0o777;
    atime = seconds 25; mtime = seconds 29; length = Int64.to_int (Bytes.get_int64_le b (o + 33)) },
  o + 2 + u16 0

let dirstat (_ : < Cap.readdir; .. >) path =
  let b = Bytes.create 1024 in
  ignore (Unix.plan9_call "stat" path 16 [| s path; Obj.repr b; i 1024; z; z; z |]);
  fst (entry b 0)

(* a read of a directory gives whole entries, one after the other *)
let dirread (_ : < Cap.readdir; .. >) path =
  let fd = Unix.openfile path [ Unix.O_RDONLY ] 0 and b = Bytes.create 8192 in
  let rec entries o n acc = if o >= n then acc else let d, next = entry b o in entries next n (d :: acc) in
  let rec all acc = match Unix.read fd b 0 8192 with 0 -> List.rev acc | n -> all (entries 0 n acc) in
  match all [] with
  | ds -> Unix.close fd; ds
  | exception e -> Unix.close fd; raise e

(* wstat's entry: every field all ones (unchanged), the strings empty,
 * but the mode (its 4 bytes), the time written (seconds, by its
 * halves) or the name, when given *)
let wstat path mode mtime name =
  let ones n = String.make n '\xff' in
  let b16 v = String.init 2 (fun k -> Char.chr ((v lsr (8 * k)) land 0xff)) in
  let str x = b16 (String.length x) ^ x in
  let seconds t = let hi = Float.to_int (t /. 65536.0) in b16 (Float.to_int (t -. (float_of_int hi *. 65536.0))) ^ b16 hi in
  let body =
    ones 19
    ^ (match mode with Some (mode_type, perm) -> b16 perm ^ "\000" ^ String.make 1 (Char.chr mode_type) | None -> ones 4)
    ^ ones 4 ^ (match mtime with Some t -> seconds t | None -> ones 4)
    ^ ones 8 ^ str name ^ str "" ^ str "" ^ str "" in
  let b = b16 (String.length body) ^ body in
  ignore (Unix.plan9_call "wstat" path 18 [| s path; s b; i (String.length b); z; z; z |])

let rename (_ : < Cap.open_out; .. >) path name = wstat path None None name
let chmod (_ : < Cap.open_out; .. >) path mode_type perm = wstat path (Some (mode_type, perm)) None ""
let set_mtime (_ : < Cap.open_out; .. >) path secs = wstat path None (Some secs) ""
