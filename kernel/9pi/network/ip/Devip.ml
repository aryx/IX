(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Devip.mli *)

open Types

(*****************************************************************************)
(* ipifc: the interface as a protocol *)
(*****************************************************************************)

let ipifcstate _ =
  let i = Ip.ifc in
  Printf.sprintf "device %s maxtu %d sendra 0 recvra 0 mflag 0 oflag 0 maxraint 600000 minraint 200000 linkmtu 0 reachtime 0 rxmitra 0 ttl 255 routerlt 0 pktin %d pktout %d errin 0 errout 0\n"
    i.Ip.dev i.Ip.mtu i.Ip.pktin i.Ip.pktout
  ^ (if i.Ip.lifcs = [] then "\n" else
     String.concat "" (List.map (fun l ->
       let pad n s = s ^ String.make (max 0 (n - String.length s)) ' ' in
       let net = String.concat "" (List.map (fun k -> String.make 1 (Char.chr (Char.code l.Ip.local.[k] land Char.code l.Ip.mask.[k]))) [ 0; 1; 2; 3 ]) in
       Printf.sprintf "  %s %s %s %s %s\n" (pad 40 (Ip.show l.Ip.local)) (pad 10 (Ip.show l.Ip.mask)) (pad 40 (Ip.show net))
         (pad 12 "4294967295") (pad 12 "4294967295")) i.Ip.lifcs))

let ipifcctl _ words =
  match words with
  | "bind" :: _ :: dev :: _ -> Ip.bind dev; true
  | "add" :: ip :: mask :: _ -> Ip.add (Ip.parse ip) (Ip.parsemask mask); true
  | "remove" :: ip :: mask :: _ -> Ip.remove (Ip.parse ip) (Ip.parsemask mask); true
  | "unbind" :: _ -> Ip.unbind (); true
  | _ -> true

let ipifc = { Ip.pname = "ipifc"; Ip.convs = Array.make 4 None; Ip.connect = (fun _ _ -> raise (Error "not a connection"));
              Ip.announce = (fun _ _ -> raise (Error "not a connection")); Ip.write = (fun _ _ -> raise (Error eperm));
              Ip.state = ipifcstate; Ip.close = (fun _ -> ()); Ip.listen = (fun _ -> raise (Error eperm)); Ip.ctl = ipifcctl }

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

let protos () = ipifc :: !Ip.protos
let ndb = ref ""

(* a qid's path: 0 #I, 1 arp, 2 iproute, 3 ipselftab, 4 log, 5 ndb; a
 * protocol p's 0x1000(p+1): +0 its directory, +1 clone, +2 stats; its
 * connection c's +0x10(c+1): +0 directory, +1 ctl, +2 data, +3 err,
 * +4 listen, +5 local, +6 remote, +7 status *)
let qdir p = { path = p; vers = 0; typ = Qt_dir }
let qfile p = { path = p; vers = 0; typ = Qt_file }
let top = [ ("arp", 1, 0o666); ("iproute", 2, 0o666); ("ipselftab", 3, 0o444); ("log", 4, 0o666); ("ndb", 5, 0o666) ]
let convfiles = [ ("ctl", 1, 0o666); ("data", 2, 0o666); ("err", 3, 0o666); ("listen", 4, 0o666); ("local", 5, 0o444);
                  ("remote", 6, 0o444); ("status", 7, 0o444) ]

let pidx path = path / 0x1000 - 1
let cidx path = (path land 0xfff) / 0x10 - 1
let kind path = path land 0xf
let proto path = List.nth (protos ()) (pidx path)
let conv path = match (proto path).Ip.convs.(cidx path) with Some c -> c | None -> raise (Error enonexist)

let entries path =
  if path = 0 then
    List.map (fun (n, k, perm) -> (n, qfile k, perm)) top
    @ List.mapi (fun i p -> (p.Ip.pname, qdir (0x1000 * (i + 1)), 0o555)) (protos ())
  else if path >= 0x1000 && path land 0xfff = 0 then
    let b = path in
    [ ("clone", qfile (b + 1), 0o666); ("stats", qfile (b + 2), 0o444) ]
    @ List.concat (Array.to_list (Array.map (function
        | Some c -> [ (string_of_int c.Ip.cid, qdir (b + (0x10 * (c.Ip.cid + 1))), 0o555) ]
        | None -> []) (proto path).Ip.convs))
  else if path >= 0x1000 && kind path = 0 then
    List.map (fun (n, k, perm) -> (n, qfile (path + k), perm)) convfiles
  else []

let parent path =
  if path < 0x1000 then qdir 0
  else if path land 0xfff = 0 then qdir 0
  else if kind path = 0 || path land 0xff0 = 0 then qdir (path land (lnot 0xfff))
  else qdir (path land (lnot 0xf))

let readstr off n s = if off >= String.length s then "" else String.sub s off (min n (String.length s - off))

let hold c = c.Ip.held <- c.Ip.held + 1
(* the last close frees a connection; an interface stays (ipifc's: till
 * unbound) *)
let release p c =
  c.Ip.held <- c.Ip.held - 1;
  if c.Ip.held <= 0 && p != ipifc then begin p.Ip.close c; p.Ip.convs.(c.Ip.cid) <- None end

