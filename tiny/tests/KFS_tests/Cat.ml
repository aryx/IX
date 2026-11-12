(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A file of a tiny-kernel disk on the standard output, by KFS.ml
 * on the host: what tiny-kernel made on its disk, for the host to compare
 * (TinyKernel/Makefile's self: the image built on tiny-kernel). The disk
 * is read whole and mounted as the kernel mounts it, in memory: the file
 * is left as it was.
 * usage: Cat.exe disk path *)

let () =
  match Sys.argv with
  | [| _; file; path |] ->
      let disk =
        Bytes.of_string (In_channel.with_open_bin file In_channel.input_all)
      in
      let fs =
        KFS.fs_mount (fun b a io ->
            match io with
            | KFS.Disk_read -> Bytes.blit disk (b * 1024) KRaw.mem a 1024
            | Disk_write -> Bytes.blit KRaw.mem a disk (b * 1024) 1024)
          0 (Bytes.length disk / 1024) in
      let inode =
        List.fold_left (fun d name ->
            if d = 0 || name = "" then d
            else Option.value ~default:0 (KFS.fs_lookup fs 0 d name))
          1 (String.split_on_char '/' path) in

      if inode = 0 then (prerr_endline (path ^ ": not on the disk"); exit 1);
      print_string (KFS.fs_contents fs 0 inode)
  | _ -> prerr_endline "usage: Cat.exe disk path"; exit 2
