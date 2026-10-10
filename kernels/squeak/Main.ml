(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-squeak's boot on the bare Pi 4 (docs/plans/plan_system_squeak.md):
 * the board's devices (Host), Smalltalk brought up over them and its
 * world started (Squeak: from its image, made by the build; or from
 * its text, Which.system's start), then the world's cycle for ever, the Display
 * shown when it changed. On the serial line: its name, what the start
 * could not do, and a line once the first screen is drawn.
 *
 * mini-squeak as a whole: a machine that boots into Smalltalk and
 * has nothing else. No process, no file, no shell, no system call:
 *
 *     the windows, the Browser, the menus, the atoms    Smalltalk,
 *     Morphic: the world, its morphs, the hand          drawn by
 *     classes, compiler, collections, numbers, BitBlt   itself
 *     ------------------------------------------------- bytecodes
 *     the virtual machine: St_interp, St_memory (the    OCaml,
 *     object table), St_primitives, St_colorblt         languages/
 *     Squeak: the system started, the world's cycle     smalltalk
 *     ------------------------------------------------- St_interp.host
 *     Host: the mouse, the keys, a clock, the Display   this
 *     Main: the boot, the loop                          directory
 *     ------------------------------------------------- Machine
 *     the board: framebuffer, USB, timer, serial line
 *
 * What an operating system gives a program, Smalltalk has as
 * objects of its own: what would be files is the image, every
 * object as it is; the window system, the editor and the compiler
 * are classes one can read and change in the Browser while they
 * run; its contexts, the frames of its calls, are objects too. In
 * Smalltalk-80 so are the processes, instances of Process scheduled
 * by a Smalltalk object; here a process is the virtual machine's
 * (St_interp: a chain of contexts, run for a budget of bytecodes).
 * Under it the machine needs five things of a host and a place to
 * copy pixels.
 *
 * The loop below is all of the kernel: show the Display if it
 * changed, ask the devices (Host.poll, which waits for the tick),
 * run one cycle of the world. An interrupt is never taken while
 * Smalltalk runs; Control-C is seen at the poll.
 *
 * The image: the build runs Smalltalk on Linux to the first screen
 * and saves its memory; the board loads that and goes on, objects,
 * windows and the Display's pixels as they were. That is how a
 * Smalltalk has always started: nobody has built one from nothing
 * since the first, each image is a descendant of another, changed
 * from inside. (Here the build can also start from the text,
 * FROM=text, which is how this one was made.)
 *
 * cs-history:
 * Smalltalk was the system of the Alto (Xerox PARC, 1973), from
 * Alan Kay's group: Smalltalk-72, -76 and -80, written mostly by
 * Dan Ingalls, with Adele Goldberg, Ted Kaehler and others. On the
 * Alto there was nothing under it but microcode: overlapping
 * windows, the mouse's menus and BitBlt were made there, in it. It
 * left PARC in 1981 (Byte's August issue) and 1983 (the "Blue
 * Book", whose last part is the virtual machine written out in
 * Smalltalk), and ran from then on as a program over other
 * systems. Squeak (1996) is its return by its authors:
 * languages/smalltalk's Squeak.mli tells that part.
 *
 * reframe:
 * "An operating system is a collection of things that don't fit
 * into a language. There shouldn't be one." (Dan Ingalls, 1981.)
 * This directory takes him at his word: 200 lines between the
 * virtual machine and the board.
 *
 * others:
 * Three systems in kernels/ have one address space and no
 * hardware protection, for three reasons. mini-oberon: one user,
 * modules, a compiler's types. mini-singularity: processes that
 * share nothing, checked code. Here: everything is an object that
 * can only be sent messages, and the user is trusted with all of
 * them. The Lisp machines (MIT, then Symbolics, from 1975) were
 * the same bet with Lisp. mini-xv6 and mini-9pi are the other
 * family, where the kernel is a wall.
 *
 * why-study:
 * It is the far end of what a "system" can be: no boundary at all
 * between the system and the program, both changed with the same
 * tool while running. Most of what a desktop is came from there,
 * and the part that did not come (the user reading and changing
 * what runs) is the part worth seeing.
 *
 * References: Adele Goldberg and David Robson, "Smalltalk-80: The
 * Language and its Implementation" (Addison-Wesley, 1983), the Blue
 * Book: part four is the machine languages/smalltalk follows. Dan
 * Ingalls, Ted Kaehler, John Maloney, Scott Wallace and Alan Kay,
 * "Back to the Future: The Story of Squeak, A Practical Smalltalk
 * Written in Itself" (OOPSLA 1997). Dan Ingalls, "Design Principles
 * Behind Smalltalk" (Byte, August 1981): a few pages, the
 * quotation's source. Alan Kay, "The Early History of Smalltalk"
 * (History of Programming Languages II, 1993).
 * plan_system_squeak.md. *)

let () =
  Machine.print "mini-squeak\n";
  let host = Host.init () in
  (* from the image in the kernel (its disk), or, when there is none,
   * from Smalltalk's text *)
  let squeak =
    if Machine.fs_size () > 0 then begin
      let t = Squeak.resume host (Machine.Phys.read (Machine.fs_base ()) (Machine.fs_size ())) in
      Machine.print (Printf.sprintf "mini-squeak: from its image, %d bytes.\n" (Machine.fs_size ()));
      t
    end
    else begin
      let t = Squeak.start Which.system host in
      Machine.print (Printf.sprintf "mini-squeak: started, %d bytecodes.\n" (St_interp.bytecodes_run (Squeak.vm t)));
      (* (the world's first cycle, which an image has had) *)
      Squeak.cycle t ~interrupt:false;
      t
    end in
  let drawn = ref false in
  (* (the picture first: an image's Display is drawn already) *)
  while true do
    let moved = Host.pointer_moved () in
    if Squeak.changed squeak || moved then begin
      (match Squeak.bits32 squeak with
       | Some f -> Host.show32 f
       | None -> (match Squeak.pixels squeak with Some p -> Host.show p | None -> ()));
      Host.pointer ();
      if not !drawn then begin drawn := true; Machine.print "mini-squeak: drawn.\n" end
    end;
    let interrupt = Host.poll () in
    Squeak.cycle squeak ~interrupt
  done
