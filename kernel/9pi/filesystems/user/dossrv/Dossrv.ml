(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-dossrv: Plan 9's dossrv (principia's
 * kernel/filesystems/user/dossrv: here in the same place, under the
 * kernel it is for), a file server for MS-DOS's file
 * systems: it posts /srv/dos, and a mount of it with a device's file
 * as its tree (mount -c /srv/dos /n/c /dev/sdM0/dos) gives that
 * device's FAT as files. A program like another: the kernel speaks 9P
 * to this (lib_9p), and what a FAT is is ../../lib_fat's (which the
 * kernel can use itself, with no program: Kdos, bind '#Fdos' /root).
 *
 * Files are read, written, made and removed (Fat does it; a device
 * that cannot be opened for writing is served for reading). Not: a
 * file's name changed (wstat). As dossrv, the files are bill's and trog's,
 * rw-rw-rw-, and a name is found whatever its letters' case; not as
 * dossrv, a name of 8.3 characters is shown in the case it was written
 * with (Fat). *)

type caps = < Cap.open_in; Cap.open_out; Cap.fork; Cap.stderr >

(* a file of a tree: its file system, its entry there, the directory it
 * was reached from (for "..") *)
type file = { fat : Fat.t; mutable entry : Fat.entry; parent : file option }

(* Fat's refusal, as the server's *)
let failing f = try f () with Failure m -> raise (P9_server.Error m)

(* a file's entry as it is on the disk now: another fid may have written it *)
let now (f : file) = f.entry <- failing (fun () -> Fat.refresh f.fat f.entry); f.entry

let dir_of (f : file) : Sys_plan9.dir =
  let e = now f in
  let t = if e.is_dir then Sys_plan9.dmdir else 0 in
  { name = e.name; uid = "bill"; gid = "trog"; muid = ""; dev_type = '\000'; dev = 0;
    qid_path = Int64.of_int e.where; qid_vers = 0L; qid_type = t; mode_type = t;
    perm = (if e.is_dir then 0o777 else if e.read_only then 0o444 else 0o666);
    atime = e.mtime; mtime = e.mtime; length = (if e.is_dir then 0 else e.size) }

(* n bytes of a device's file at an offset (fewer at its end): Fat's way to it *)
let pread fd at n =
  ignore (Unix.lseek fd at Unix.SEEK_SET);
  let b = Bytes.create n in
  let rec go o = if o = n then o else match Unix.read fd b o (n - o) with 0 -> o | k -> go (o + k) in
  Bytes.sub_string b 0 (go 0)

let pwrite fd at s =
  ignore (Unix.lseek fd at Unix.SEEK_SET);
  let rec go o = if o < String.length s then go (o + Unix.write_substring fd s o (String.length s - o)) in
  go 0

let fs (caps : < caps; .. >) (default : string) : file P9_server.fs =
  (* the devices attached so far, each read once *)
  let devices : (string, Fat.t) Hashtbl.t = Hashtbl.create 4 in
  { attach = (fun _user aname ->
      let device = if aname = "" then default else aname in
      if device = "" then raise (P9_server.Error "no file system device specified");
      let fat = match Hashtbl.find_opt devices device with
        | Some fat -> fat
        | None ->
            (* (for writing too, when the device lets it be) *)
            let fat = failing (fun () ->
              match FS.open_rw_fd caps device with
              | fd -> Fat.make (pread fd) (Some (pwrite fd))
              | exception Unix.Unix_error _ -> Fat.make (pread (FS.open_in_fd caps device)) None) in
            Hashtbl.replace devices device fat; fat in
      { fat; entry = Fat.root fat; parent = None });
    walk = (fun f name ->
      if not f.entry.is_dir then raise (P9_server.Error "not a directory");
      if name = ".." then (match f.parent with Some p -> p | None -> f)
      else if name = "." then f
      else
        let wanted = String.lowercase_ascii name in
        match List.find_opt (fun (e : Fat.entry) -> String.lowercase_ascii e.name = wanted) (Fat.entries f.fat f.entry) with
        | Some entry -> { fat = f.fat; entry; parent = Some f }
        | None -> raise (P9_server.Error "file does not exist"));
    stat = dir_of;
    (* (16: OTRUNC, the file emptied) *)
    opened = (fun f mode -> if mode land 16 <> 0 && not f.entry.is_dir then f.entry <- failing (fun () -> Fat.truncate f.fat f.entry));
    read = (fun f offset count -> Fat.read f.fat (now f) offset count);
    entries = (fun f -> List.map (fun entry -> dir_of { fat = f.fat; entry; parent = Some f }) (Fat.entries f.fat f.entry));
    write = (fun f offset data -> f.entry <- failing (fun () -> Fat.write f.fat f.entry offset data); String.length data);
    create = (fun f name perm _mode ->
      let entry = failing (fun () -> Fat.create f.fat f.entry name (perm land (Sys_plan9.dmdir lsl 16) <> 0)) in
      { fat = f.fat; entry; parent = Some f });
    remove = (fun f -> failing (fun () -> Fat.remove f.fat f.entry));
    (* (a name changed is not done; the rest of an entry is FAT's own to say) *)
    wstat = (fun f (d : Sys_plan9.dir) -> if d.name <> "" && d.name <> f.entry.name then raise (P9_server.Error "dossrv: a file's name cannot be changed"));
    clunk = (fun _ _ -> ()) }

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let device = ref "" in
  let rec options = function
    | "-f" :: file :: rest -> device := file; options rest
    | ("-v" | "-s") :: rest -> options rest
    | rest -> rest in
  match options (List.tl (Array.to_list argv)) with
  | ([] | [ _ ]) as rest ->
      let name = match rest with [ name ] -> name | _ -> "dos" in
      Fat.clock := Unix.time;
      let fd = P9_server.post caps name in
      (* the server is a process of its own: this one ends, and its shell goes on *)
      (match CapUnix.fork caps () with
       | 0 -> P9_server.serve (fs caps !device) fd; Unix._exit 0
       | _ -> Console.eprint caps (Printf.sprintf "dossrv: serving #s/%s\n" name));
      Exit.OK
  | _ -> Console.eprint caps "usage: dossrv [-v] [-s] [-f devicefile] [srvname]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
