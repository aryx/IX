(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernel.mli *)

(* what draws, what keeps files on the disk, and what gives a process
 * its memory (KGraphics, KFS, KMemory); and
 * the kernel's own parts, in their order (TinyKernel.mli): the
 * Makefile gives tiny-ml their files before this one, as one program *)
open KGraphics
open KFS
open KMemory
open KMachine
open KFiles
open KProcs
open KDevices
open KCalls
open KScheduler

(*****************************************************************************)
(* The boot *)
(*****************************************************************************)

let () =
  k_init ();
  if cores > 1 then k_ie 27;
  counted := k_clock ();
  k_timer tick;
  load (k_end ());
  (match root with
   | Dir d ->
       d := !d @ [ "dev", Dir (ref [ "console", Tty; "draw", Screen;
                                    "mouse", Pointer; "audio", Speaker;
                                    "ps", Ps ]) ]
   | _ -> ());
  k_zero ring_at ring;
  poke speaker_dev ring_at;
  (* how the processes get memory: /lib/memory, which the Makefile's
   * MEMORY=segments puts in the image; partitions otherwise *)
  (match walk root (names [] "/lib/memory") with
   | Some node ->
       let s = contents node in
       let says w =
         String.length s >= String.length w
         && String.sub s 0 (String.length w) = w in
       segments := says "segments";
       pages := says "pages"
   | None -> ());
  puts ("tiny-kernel: TinyKernel.ml, "
        ^ string_of_int ((mem_high - mem_low) / part) ^ " MB for "
        ^ string_of_int nslots ^ " processes"
        ^ (if !segments then ", in segments\n"
           else if !pages then ", in pages\n" else "\n"));
  (* The disk, when there is one, is the root: the top becomes a union
   * of the disk's root, of /boot and /dump, and of the image's files.
   * Its snapshots are in /dump, each under the number of the boot that
   * left it. Its /bin and /usr/glenda are made at its first boot, and the
   * first shell starts in /usr/glenda. A second disk, the sources', is
   * /src. A disk's transfers are its device's: the block, the address,
   * the command (1 the block to memory, 2 back), its status cleared *)
  let disk_io dev b a io =
    poke dev b;
    poke (dev + 4) a;
    poke (dev + 8) (match io with Disk_read -> 1 | Disk_write -> 2);
    poke (dev + 12) 0 in
  fs_clock := date;
  let blocks = peek disk_dev in
  if blocks > 0 then begin
    let fs = fs_mount (disk_io disk_dev) 0 blocks in
    let made d name =
      match fs_lookup fs 0 d name with
      | None -> fs_create fs d name Fs_dir
      | Some j -> j in
    ignore (made 1 "bin");
    ignore (made (made 1 "usr") "glenda");
    fs_commit fs;
    let dumps =
      List.map (fun (r, boot) -> string_of_int boot, Disk (fs, r, 1))
        (fs_snapshots fs) in
    let blocks2 = peek disk2_dev in
    let src =
      if blocks2 = 0 then []
      else [ "src", Disk (fs_mount (disk_io disk2_dev) 1 blocks2, 0, 1) ] in
    top := Union [ Disk (fs, 0, 1);
                   Dir (ref ([ "boot", root; "dump", Dir (ref dumps) ] @ src));
                   root ];
    puts ("tiny-kernel: / on a disk of " ^ string_of_int blocks ^ " KB, "
          ^ string_of_int (fs_free fs) ^ " KB free; "
          ^ string_of_int (List.length dumps) ^ " snapshots in /dump"
          ^ (if blocks2 = 0 then ""
             else "; /src on a disk of " ^ string_of_int blocks2 ^ " KB")
          ^ "\n")
  end;
  (* the first process: /bin/sh, the console its 0, 1 and 2; and for the
   * programs it runs, which inherit them, the screen its 3 (a
   * connection) and the mouse its 4: a window system gives a window's
   * programs the same five, so a program draws in what it was given
   * and does not ask where *)
  let fds = [ 0, Console; 1, Console; 2, Console;
              3, Draw { conn = connect screen font; refs = 1 };
              4, Peek mouse ] in
  let p = {
    slot = 0; mem = mem_empty (); pid = 1; state = Ready; parent = None;
    fds = fds; cwd = (if blocks > 0 then [ "usr"; "glenda" ] else []);
    since = None; traced = None; core = None; doomed = false;
    cmd = ""; memory = 0;
  } in
  incr next_pid;
  procs := [ p ];
  (try load_prog p (walk !top [ "bin"; "sh" ]) [ "sh" ]
   with Bad | No_room -> puts "no /bin/sh\n"; halt 1);
  schedule ()
