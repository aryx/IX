(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A file of a tiny-kernel disk on the standard output, by TinyKernelFS.ml
 * on the host: what tiny-kernel made on its disk, for the host to compare
 * (TinyKernel/Makefile's self: the image built on tiny-kernel). The disk
 * is read whole and mounted as the kernel mounts it, in memory: the file
 * is left as it was.
 * usage: Cat.exe disk path *)

let () =
  match Sys.argv with
  | [| _; file; path |] ->
      let disk = Bytes.of_string (In_channel.with_open_bin file In_channel.input_all) in
      TinyKernelFS.fs_io := (fun b a cmd ->
        if cmd = 1 then Bytes.blit disk (b * 1024) TinyMemory.mem a 1024
        else Bytes.blit TinyMemory.mem a disk (b * 1024) 1024);
      TinyKernelFS.fs_mount (Bytes.length disk / 1024);
      let inode = List.fold_left (fun d name -> if d = 0 || name = "" then d else TinyKernelFS.fs_lookup 0 d name) 1
          (String.split_on_char '/' path) in
      if inode = 0 then (prerr_endline (path ^ ": not on the disk"); exit 1);
      print_string (TinyKernelFS.fs_contents 0 inode)
  | _ -> prerr_endline "usage: Cat.exe disk path"; exit 2
