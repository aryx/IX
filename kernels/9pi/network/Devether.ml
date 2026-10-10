(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Devether.mli *)

open Types
open Errors

let enodev = "no free devices"

(* a connection (netif's Netfile): its Ethernet type (-1 all, 0 none
 * yet), how many hold it, its frames not read *)
type conv = { cid : int; mutable ftype : int; mutable held : int; frames : string Queue.t }

let nconv = 16
let convs : conv option array = Array.make nconv None
let addr = ref None
let inpackets = ref 0 and outpackets = ref 0
let receivers = ref []

let mac () = match !addr with Some m -> m | None -> raise (Error enodev)

let register typ f = receivers := (typ, f) :: !receivers

let transmit frame =
  let m = mac () in
  let f = String.sub frame 0 6 ^ m ^ String.sub frame 12 (String.length frame - 12) in
  incr outpackets;
  Etherusb.send f

let deliver f =
  if String.length f >= 14 then begin
    let typ = (Char.code f.[12] lsl 8) lor Char.code f.[13] in
    incr inpackets;
    Array.iter (function
      | Some c when c.ftype = typ || c.ftype = -1 -> Queue.add f c.frames; Proc.wakeup (Ether_data c.cid)
      | _ -> ()) convs;
    List.iter (fun (t, fn) -> if t = typ then fn f) !receivers
  end

let input () = if !addr <> None then List.iter deliver (Etherusb.poll ())

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

(* a qid's path: 0 #l0, 1 ether0, 2 clone, 3 addr, 4 stats, 5 ifstats;
 * a connection n's 16(n+1) + 0 its directory, 1 ctl, 2 data, 3 stats,
 * 4 type, 5 ifstats *)
let qdir p = { path = p; vers = 0; typ = Qt_dir }
let qfile p = { path = p; vers = 0; typ = Qt_file }
let conv_of path = path / 16 - 1
let kind path = path mod 16

let entries path =
  if path = 0 then [ ("ether0", qdir 1, 0o555) ]
  else if path = 1 then
    [ ("clone", qfile 2, 0o666); ("addr", qfile 3, 0o666); ("stats", qfile 4, 0o444); ("ifstats", qfile 5, 0o444) ]
    @ List.concat (Array.to_list (Array.map (function
        | Some c -> [ (string_of_int c.cid, qdir (16 * (c.cid + 1)), 0o555) ]
        | None -> []) convs))
  else if path >= 16 && kind path = 0 then
    let b = path in
    [ ("data", qfile (b + 2), 0o666); ("ctl", qfile (b + 1), 0o666); ("stats", qfile (b + 3), 0o444);
      ("type", qfile (b + 4), 0o444); ("ifstats", qfile (b + 5), 0o444) ]
  else []

let parent path = if path = 0 || path = 1 then qdir 0 else if path < 16 then qdir 1 else if kind path = 0 then qdir 1 else qdir (16 * (conv_of path + 1))

let readstr off n s = if off >= String.length s then "" else String.sub s off (min n (String.length s - off))
let readnum off n v = let s = string_of_int v in readstr off n (String.make (max 0 (11 - String.length s)) ' ' ^ s ^ " ")

let hex m = String.concat "" (List.map (fun i -> Printf.sprintf "%02x" (Char.code m.[i])) [ 0; 1; 2; 3; 4; 5 ])

let stats () =
  Printf.sprintf "in: %d\nlink: 1\nout: %d\ncrc errs: 0\noverflows: 0\nsoft overflows: 0\nframing errs: 0\nbuffer errs: 0\noutput errs: 0\nprom: 0\nmbps: 10\naddr: %s\n"
    !inpackets !outpackets (hex (mac ()))

let conv path = match convs.(conv_of path) with Some c -> c | None -> raise (Error "file does not exist")

let rec readframe c =
  if Queue.length c.frames = 0 then begin Proc.sleep (Ether_data c.cid); readframe c end else Queue.take c.frames

let init () =
  let d = Dev.default 'l' "ether" in
  let stat (c : chan) =
    let p = parent c.qid.path in
    try let (nm, q, perm) = List.find (fun (_, q, _) -> q.path = c.qid.path) (entries p.path) in Dev.mkdir c nm q 0 perm
    with Not_found -> Dev.mkdir c "#l0" c.qid 0 0o555 in
  Dev.register { d with
    Dev.attach = (fun spec ->
      if spec <> "0" && spec <> "" then raise (Error enodev);
      (match !addr with None -> addr := Etherusb.probe () | Some _ -> ());
      if !addr = None then raise (Error enodev);
      Dev.attach 'l' 0 (qdir 0));
    Dev.walk = (fun c _ name ->
      if c.qid.typ <> Qt_dir then raise (Error enotdir);
      if name = ".." then parent c.qid.path
      else try let (_, q, _) = List.find (fun (nm, _, _) -> nm = name) (entries c.qid.path) in q
           with Not_found -> raise (Error enonexist));
    Dev.stat = stat;
    Dev.dirs = (fun c -> List.map (fun (nm, q, perm) -> Dev.mkdir c nm q 0 perm) (entries c.qid.path));
    Dev.open_ = (fun c m ->
      if c.qid.typ = Qt_dir then Dev.tab_open c m
      else begin
        if c.qid.path = 2 then begin
          (* clone: a free connection, its ctl opened *)
          let rec free i = if i = nconv then raise (Error "no free devices") else match convs.(i) with None -> i | Some _ -> free (i + 1) in
          let i = free 0 in
          convs.(i) <- Some { cid = i; ftype = 0; held = 1; frames = Queue.create () };
          c.qid <- qfile ((16 * (i + 1)) + 1)
        end
        else if c.qid.path >= 16 && (kind c.qid.path = 1 || kind c.qid.path = 2) then begin
          let v = conv c.qid.path in v.held <- v.held + 1
        end;
        c
      end);
    Dev.close = (fun c ->
      if c.opened <> None && c.qid.path >= 16 && (kind c.qid.path = 1 || kind c.qid.path = 2) then
        match convs.(conv_of c.qid.path) with
        | Some v -> v.held <- v.held - 1; if v.held <= 0 then convs.(v.cid) <- None
        | None -> ());
    Dev.read = (fun c n off ->
      let p = c.qid.path in
      if p = 3 then readstr off n (hex (mac ()))
      else if p = 4 then readstr off n (stats ())
      else if p = 5 then ""
      else if p >= 16 then begin
        let v = conv p in
        match kind p with
        | 1 -> readnum off n v.cid
        | 2 -> let f = readframe v in String.sub f 0 (min n (String.length f))
        | 3 -> readstr off n (stats ())
        | 4 -> readnum off n v.ftype
        | _ -> ""
      end else "");
    Dev.write = (fun c s _ ->
      let p = c.qid.path in
      if p >= 16 && kind p = 1 then begin
        let v = conv p in
        (match List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.trim s)) with
         | [ "connect"; t ] -> v.ftype <- (try int_of_string t with Failure _ -> raise (Error ebadarg))
         | _ -> ());
        String.length s
      end
      else if p >= 16 && kind p = 2 then begin
        if String.length s < 14 then raise (Error ebadarg);
        transmit s;
        String.length s
      end
      else raise (Error eperm));
  }
