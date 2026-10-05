(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See P9_server.mli *)

open P9

exception Error of string

type 'f fs = {
  attach : string -> string -> 'f;
  walk : 'f -> string -> 'f;
  stat : 'f -> Sys_plan9.dir;
  opened : 'f -> int -> unit;
  read : 'f -> int -> int -> string;
  entries : 'f -> Sys_plan9.dir list;
  write : 'f -> int -> string -> int;
  create : 'f -> string -> int -> int -> 'f;
  remove : 'f -> unit;
  wstat : 'f -> Sys_plan9.dir -> unit;
  clunk : 'f -> unit;
}

let read_only = "read only file system"
let no_write _ _ _ = raise (Error read_only)
let no_create _ _ _ _ = raise (Error read_only)
let no_remove _ = raise (Error read_only)
let no_wstat _ _ = raise (Error read_only)

(* a fid: the file, whether it is open, and for a directory being read
 * what is left of its entries (each one's bytes) and the offset the
 * next read must ask *)
type 'f fid_state = { file : 'f; mutable is_open : bool; mutable rest : string list; mutable next : int }

let serve (fs : 'f fs) fd =
  let fids : (int, 'f fid_state) Hashtbl.t = Hashtbl.create 32 in
  let msize = ref (8192 + io_header_size) in
  let find fid = match Hashtbl.find_opt fids fid with Some st -> st | None -> raise (Error "unknown fid") in
  let fresh fid file = if Hashtbl.mem fids fid then raise (Error "fid in use"); Hashtbl.replace fids fid { file; is_open = false; rest = []; next = 0 } in
  let is_dir file = (fs.stat file).qid_type land Sys_plan9.dmdir <> 0 in
  let answer (req : Request.t) : Response.t =
    match req with
    | Request.Version (size, version) ->
        Hashtbl.reset fids;
        msize := min size !msize;
        Response.Version (!msize, if String.length version >= 6 && String.sub version 0 6 = "9P2000" then "9P2000" else "unknown")
    | Request.Auth _ -> raise (Error "authentication not required")
    | Request.Attach (fid, _, user, aname) ->
        let root = fs.attach user aname in
        fresh fid root;
        Response.Attach (qid_of (fs.stat root))
    | Request.Walk (fid, newfid, names) ->
        let st = find fid in
        if st.is_open then raise (Error "walk of an open fid");
        (* as far as the names lead: all of them for the new fid to be;
         * none at all is an error, the first's *)
        let rec down file names qids =
          match names with
          | [] -> Some file, List.rev qids
          | name :: more -> (
              match fs.walk file name with
              | next -> down next more (qid_of (fs.stat next) :: qids)
              | exception Error e -> if qids = [] then raise (Error e) else None, List.rev qids) in
        let reached, qids = down st.file names [] in
        (match reached with
         | Some file -> if newfid = fid then Hashtbl.remove fids fid; fresh newfid file
         | None -> ());
        Response.Walk qids
    | Request.Open (fid, mode) ->
        let st = find fid in
        if st.is_open then raise (Error "fid already open");
        fs.opened st.file mode;
        st.is_open <- true;
        Response.Open (qid_of (fs.stat st.file), 0)
    | Request.Create (fid, name, perm, mode) ->
        let st = find fid in
        let file = fs.create st.file name perm mode in
        Hashtbl.replace fids fid { file; is_open = true; rest = []; next = 0 };
        Response.Create (qid_of (fs.stat file), 0)
    | Request.Read (fid, offset, count) ->
        let st = find fid in
        if not st.is_open then raise (Error "fid not open");
        let count = min count (!msize - io_header_size) in
        if is_dir st.file then begin
          (* whole entries, from the start or where the last read ended *)
          if offset = 0 then begin st.rest <- List.map P9_wire.encode_dir (fs.entries st.file); st.next <- 0 end
          else if offset <> st.next then raise (Error "bad offset in directory read");
          let b = Buffer.create count in
          let rec take = function
            | e :: more when Buffer.length b + String.length e <= count -> Buffer.add_string b e; take more
            | rest -> rest in
          st.rest <- take st.rest;
          st.next <- offset + Buffer.length b;
          Response.Read (Buffer.contents b)
        end
        else Response.Read (fs.read st.file offset count)
    | Request.Write (fid, offset, data) ->
        let st = find fid in
        if not st.is_open then raise (Error "fid not open");
        Response.Write (fs.write st.file offset data)
    | Request.Clunk fid ->
        let st = find fid in
        Hashtbl.remove fids fid;
        fs.clunk st.file;
        Response.Clunk
    | Request.Remove fid ->
        let st = find fid in
        Hashtbl.remove fids fid;
        fs.remove st.file;
        Response.Remove
    | Request.Stat fid -> Response.Stat (fs.stat (find fid).file)
    | Request.Wstat (fid, d) -> fs.wstat (find fid).file d; Response.Wstat
    | Request.Flush _ -> Response.Flush in
  let reply tag r =
    let bytes = P9_wire.encode { tag; mtyp = R r } in
    ignore (Unix.write_substring fd bytes 0 (String.length bytes)) in
  let rec loop () =
    match P9_wire.read fd with
    | None -> ()
    | Some bytes ->
        (match P9_wire.decode bytes with
         | { tag; mtyp = T req } ->
             reply tag (try answer req with
                        | Error e -> Response.Error e
                        | Unix.Unix_error (e, _, _) -> Response.Error (Unix.error_message e)
                        | Sys_error e | Failure e -> Response.Error e)
         | { tag; mtyp = R _ } -> reply tag (Response.Error "a response, not a request")
         | exception Failure e -> reply notag (Response.Error e));
        loop () in
  loop ()

let post (caps : < Cap.open_out; .. >) name =
  let mine, posted = Unix.pipe ~cloexec:false () in
  (* /srv takes a descriptor's number, written to a file made there *)
  let number = string_of_int (Obj.magic posted : int) in
  Fpath.v ("/srv/" ^ name) |> FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc number);
  Unix.close posted;
  mine
