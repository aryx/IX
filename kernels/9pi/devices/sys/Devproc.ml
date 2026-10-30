(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Devproc.mli *)

open Types
open Errors

(* procdir, in its order *)
let files = [ "args", 0o660; "ctl", 0o000; "fd", 0o444; "fpregs", 0o000; "kregs", 0o400; "mem", 0o000;
              "note", 0o000; "noteid", 0o664; "notepg", 0o000; "ns", 0o444; "proc", 0o400; "regs", 0o000;
              "segment", 0o444; "status", 0o444; "text", 0o400; "wait", 0o400; "profile", 0o400; "syscall", 0o400 ]

(* the image's bytes (Fault.read_image, after this in the link: Main
 * sets it) *)
let read_image = ref (fun (_ : chan) (_ : int) (_ : int) -> "")

(* text: the program's file, as its text segment was made from it (the
 * image's channel): a program's own runtime reads its symbol table
 * there to name a raise's frames (languages/ml/runtime/frames.c) *)
let text p off n =
  match List.find_opt (fun s -> s.kind = Text) p.segs with
  | Some s ->
      (match s.image with Some c -> !read_image c off n | None -> raise (Error eperm))
  | None -> raise (Error eperm)

(* another process's memory, for its debugger (Usermem's debug_read and
 * debug_write, after this in the link: Main sets them) *)
let mem_read = ref (fun (_ : proc) (_ : int) (_ : int) -> "")
let mem_write = ref (fun (_ : proc) (_ : int) (_ : string) -> ())

(* a debugger's control (principia's procctlreq): stop and wait for the
 * stop (Syscall.procctl, on the process's way back to user mode),
 * start, both at once, the process traced (its next note stops it),
 * wait, hang (stopped at its next exec) *)
let stopped p = p.psstate = "Stopped"

let waitstop p =
  while not (stopped p) do
    if p.state = Zombie || Proc.find p.pid = None then raise (Error "process exited");
    Proc.sleep (Stop_wait p.pid)
  done

let start p =
  if not (stopped p) then raise (Error "not stopped");
  p.psstate <- "";
  Proc.wakeup (Stopped p.pid)

let ctl p msg =
  match msg with
  | "kill" -> ignore (Proc.postnote p "sys: killed" Nexit)
  | "stop" -> if not (stopped p) then begin p.procctl <- Pc_stop; waitstop p end
  | "start" -> start p
  | "startstop" -> p.procctl <- Pc_trace; start p; waitstop p
  | "waitstop" -> waitstop p
  | "hang" -> p.hang <- true
  | _ -> raise (Error ebadctl)

(* its registers as Plan 9 arm's Ureg (Ureg.plan9), its trap frame's; a
 * write changes those of r0-r14 and the pc it covers *)
let regs p = Ureg.plan9 (Machine.tf_slot_bytes p.slot) p.traptype

let set_regs p off s =
  let u = regs p in
  if off < 0 || off + String.length s > String.length u then raise (Error ebadarg);
  let u = String.sub u 0 off ^ s ^ String.sub u (off + String.length s) (String.length u - off - String.length s) in
  Machine.tf_slot_set_bytes p.slot (Ureg.into_frame (Machine.tf_slot_bytes p.slot) u)

