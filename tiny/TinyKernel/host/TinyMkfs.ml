(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMkfs.mli *)

let usage =
  "usage: tiny-mkfs [-m megabytes] disk.img name=file|directory/... \
   | tiny-mkfs -l disk.img"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
A disk of tiny-kernel's file system (TinyKernel/KFS.ml), made on
the host by the kernel's own code: the files named, each under its name on
the disk; a name with / makes the directories on its way, and a name that
ends with / is a directory, empty. Files that are one on the host (hard
links, ln) are one on the disk, under each name. tiny-machine -d gives the disk to the
machine, where the kernel shows it at /, with the image's files.
  tiny-mkfs disk.img src/hello.c=hello.c tmp/
                                  8 MB: /src/hello.c, and /tmp, empty
  tiny-mkfs -m 64 disk.img ...    64 MB, the most (64 K blocks of 1 KB)
  tiny-mkfs -l disk.img           each file read back: its path and size
|}

(* where a file's bytes are put in the machine's memory for the file
 * system to write them, a piece at a time (the file system's own
 * buffers are at 10 MB) *)
let scratch = 0x100000
let piece = 0x10000

(* the disk's bytes, the file system's transfers on them; mounted as
 * the kernel mounts it (made when blank), the dates 0, so that the same
 * files make the same disk *)
let mount (disk : Bytes.t) : KFS.fs =
  KFS.fs_clock := (fun () -> 0);
  KFS.fs_mount (fun b a io ->
      match io with
      | KFS.Disk_read -> Bytes.blit disk (b * 1024) KRaw.mem a 1024
      | Disk_write -> Bytes.blit KRaw.mem a disk (b * 1024) 1024)
    0 (Bytes.length disk / 1024)

(* the directory at the end of names from d, made where it is missing *)
let rec directory fs (d : KFS.inode) (names : string list) =
  match names with
  | [] -> d
  | n :: rest ->
      let sub =
        match KFS.fs_lookup fs 0 d n with
        | Some i when KFS.fs_is_dir fs 0 i -> i
        | Some _ -> failwith (n ^ ": a file, not a directory")
        | None -> KFS.fs_create fs d n KFS.Fs_dir in
      directory fs sub rest

(* what a name is given: a directory, a file's bytes, or a file already
 * on the disk (a hard link) *)
type contents = Directory | Bytes of string | Link of KFS.inode

(* a name made on the disk, a file's then committed (a commit a file:
 * the blocks written since the last one are a list the file system
 * searches); its inode *)
let add fs (path : string) (contents : contents) : KFS.inode =
  let names = List.filter (fun n -> n <> "") (String.split_on_char '/' path) in
  match contents, List.rev names with
  | Directory, _ ->
      let d = directory fs 1 names in
      KFS.fs_commit fs;
      d
  | _, [] -> failwith (path ^ ": no name")
  | (Bytes _ | Link _), name :: rdirs ->
      let d = directory fs 1 (List.rev rdirs) in
      if KFS.fs_lookup fs 0 d name <> None then
        failwith (path ^ ": named twice");
      let n =
        match contents with
        | Link n -> KFS.fs_link fs d name n; n
        | _ -> KFS.fs_create fs d name KFS.Fs_file in
      let rec write s off =
        if off < String.length s then begin
          let k = min piece (String.length s - off) in
          Bytes.blit_string s off KRaw.mem scratch k;
          KFS.fs_write_at fs n off scratch k;
          write s (off + k)
        end in
      (match contents with Bytes s -> write s 0 | _ -> ());
      KFS.fs_commit fs;
      n

(* each file's path and size, each directory's path and a /, the live
 * tree's from the root *)
let rec list fs (path : string) (d : KFS.inode) : string list =
  List.concat_map (fun (name, i) ->
      let p = path ^ "/" ^ name in
      match KFS.fs_kind fs 0 i with
      | KFS.Fs_dir, _, _ -> (p ^ "/\n") :: list fs p i
      | Fs_file, size, _ -> [ p ^ " " ^ string_of_int size ^ "\n" ])
    (KFS.fs_entries fs 0 d)

let main (caps : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    (argv : string array) : Exit.t =
  let read f = FS.read caps (Fpath.v f) in
  let make mb img specs =
    let disk = Bytes.make (mb * 0x100000) '\000' in
    let fs = mount disk in
    (* the host's files of several names (hard links: install's ln),
     * by their device and inode, and the disk's inode of the first *)
    let seen = Hashtbl.create 16 in
    List.iter (fun spec ->
        match String.index_opt spec '=' with
        | Some i ->
            let name = String.sub spec 0 i in
            let file = String.sub spec (i + 1) (String.length spec - i - 1) in
            let st = Unix.stat file in
            (match Hashtbl.find_opt seen (st.st_dev, st.st_ino) with
             | Some n -> ignore (add fs name (Link n))
             | None ->
                 let n = add fs name (Bytes (read file)) in
                 if st.st_nlink > 1 then
                   Hashtbl.add seen (st.st_dev, st.st_ino) n)
        | None when spec <> "" && spec.[String.length spec - 1] = '/' ->
            ignore (add fs spec Directory)
        | None -> failwith (spec ^ ": not name=file nor directory/"))
      specs;
    FS.write caps (Fpath.v img) (Bytes.to_string disk);
    Exit.OK in
  let megabytes s =
    match int_of_string_opt s with
    | Some n when n >= 1 && n <= 64 -> Some n
    | _ -> None in
  try
    match List.tl (Array.to_list argv) with
    | ("-h" | "--help") :: _ -> Console.print caps help; Exit.OK
    | [ "-l"; img ] ->
        let fs = mount (Bytes.of_string (read img)) in
        Console.print caps (String.concat "" (list fs "" 1));
        Exit.OK
    | "-m" :: m :: img :: specs when megabytes m <> None ->
        make (Option.get (megabytes m)) img specs
    | img :: specs when img <> "" && img.[0] <> '-' -> make 8 img specs
    | _ -> Console.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2
  with
  | Sys_error e | Failure e -> Exit.Err e
  | Unix.Unix_error (e, _, f) -> Exit.Err (f ^ ": " ^ Unix.error_message e)
  | KFS.Disk_full -> Exit.Err "the disk is full: -m more megabytes"

let () = TinyLibSystem.main "tiny-mkfs" main
