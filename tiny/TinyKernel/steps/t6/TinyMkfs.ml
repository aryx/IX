(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMkfs.mli *)

let usage = "usage: tiny-mkfs fs.img file... | tiny-mkfs -l fs.img"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
The disk image of t6's file system (tiny/TinyKernel/steps/t6/), made on
the host: MS-DOS's FAT, 2 MB. For example:
  tiny-mkfs fs.img hello.txt bye.txt    a root directory with the files (by
                                        their base names) and the console
  tiny-mkfs -l fs.img                   the image read back:
    hello.txt            2    9 6       each name, its type (1 a directory,
    console              3    0 0       2 a file, 3 a device), first block, size
./tiny-machine t6 makes one with the programs, and boots on it.
|}

let bsize = 1024
let nblocks = 2048                        (* 2 MB *)
let t_file = 2 and t_dev = 3

(*****************************************************************************)
(* Making *)
(*****************************************************************************)

(* (old: xv6's format too, inodes and a bitmap, for v6, the kernel that
 * was beside t6; -fat chose this one) *)
let fat_magic = 0x7f5f0006
let fatstart = 1 and fatblocks = nblocks * 4 / bsize
let fat_data = fatstart + fatblocks

let make files =
  let disk = Bytes.make (nblocks * bsize) '\000' in
  let put32 at v = Bytes.set_int32_le disk at (Int32.of_int v) in
  let fat b v = put32 ((fatstart * bsize) + (4 * b)) v in
  let next = ref fat_data in
  (* data in a chain of fresh blocks, its first returned (0 if empty) *)
  let chain data =
    let n = (String.length data + bsize - 1) / bsize in
    if !next + n > nblocks then failwith "the disk is full";
    let first = if n = 0 then 0 else !next in
    for k = 0 to n - 1 do
      let b = !next + k in
      Bytes.blit_string data (k * bsize) disk (b * bsize)
        (min bsize (String.length data - (k * bsize)));
      fat b (if k = n - 1 then 0xffffffff else b + 1)
    done;
    next := !next + n;
    first in
  let entry name typ first size =
    if String.length name > 20 then failwith ("a name longer than 20: " ^ name);
    let b = Bytes.make 32 '\000' in
    Bytes.blit_string name 0 b 0 (String.length name);
    List.iteri (fun k v -> Bytes.set_int32_le b (20 + (4 * k)) (Int32.of_int v))
      [ typ; first; size ];
    Bytes.to_string b in
  let root = !next in
  incr next;
  let entries =
    List.map
      (fun (name, data) -> entry name t_file (chain data) (String.length data))
      files
  in
  let dir = String.concat "" (entries @ [ entry "console" t_dev 0 0 ]) in
  if String.length dir > bsize then failwith "too many files for the root's block";
  Bytes.blit_string dir 0 disk (root * bsize) (String.length dir);
  fat root 0xffffffff;
  for b = 0 to fat_data - 1 do fat b 0xffffffff done;
  List.iteri (fun k v -> put32 (4 * k) v)
    [ fat_magic; nblocks; fatstart; fatblocks; root ];
  Bytes.to_string disk

(*****************************************************************************)
(* Reading back *)
(*****************************************************************************)

let list disk =
  let get32 at = Int32.to_int (String.get_int32_le disk at) land 0xffffffff in
  if get32 0 <> fat_magic then failwith "not a t6 file system";
  let root = get32 16 in
  List.init (bsize / 32) (fun e ->
    let at = (root * bsize) + (e * 32) in
    let name = String.sub disk at 20 in
    let name =
      match String.index_opt name '\000' with
      | Some i -> String.sub name 0 i
      | None -> name
    in
    if get32 (at + 20) = 0 then ""
    else
      Printf.sprintf "%-20s %d %4d %d\n" name (get32 (at + 20))
        (get32 (at + 24)) (get32 (at + 28)))
  |> String.concat ""

let main
    (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    =
  let read f = FS.read caps (Fpath.v f) in
  try
    match List.tl (Array.to_list (CapSys.argv caps)) with
    | ("-h" | "--help") :: _ -> Console.print caps help; 0
    | [ "-l"; img ] -> Console.print caps (list (read img)); 0
    | img :: files when img.[0] <> '-' ->
        FS.write caps (Fpath.v img)
          (make (List.map (fun f -> Filename.basename f, read f) files));
        0
    | _ -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  with Failure e | Sys_error e -> Console.eprint caps ("tiny-mkfs: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