(* a data read: the next message (a stream's first n bytes, the rest kept) *)
let rec readdata c n =
  if Queue.length c.Ip.rq = 0 then begin
    if c.Ip.eof then "" else begin Proc.sleep (Ip_conv c.Ip.key); readdata c n end
  end else begin
    let m = Queue.take c.Ip.rq in
    if String.length m <= n then m
    else begin
      let rest = Queue.create () in
      Queue.add (String.sub m n (String.length m - n)) rest;
      Queue.iter (fun x -> Queue.add x rest) c.Ip.rq;
      Queue.clear c.Ip.rq;
      Queue.iter (fun x -> Queue.add x c.Ip.rq) rest;
      String.sub m 0 n
    end
  end

let words s = List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\n' || c = '\t' then ' ' else c) s))

let rxmit = ref false

let init () =
  let d = Dev.default 'I' "ip" in
  Dev.register { d with
    Dev.attach = (fun _ ->
      (* rxmitproc's pid spent, as 9pi's first attach starts it *)
      if not !rxmit then begin rxmit := true; Proc.kproc "rxmitproc" end;
      Dev.attach 'I' 0 (qdir 0));
    Dev.walk = (fun c _ name ->
      if c.qid.typ <> Qt_dir then raise (Error enotdir);
      if name = ".." then parent c.qid.path
      else try let (_, q, _) = List.find (fun (n, _, _) -> n = name) (entries c.qid.path) in q
           with Not_found -> raise (Error enonexist));
    Dev.stat = (fun c ->
      let p = parent c.qid.path in
      try let (n, q, perm) = List.find (fun (_, q, _) -> q.path = c.qid.path) (entries p.path) in Dev.mkdir c n q 0 perm
      with Not_found -> Dev.mkdir c "#I0" c.qid 0 0o555);
    Dev.dirs = (fun c -> List.map (fun (n, q, perm) -> Dev.mkdir c n q 0 perm) (entries c.qid.path));
    Dev.open_ = (fun c m ->
      if c.qid.typ = Qt_dir then Dev.tab_open c m
      else begin
        let path = c.qid.path in
        if path >= 0x1000 && path land 0xfff = 1 then begin
          (* clone: a new connection, its ctl *)
          let p = proto path in
          let cv = Ip.newconv p in
          hold cv;
          c.qid <- qfile ((path land (lnot 0xfff)) + (0x10 * (cv.Ip.cid + 1)) + 1)
        end
        else if path >= 0x1000 && kind path = 4 then begin
          (* listen: a connection called in, its ctl *)
          let p = proto path in
          let nc = p.Ip.listen (conv path) in
          hold nc;
          c.qid <- qfile ((path land (lnot 0xfff)) + (0x10 * (nc.Ip.cid + 1)) + 1)
        end
        else if path >= 0x1000 && (kind path = 1 || kind path = 2 || kind path = 3) then hold (conv path);
        c
      end);
    Dev.close = (fun c ->
      let path = c.qid.path in
      if c.opened <> None && path >= 0x1000 && path land 0xff0 <> 0 && (kind path = 1 || kind path = 2 || kind path = 3) then
        match (proto path).Ip.convs.(cidx path) with Some cv -> release (proto path) cv | None -> ());
    Dev.read = (fun c n off ->
      let path = c.qid.path in
      if path = 1 then readstr off n (Ip.arptext ())
      else if path = 2 then readstr off n (Ip.routetext ())
      else if path = 3 then readstr off n (String.concat "" (List.map (fun l -> Printf.sprintf "%-44s 01 6u\n" (Ip.show l.Ip.local)) Ip.ifc.Ip.lifcs))
      else if path = 5 then readstr off n !ndb
      else if path < 0x1000 then ""
      else if path land 0xfff = 2 then ""
      else begin
        let cv = conv path in
        match kind path with
        | 1 -> readstr off n (string_of_int cv.Ip.cid)
        | 2 -> readdata cv n
        | 5 -> readstr off n (Ip.show cv.Ip.laddr ^ "!" ^ string_of_int cv.Ip.lport ^ "\n")
        | 6 -> readstr off n (Ip.show cv.Ip.raddr ^ "!" ^ string_of_int cv.Ip.rport ^ "\n")
        | 7 -> readstr off n ((proto path).Ip.state cv)
        | _ -> ""
      end);
    Dev.write = (fun c s off ->
      let path = c.qid.path in
      let n = String.length s in
      if path = 5 then begin ndb := (if off = 0 then s else !ndb ^ s); n end
      else if path = 2 then begin
        (match words s with
         | [ "add"; d; m; g ] -> Ip.routes := !Ip.routes @ [ (Ip.parse d, Ip.parse m, Ip.parse g) ]
         | [ "remove"; d; m ] -> Ip.routes := List.filter (fun (d', m', _) -> not (d' = Ip.parse d && m' = Ip.parse m)) !Ip.routes
         | "flush" :: _ -> Ip.routes := []
         | _ -> ());
        n
      end
      else if path < 0x1000 then n
      else begin
        let p = proto path and cv = conv path in
        match kind path with
        | 1 ->
            (match words s with
             | "connect" :: a :: _ -> p.Ip.connect cv a
             | "announce" :: a :: _ -> p.Ip.announce cv a
             | "headers" :: _ -> cv.Ip.headers <- true
             | ("ttl" | "tos" | "ignoreadvice" | "maxfragsize") :: _ -> ()
             | ws -> if not (p.Ip.ctl cv ws) then raise (Error "unknown control request"));
            n
        | 2 -> p.Ip.write cv s; n
        | _ -> raise (Error eperm)
      end);
  }
