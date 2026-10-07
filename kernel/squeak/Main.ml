(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-squeak's boot on the bare Pi 4 (docs/plans/plan_system_squeak.md):
 * the board's devices (Host), Smalltalk brought up over them and its
 * world started (Squeak; Which.system: Squeak's, or MiniMorphic's by
 * mini-mk SYSTEM=Mini), then the world's cycle for ever, the Display
 * shown when it changed. On the serial line: its name, what the start
 * could not do, and a line once the first screen is drawn. *)

let () =
  Machine.print "mini-squeak\n";
  let host = Host.init () in
  let squeak = Squeak.start Which.system host in
  Machine.print (Printf.sprintf "mini-squeak: started, %d bytecodes.\n" (St_interp.bytecodes_run (Squeak.vm squeak)));
  let drawn = ref false in
  while true do
    let interrupt = Host.poll () in
    Squeak.cycle squeak ~interrupt;
    if Squeak.changed squeak then begin
      (match Squeak.bits32 squeak with
       | Some f -> Host.show32 f
       | None -> (match Squeak.pixels squeak with Some p -> Host.show p | None -> ()));
      if not !drawn then begin drawn := true; Machine.print "mini-squeak: drawn.\n" end
    end
  done
