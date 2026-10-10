(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mkbootdir: mini-9pi's bootdir, the files a kernel has in its own
 * image (9pi's kernel/conf/arm/pi's bootdir: /boot/boot the rc script,
 * rcmain, rc, echo, bind...), packed for Devroot, which serves them as
 * /boot: a line "9pi bootdir KERNDATE" (the time the devices' files say
 * they were made: 9pi's kerndate, its build's `date -n`), then for each
 * file a line "name size" and its bytes, then a line "end". The usage:
 * [help], what mini-mkbootdir -h prints.
 *
 * Lines and bytes, not a marshalled list: Devroot reads the files where
 * they are in the image, without a copy of them in the heap (rc alone
 * is 700 KB), and the kernel's runtime has no Marshal.
 * (old: conf/mkbootdir.py, 25 lines of Python: plan_rio.md, decision 5)
 *
 * Where it stands: the kernel's first files. A kernel that has just
 * booted has no disk driver started and no file server to ask, and
 * must still find a first program to run. Plan 9 links a small
 * directory into the kernel itself: /boot/boot is run as the first
 * process and, being a script here (conf's boot.rc), does the rest
 * in the open: the devices bound where programs look for them, the
 * card's partition if there is one, then a shell.
 *
 * others:
 * Linux's initramfs is the same thing with an archive format: a
 * cpio file in the kernel's image (or beside it, loaded by the
 * boot loader), unpacked into a file system in memory, whose /init
 * is the first process. xv6 has no such stage: its kernel knows its
 * one disk and runs /init from it (mini-xv6's Main). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let help = {|usage: mini-mkbootdir out kerndate name=file...
mini-9pi's bootdir: the files of the kernel's own image, its /boot.
  mini-mkbootdir bootdir 1757430000 boot=boot.rc rc=mini-rc ed=mini-ed
                                      /boot/boot, /boot/rc and /boot/ed, their
                                      date the second argument (seconds)
|}

let main (caps : < caps; .. >) (argv : string array) : int =
  match List.tl (Array.to_list argv) with
  | args when List.mem "-h" args || List.mem "--help" args -> Console.print caps help; 0
  | out :: kerndate :: (_ :: _ as pairs) when int_of_string_opt kerndate <> None -> (
      let b = Buffer.create (1 lsl 20) in
      Buffer.add_string b (Printf.sprintf "9pi bootdir %s\n" kerndate);
      try
        List.iter (fun pair ->
          match String.index_opt pair '=' with
          | None -> failwith (pair ^ ": not name=file")
          | Some k ->
              let data = FS.read caps (Fpath.v (String.sub pair (k + 1) (String.length pair - k - 1))) in
              Buffer.add_string b (Printf.sprintf "%s %d\n" (String.sub pair 0 k) (String.length data));
              Buffer.add_string b data) pairs;
        Buffer.add_string b "end\n";
        FS.write caps (Fpath.v out) (Buffer.contents b);
        0
      with Sys_error m | Failure m -> Console.eprint caps ("mini-mkbootdir: " ^ m ^ "\n"); 1)
  | _ -> Console.eprint caps "usage: mini-mkbootdir out kerndate name=file...   (-h: how)\n"; 1

let () = Cap.main (fun caps -> Logging.setup caps ~name:"mini-mkbootdir"; CapStdlib.exit caps (main caps (CapSys.argv caps)))
