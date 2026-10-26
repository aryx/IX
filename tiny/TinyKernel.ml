(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernel.mli *)

(* what draws, what keeps files on the disk, and what gives a process
 * its memory (TinyKernelGraphics, TinyKernelFS, TinyKernelMemory); and
 * the kernel's own parts, in their order (TinyKernel.mli): the
 * Makefile gives tiny-ml their files before this one, as one program *)
open TinyKernelGraphics
open TinyKernelFS
open TinyKernelMemory
open TinyKernelMachine
open TinyKernelFiles
open TinyKernelProcs
open TinyKernelDevices
open TinyKernelCalls
open TinyKernelScheduler

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
                                    "mouse", Pointer; "audio", Speaker ]) ]
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
   * first shell starts in /usr/glenda. *)
  let blocks = peek disk_dev in
  if blocks > 0 then begin
    fs_io := (fun b a cmd ->
      poke disk_dev b;
      poke (disk_dev + 4) a;
      poke (disk_dev + 8) cmd;
      poke (disk_dev + 12) 0);
    fs_clock := date;
    fs_mount blocks;
    let made d name =
      match fs_lookup 0 d name with 0 -> fs_create d name 1 | j -> j in
    ignore (made 1 "bin");
    ignore (made (made 1 "usr") "glenda");
    fs_commit ();
    let dumps =
      List.map (fun (r, boot) -> string_of_int boot, Disk (r, 1))
        (fs_snapshots ()) in
    top := Union [ Disk (0, 1);
                   Dir (ref [ "boot", root; "dump", Dir (ref dumps) ]);
                   root ];
    puts ("tiny-kernel: / on a disk of " ^ string_of_int blocks ^ " KB, "
          ^ string_of_int (fs_free ()) ^ " KB free; "
          ^ string_of_int (List.length dumps) ^ " snapshots in /dump\n")
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
    slot = 0; mem = mem_empty (); pid = 1; state = Ready; parent = 0;
    fds = fds; cwd = (if blocks > 0 then [ "usr"; "glenda" ] else []);
    since = -1; traced = None; core = -1; doomed = false;
  } in
  incr next_pid;
  procs := [ p ];
  (try load_prog p (walk !top [ "bin"; "sh" ]) [ "sh" ]
   with Bad | No_room -> puts "no /bin/sh\n"; halt 1);
  schedule ()
