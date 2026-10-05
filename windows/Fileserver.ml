(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Fileserver.mli *)

type what = Dir | Cons | Consctl
type file = { win : Window.t; what : what }

let entry (f : file) : Sys_plan9.dir =
  let name, code, perm, t = match f.what with
    | Dir -> "/", 0, 0o555, Sys_plan9.dmdir
    | Cons -> "cons", 1, 0o666, 0
    | Consctl -> "consctl", 2, 0o222, 0 in
  { name; uid = "ix"; gid = "ix"; muid = "ix"; dev_type = '\000'; dev = 0;
    qid_path = Int64.of_int ((f.win.id * 16) + code); qid_vers = 0L; qid_type = t; mode_type = t; perm;
    atime = 0.0; mtime = 0.0; length = 0 }

let refuse _ = raise (P9_server.Error "permission denied")

let fs (window : int -> Window.t option) : file P9_server.fs =
  { attach = (fun _user aname ->
      match Option.bind (int_of_string_opt aname) window with
      | Some win -> { win; what = Dir }
      | None -> raise (P9_server.Error ("unknown window: " ^ aname)));
    walk = (fun f name ->
      match f.what, name with
      | Dir, "cons" -> { f with what = Cons }
      | Dir, "consctl" -> { f with what = Consctl }
      | _, ".." -> { f with what = Dir }
      | _ -> raise (P9_server.Error "file does not exist"));
    stat = entry;
    opened = (fun _ _ -> ());
    (* the console's read waits for a line typed in the window *)
    read = (fun f _offset count ->
      match f.what with
      | Cons -> raise (P9_server.Later (fun reply -> Window.read f.win reply count))
      | _ -> "");
    entries = (fun f -> [ entry { f with what = Cons }; entry { f with what = Consctl } ]);
    write = (fun f _offset data -> (match f.what with Cons -> Window.wrote f.win data | _ -> ()); String.length data);
    create = (fun f _ _ _ -> refuse f); remove = refuse; wstat = (fun f _ -> refuse f);
    clunk = (fun _ -> ()) }
