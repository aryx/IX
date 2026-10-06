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
 * Reading only, for now (plan_rio.md, stage 5): a file opened to be
 * written is refused. As dossrv, the files are bill's and trog's,
 * rw-rw-rw-, and a name is found whatever its letters' case; not as
 * dossrv, a name of 8.3 characters is shown in the case it was written
 * with (Fat). *)

type caps = < Cap.open_in; Cap.open_out; Cap.fork; Cap.stderr >

(* a file of a tree: its file system, its entry there, the directory it
 * was reached from (for "..") *)
type file = { fat : Fat.t; entry : Fat.entry; parent : file option }

let dir_of (f : file) : Sys_plan9.dir =
  let e = f.entry in
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

let fs (caps : < caps; .. >) (default : string) : file P9_server.fs =
  (* the devices attached so far, each read once *)
  let devices : (string, Fat.t) Hashtbl.t = Hashtbl.create 4 in
  { attach = (fun _user aname ->
      let device = if aname = "" then default else aname in
      if device = "" then raise (P9_server.Error "no file system device specified");
      let fat = match Hashtbl.find_opt devices device with
        | Some fat -> fat
        | None ->
            let fat = try Fat.make (pread (FS.open_in_fd caps device)) with Failure m -> raise (P9_server.Error m) in
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
    opened = (fun _ mode -> if mode land 3 = 1 || mode land 3 = 2 || mode land (16 lor 64) <> 0 then raise (P9_server.Error P9_server.read_only));
    read = (fun f offset count -> Fat.read f.fat f.entry offset count);
    entries = (fun f -> List.map (fun entry -> dir_of { fat = f.fat; entry; parent = Some f }) (Fat.entries f.fat f.entry));
    write = P9_server.no_write; create = P9_server.no_create; remove = P9_server.no_remove; wstat = P9_server.no_wstat;
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
      let fd = P9_server.post caps name in
      (* the server is a process of its own: this one ends, and its shell goes on *)
      (match CapUnix.fork caps () with
       | 0 -> P9_server.serve (fs caps !device) fd; Unix._exit 0
       | _ -> Console.eprint caps (Printf.sprintf "dossrv: serving #s/%s\n" name));
      Exit.OK
  | _ -> Console.eprint caps "usage: dossrv [-v] [-s] [-f devicefile] [srvname]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
