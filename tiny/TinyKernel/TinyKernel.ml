(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernel.mli *)

(* what draws, what keeps files on the disk, and what gives a process
 * its memory (KGraphics, KFS, KMemory); and
 * the kernel's own parts, in their order (TinyKernel.mli): the
 * Makefile gives tiny-ml their files before this one, as one program *)
open KProcs

(*****************************************************************************)
(* The boot *)
(*****************************************************************************)

let () =
  KMachine.k_init ();
  if KMachine.cores > 1 then KMachine.k_ie 27;
  KDevices.counted := KMachine.k_clock ();
  KMachine.k_timer KMachine.tick;
  KFiles.load (KMachine.k_end ());
  (match KFiles.root with
   | Dir d ->
       let devs : (string * KFiles.node) list =
         [ "console", Tty; "draw", Screen; "mouse", Pointer;
           "audio", Speaker; "ps", Ps ] in
       d := !d @ [ "dev", Dir (ref devs) ]
   | _ -> ());
  KMachine.k_zero KMachine.ring_at KDevices.ring;
  KMachine.poke KMachine.speaker_dev KMachine.ring_at;
  (* how the processes get memory: /lib/memory, which the Makefile's
   * MEMORY=segments puts in the image; partitions otherwise *)
  (match KFiles.walk KFiles.root (KFiles.names [] "/lib/memory") with
   | Some node ->
       let s = KFiles.contents node in
       let says w =
         String.length s >= String.length w
         && String.sub s 0 (String.length w) = w in
       KMemory.segments := says "segments";
       KMemory.pages := says "pages"
   | None -> ());
  let mb = (KMemory.mem_high - KMemory.mem_low) / KMemory.part in
  KMachine.puts ("tiny-kernel: TinyKernel.ml, "
        ^ string_of_int mb ^ " MB for "
        ^ string_of_int KMachine.nslots ^ " processes"
        ^ (if !KMemory.segments then ", in segments\n"
           else if !KMemory.pages then ", in pages\n" else "\n"));
  (* The disk, when there is one, is the root: the top becomes a union
   * of the disk's root, of /boot and /dump, and of the image's files.
   * Its snapshots are in /dump, each under the number of the boot that
   * left it. Its /bin and /usr/glenda are made at its first boot, and the
   * first shell starts in /usr/glenda. A second disk, the sources', is
   * /src. A disk's transfers are its device's: the block, the address,
   * the command (1 the block to memory, 2 back), its status cleared *)
  let disk_io dev b a (io : KFS.disk_io) =
    KMachine.poke dev b;
    KMachine.poke (dev + 4) a;
    KMachine.poke (dev + 8) (match io with Disk_read -> 1 | Disk_write -> 2);
    KMachine.poke (dev + 12) 0 in
  KFS.fs_clock := KDevices.date;
  let blocks = KMachine.peek KMachine.disk_dev in
  if blocks > 0 then begin
    let fs = KFS.fs_mount (disk_io KMachine.disk_dev) 0 blocks in
    let made d name =
      match KFS.fs_lookup fs 0 d name with
      | None -> KFS.fs_create fs d name Fs_dir
      | Some j -> j in
    ignore (made 1 "bin");
    ignore (made (made 1 "usr") "glenda");
    KFS.fs_commit fs;
    let dumps =
      List.map (fun (r, boot) -> string_of_int boot, KFiles.Disk (fs, r, 1))
        (KFS.fs_snapshots fs) in
    let blocks2 = KMachine.peek KMachine.disk2_dev in
    let src : (string * KFiles.node) list =
      if blocks2 = 0 then []
      else
        let fs2 = KFS.fs_mount (disk_io KMachine.disk2_dev) 1 blocks2 in
        [ "src", Disk (fs2, 0, 1) ] in
    let more : (string * KFiles.node) list =
      [ "boot", KFiles.root; "dump", Dir (ref dumps) ] @ src in
    let top : KFiles.node =
      Union [ Disk (fs, 0, 1); Dir (ref more); KFiles.root ] in
    KFiles.top := top;
    KMachine.puts ("tiny-kernel: / on a disk of " ^ string_of_int blocks
          ^ " KB, " ^ string_of_int (KFS.fs_free fs) ^ " KB free; "
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
  let screen = KGraphics.connect KDevices.screen KDevices.font in
  let fds : (int * KFiles.file) list =
    [ 0, Console; 1, Console; 2, Console;
      3, Draw { conn = screen; refs = 1 }; 4, Peek KDevices.mouse ] in
  let p = {
    slot = 0; mem = KMemory.mem_empty (); pid = 1; state = Ready; parent = None;
    fds = fds; cwd = (if blocks > 0 then [ "usr"; "glenda" ] else []);
    since = None; traced = None; core = None; doomed = false;
    cmd = ""; memory = 0;
  } in
  incr next_pid;
  procs := [ p ];
  (try KCalls.load_prog p (KFiles.walk !KFiles.top [ "bin"; "sh" ]) [ "sh" ]
   with Bad | KMemory.No_room -> KMachine.puts "no /bin/sh\n"; KMachine.halt 1);
  KScheduler.schedule ()
