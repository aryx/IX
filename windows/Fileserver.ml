(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Fileserver.mli *)

type what = Dir | Cons | Consctl | Mouse | Winname
type file = { win : Window.t; what : what }

let entry (f : file) : Sys_plan9.dir =
  let name, code, perm, t = match f.what with
    | Dir -> "/", 0, 0o555, Sys_plan9.dmdir
    | Cons -> "cons", 1, 0o666, 0
    | Consctl -> "consctl", 2, 0o222, 0
    | Mouse -> "mouse", 3, 0o666, 0
    | Winname -> "winname", 4, 0o444, 0 in
  { name; uid = "ix"; gid = "ix"; muid = "ix"; dev_type = '\000'; dev = 0;
    qid_path = Int64.of_int ((f.win.id * 16) + code); qid_vers = 0L; qid_type = t; mode_type = t; perm;
    atime = 0.0; mtime = 0.0; length = 0 }

let refuse _ = raise (P9_server.Error "permission denied")

(* Each request is a message to the window's thread: the file server
 * waits only until the thread takes it. A read is answered by the
 * thread, when it can (P9_server.Later: it is given how to). *)
let fs (window : int -> Window.t option) : file P9_server.fs =
  { attach = (fun _user aname ->
      match Option.bind (int_of_string_opt aname) window with
      | Some win -> { win; what = Dir }
      | None -> raise (P9_server.Error ("unknown window: " ^ aname)));
    walk = (fun f name ->
      match f.what, name with
      | Dir, "cons" -> { f with what = Cons }
      | Dir, "consctl" -> { f with what = Consctl }
      | Dir, "mouse" -> { f with what = Mouse }
      | Dir, "winname" -> { f with what = Winname }
      | _, ".." -> { f with what = Dir }
      | _ -> raise (P9_server.Error "file does not exist"));
    stat = entry;
    opened = (fun f _ -> if f.what = Mouse then Window.send f.win (Window.Mouse_file true));
    read = (fun f offset count ->
      match f.what with
      | Cons -> raise (P9_server.Later (fun reply -> Window.send f.win (Window.Read (reply, count))))
      | Mouse -> raise (P9_server.Later (fun reply -> Window.send f.win (Window.Mouse_read reply)))
      | Winname -> let n = Window.name f.win in if offset >= String.length n then "" else String.sub n offset (min count (String.length n - offset))
      | _ -> "");
    entries = (fun f -> List.map (fun what -> entry { f with what }) [ Cons; Consctl; Mouse; Winname ]);
    write = (fun f _offset data ->
      (match f.what with
       | Cons -> Window.send f.win (Window.Wrote data)
       | Consctl -> if data = "rawon" then Window.send f.win (Window.Raw true) else if data = "rawoff" then Window.send f.win (Window.Raw false)
       | _ -> ());
      String.length data);
    create = (fun f _ _ _ -> refuse f); remove = refuse; wstat = (fun f _ -> refuse f);
    (* (the program that had the mouse, or the raw keyboard, is done with it) *)
    clunk = (fun f was_open ->
      if was_open then match f.what with
        | Mouse -> Window.send f.win (Window.Mouse_file false)
        | Consctl -> Window.send f.win (Window.Raw false)
        | _ -> ()) }
