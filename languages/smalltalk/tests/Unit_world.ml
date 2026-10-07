(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Unit_world.mli *)

let check = Alcotest.(check string)

(* a system started and cycled n times, 20 ms of its clock a cycle,
 * nobody at the mouse: its Display's size and its pixels' MD5 *)
let after (system : Squeak.system) (n : int) : string =
  let now = ref 0 in
  let host = { St_boot.quiet_host with milliseconds = (fun () -> !now) } in
  let t = Squeak.start system host in
  let last = ref None in
  for _i = 1 to n do
    Squeak.cycle t ~interrupt:false;
    now := !now + 20;
    match Squeak.picture t with Some p -> last := Some p | None -> ()
  done;
  match !last with
  | Some (w, h, bytes) -> Printf.sprintf "%dx%d %s" w h (Digest.to_hex (Digest.bytes bytes))
  | None -> "no picture"

let tests =
  Testo.categorize "Squeak's world"
    [
      Testo.create "Squeak: the start's screen, then thirty cycles" (fun () ->
          check "after 3" "800x600 b87daa51e6ef7f0c7ec0062ab413efac" (after Squeak.Squeak 3);
          check "after 30" "800x600 d309822b30eb8013b2ebefd0b9c2af94" (after Squeak.Squeak 30));
      Testo.create "MiniMorphic: fifty squares, a hundred cycles" (fun () ->
          check "after 100" "800x600 1d8002b4950c6977a23649ab5050d73b" (after Squeak.Mini 100));
    ]
