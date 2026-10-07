(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-squeak's boot on the bare Pi 4 (docs/plans/plan_system_squeak.md):
 * the board's devices (Host), Smalltalk brought up over them and its
 * world started (Squeak: from its image, made by the build; or from
 * its text, Which.system's start), then the world's cycle for ever, the Display
 * shown when it changed. On the serial line: its name, what the start
 * could not do, and a line once the first screen is drawn. *)

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
