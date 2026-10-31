(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fileserver.mli *)

(* a window's files: a file more is a line here *)
let devices : Device.t list =
  [ Virtual_cons.cons; Virtual_cons.consctl; Virtual_cons.kbd; Virtual_mouse.mouse; Virtual_mouse.cursor;
    Dev_wm.winname; Dev_wm.winid; Dev_wm.label; Dev_wm.text; Dev_wm.window; Dev_wm.screen; Dev_wm.snarf; Wctl.wctl ]

(* The tree. The root is what -i's process has (no window's): a wctl for
 * new, and wsys. A window's directory is what its process has, wsys
 * too, in which each window is again, as rio's. *)
type file = Root | Root_wctl | Wsys | Dir of Window.t | Dev of Window.t * Device.t

let entry (f : file) : Sys_plan9.dir =
  let rec number k (d : Device.t) = function x :: more -> if x == d then k else number (k + 1) d more | [] -> 0 in
  let name, id, code, perm, t = match f with
    | Root -> "/", 0, 0, 0o555, Sys_plan9.dmdir
    | Root_wctl -> "wctl", 0, 1, 0o666, 0
    | Wsys -> "wsys", 0, 2, 0o555, Sys_plan9.dmdir
    | Dir w -> string_of_int w.id, w.id, 0, 0o555, Sys_plan9.dmdir
    | Dev (w, d) -> d.name, w.id, number 1 d devices, d.perm, 0 in
  { name; uid = "ix"; gid = "ix"; muid = "ix"; dev_type = '\000'; dev = 0;
    qid_path = Int64.of_int ((id * 64) + code); qid_vers = 0L; qid_type = t; mode_type = t; perm;
    atime = 0.0; mtime = 0.0; length = 0 }

let refuse _ = raise (P9_server.Error "permission denied")
let absent () = raise (P9_server.Error "file does not exist")

let window_of name = Option.bind (int_of_string_opt name) Wm.find

let fs : file P9_server.fs =
  { attach = (fun _user aname ->
      if aname = "" then Root
      else match window_of aname with
        | Some win -> Dir win
        | None -> raise (P9_server.Error ("unknown window: " ^ aname)));
    walk = (fun f name ->
      match f, name with
      | (Root | Root_wctl | Wsys), ".." -> Root
      | Root, "wctl" -> Root_wctl
      | (Root | Dir _), "wsys" -> Wsys
      | Wsys, _ -> (match window_of name with Some w -> Dir w | None -> absent ())
      | (Dir w | Dev (w, _)), ".." -> Dir w
      | Dir w, _ -> (match List.find_opt (fun (d : Device.t) -> d.name = name) devices with Some d -> Dev (w, d) | None -> absent ())
      | _ -> absent ());
    stat = entry;
    opened = (fun f mode -> match f with Dev (w, d) -> d.opened w mode | _ -> ());
    read = (fun f offset count -> match f with Dev (w, d) -> d.read w offset count | _ -> "");
    entries = (fun f ->
      match f with
      | Root -> [ entry Root_wctl; entry Wsys ]
      | Wsys -> List.map (fun w -> entry (Dir w)) (List.sort (fun (a : Window.t) (b : Window.t) -> compare a.id b.id) !Wm.windows)
      | Dir w -> List.map (fun d -> entry (Dev (w, d))) devices @ [ entry Wsys ]
      | Root_wctl | Dev _ -> []);
    write = (fun f _offset data ->
      (match f with
       | Dev (w, d) -> d.write w data
       | Root_wctl -> Wctl.written None data
       | _ -> ());
      String.length data);
    create = (fun f _ _ _ -> refuse f); remove = refuse; wstat = (fun f _ -> refuse f);
    clunk = (fun f was_open -> match f with Dev (w, d) when was_open -> d.closed w | _ -> ()) }

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