(* its first note, taken (a debugger's: why it stopped) *)
let note p =
  match p.notes with
  | (msg, _) :: rest -> p.notes <- rest; msg
  | [] -> ""

let knamelen = 28
let numsize = 12
let statsize = (2 * knamelen) + 12 + (9 * 12)

(* the qids: a process's directory pid*32, its files pid*32 + i + 1 *)
let root = { path = 0; vers = 0; typ = Qt_dir }

let procs () = List.fold_right (fun o acc -> match o with Some p when p.state <> Zombie -> p :: acc | _ -> acc)
                 (Array.to_list Proc.procs) []

let find pid = try List.find (fun p -> p.pid = pid) (procs ()) with Not_found -> raise (Error "process exited")

let entries path =
  if path = 0 then
    List.map (fun p -> { Dev.dname = string_of_int p.pid; Dev.dqid = { path = p.pid * 32; vers = p.pid; typ = Qt_dir };
                         Dev.dlength = 0; Dev.dperm = 0o555 }) (procs ())
  else if path land 31 = 0 then begin
    let pid = path / 32 in
    ignore (find pid);
    let rec go i l = match l with
      | [] -> []
      | (name, perm) :: r ->
          { Dev.dname = name; Dev.dqid = { path = (pid * 32) + i + 1; vers = pid; typ = Qt_file };
            Dev.dlength = (if name = "status" then statsize else 0); Dev.dperm = perm } :: go (i + 1) r in
    go 0 files
  end
  else raise (Error enotdir)

let parent path = if path land 31 = 0 then root else { path = path land lnot 31; vers = path / 32; typ = Qt_dir }

let name_of path = fst (List.nth files ((path land 31) - 1))

let readstr off n s = if off >= String.length s then "" else String.sub s off (min n (String.length s - off))
let field w s = let s = if String.length s > w then String.sub s 0 w else s in s ^ String.make (w - String.length s) ' '
let num v = let s = string_of_int v in String.make (max 0 (numsize - 1 - String.length s)) ' ' ^ s ^ " "

let status p =
  let st = if p.psstate <> "" then p.psstate
    else match p.state with Running -> "Running" | Runnable -> "Ready" | Sleeping _ -> "Wakeme" | Zombie -> "Moribund" in
  (* the segments but the stack ("mostly non-existent") *)
  let mem = List.fold_left (fun n s -> if s.kind = Stack then n else n + (s.top - s.base)) 0 p.segs in
  field knamelen p.text ^ field knamelen !Dev.eve ^ field 12 st
  ^ num 0 ^ num 0 ^ num ((!Proc.ticks - p.start) * 10) ^ num 0 ^ num 0 ^ num (mem / 1024) ^ num 10 ^ num 10
  ^ String.make (statsize - (2 * knamelen) - 12 - (8 * numsize)) ' '

(* %.Nx: hex, zero-padded to w digits *)
let hex w v = let s = Printf.sprintf "%x" v in String.make (max 0 (w - String.length s)) '0' ^ s

(* procargs: the arguments quoted, space-separated; a name the process
 * gave itself: "text [name]" *)
let procargs p =
  if p.setargs then p.text ^ " [" ^ p.args ^ "]"
  else String.concat " " (List.map Dev.quote (List.filter (fun a -> a <> "") (String.split_on_char '\000' p.args)))

(* (a last column Plan 9 has not: the segment's pages in memory, those
 * touched; what mini-free adds up. old: the line ended at the 1) *)
let segment p =
  (* (the stack first, as Plan 9's: libmach's stacktop reads its line) *)
  let segs = List.filter (fun s -> s.kind = Stack) p.segs @ List.filter (fun s -> s.kind <> Stack) p.segs in
  String.concat "" (List.map (fun s ->
    let name = match s.kind with Text -> "Text" | Data -> "Data" | Bss -> "Bss" | Stack -> "Stack"
                                  | Attached _ -> "Memory" in
    Printf.sprintf "%-6s %c %s %s %4d %6d\n" name (if s.kind = Text then 'R' else ' ') (hex 8 s.base) (hex 8 s.top) 1 (Hashtbl.length s.pages)) segs)

let fds p =
  let b = Buffer.create 256 in
  Buffer.add_string b (p.dot.cname ^ "\n");
  Array.iteri (fun i o -> match o with
    | Some c ->
        let m = match c.opened with Some { access = Oread } -> 'r' | Some { access = Owrite } -> 'w' | _ -> 'R' in
        Buffer.add_string b (Printf.sprintf "%3d %c %c %4d (%s %5d %s) %5d %8d %s\n" i m c.dev c.devno
                               (hex 16 c.qid.path) c.qid.vers (hex 2 (if c.qid.typ = Qt_dir then 0x80 else 0)) 8192
                               c.offset c.cname)
    | None -> ()) p.fgrp.fds;
  Buffer.contents b

let ns p =
  String.concat "" (List.concat (List.map (fun h ->
    List.map (fun m -> Printf.sprintf "bind %s%s %s\n" (if m.mcreate then "-c " else "") m.mchan.cname h.mpt.cname) h.members)
    p.pgrp.mnt)) ^ "cd " ^ p.dot.cname ^ "\n"

let init () =
  let d = Dev.default 'p' "proc" in
  Dev.register { d with
    Dev.attach = (fun _ -> Dev.attach 'p' 0 root);
    Dev.walk = (fun c nc name ->
      if c.qid.path = 0 && name <> ".." then begin
        (* a pid, even one not listed yet *)
        let pid = try int_of_string name with Failure _ -> raise (Error enonexist) in
        ignore (find pid);
        { path = pid * 32; vers = pid; typ = Qt_dir }
      end
      else Dev.tab_walk entries parent c nc name);
    Dev.stat = Dev.tab_stat "#p" entries parent;
    Dev.dirs = Dev.tab_dirs entries;
    Dev.open_ = Dev.tab_open;
    Dev.read = (fun c n off ->
      let p = find (c.qid.path / 32) in
      match name_of c.qid.path with
      | "status" -> readstr off n (status p)
      | "args" -> readstr off n (procargs p)
      | "fd" -> readstr off n (fds p)
      | "ns" -> readstr off n (ns p)
      | "noteid" -> readstr off n (num p.noteid)
      | "segment" -> readstr off n (segment p)
      | "text" -> text p off n
      | "mem" -> !mem_read p off n
      | "regs" -> readstr off n (regs p)
      | "note" -> readstr 0 n (note p)
      | _ -> raise (Error eperm));
    Dev.write = (fun c s off ->
      let p = find (c.qid.path / 32) in
      (match name_of c.qid.path with
       | "ctl" -> ctl p (String.trim s)
       | "mem" -> !mem_write p off s
       | "regs" -> set_regs p off s
       | "note" -> ignore (Proc.postnote p s Nuser)
       | "args" ->
           if s = "" then raise (Error "i/o count too small");
           if String.length s >= 128 then raise (Error "read or write too large");
           p.args <- (try String.sub s 0 (String.index s '\000') with Not_found -> s);
           p.setargs <- true
       | "notepg" ->
           List.iter (fun q -> if q.noteid = p.noteid then ignore (Proc.postnote q s Nuser)) (procs ())
       | _ -> raise (Error eperm));
      String.length s);
  }
