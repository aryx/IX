(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Fileserver.mli *)

(* a window's files: a file more is a line here *)
let devices : Device.t list =
  [ Virtual_cons.cons; Virtual_cons.consctl; Virtual_cons.kbd; Virtual_mouse.mouse; Virtual_mouse.cursor;
    Dev_wm.winname; Dev_wm.winid; Dev_wm.label; Dev_wm.text; Dev_wm.snarf ]

(* a window's directory (no device), or one of its files *)
type file = { win : Window.t; dev : Device.t option }

let entry (f : file) : Sys_plan9.dir =
  let rec number k (d : Device.t) = function x :: more -> if x == d then k else number (k + 1) d more | [] -> 0 in
  let name, code, perm, t = match f.dev with
    | None -> "/", 0, 0o555, Sys_plan9.dmdir
    | Some d -> d.name, number 1 d devices, d.perm, 0 in
  { name; uid = "ix"; gid = "ix"; muid = "ix"; dev_type = '\000'; dev = 0;
    qid_path = Int64.of_int ((f.win.id * 64) + code); qid_vers = 0L; qid_type = t; mode_type = t; perm;
    atime = 0.0; mtime = 0.0; length = 0 }

let refuse _ = raise (P9_server.Error "permission denied")

let fs : file P9_server.fs =
  { attach = (fun _user aname ->
      match Option.bind (int_of_string_opt aname) Wm.find with
      | Some win -> { win; dev = None }
      | None -> raise (P9_server.Error ("unknown window: " ^ aname)));
    walk = (fun f name ->
      match f.dev, List.find_opt (fun (d : Device.t) -> d.name = name) devices with
      | None, Some d -> { f with dev = Some d }
      | _ -> if name = ".." then { f with dev = None } else raise (P9_server.Error "file does not exist"));
    stat = entry;
    opened = (fun f mode -> match f.dev with Some d -> d.opened f.win mode | None -> ());
    read = (fun f offset count -> match f.dev with Some d -> d.read f.win offset count | None -> "");
    entries = (fun f -> List.map (fun d -> entry { f with dev = Some d }) devices);
    write = (fun f _offset data -> (match f.dev with Some d -> d.write f.win data | None -> ()); String.length data);
    create = (fun f _ _ _ -> refuse f); remove = refuse; wstat = (fun f _ -> refuse f);
    clunk = (fun f was_open -> match f.dev with Some d when was_open -> d.closed f.win | _ -> ()) }

let serve (requests : bytes Event.channel) mine =
  let server = P9_server.make fs (fun bytes -> ignore (Unix.write_substring mine bytes 0 (String.length bytes))) in
  let pending = Buffer.create 8192 in
  let rec loop () =
    Buffer.add_bytes pending (Event.sync (Event.receive requests));
    let all = Buffer.contents pending in
    let size o = Char.code all.[o] lor (Char.code all.[o + 1] lsl 8) lor (Char.code all.[o + 2] lsl 16) in
    let rec each o = if o + 4 <= String.length all && o + size o <= String.length all then begin P9_server.request server (String.sub all o (size o)); each (o + size o) end else o in
    let rest = each 0 in
    Buffer.clear pending;
    Buffer.add_substring pending all rest (String.length all - rest);
    loop () in
  loop ()
