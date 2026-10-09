(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-turbopascal in a window of mini-rio's, under mini-9pi: see Window_draw.mli *)

let usage = "usage: turbopascal [-time] [-nocache]   (-h: how)"

let help = {|usage: turbopascal [-time] [-nocache]
Turbo Pascal's IDE in this window (or on all the screen, with no window system),
its text Plan 9's font: F9 compiles, Control-F9 runs, F10 or Alt and a letter
the menus, F1 the keys, Alt-X ends it. The window made larger has more rows and
columns, not larger letters. Without F keys: Escape then a digit (0 for F10).
-time: each time the screen is painted, the milliseconds of it, on the console
(run it with >file in a window). -nocache: every screen made from nothing.|}

let main (caps : < Window_draw.caps; Cap.stdout; Cap.stderr; .. >) (argv : string array) : Exit.t =
  let time = ref false in
  let options = [
    "-time", Arg.Set time, " the milliseconds of each painting, on the console";
    "-nocache", Arg.Clear Turbo_view.cache, " a view keeps nothing of the one before";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> raise (Arg.Bad (a ^ ": no argument is expected\n"))) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> Window_draw.run caps ~mouse:false (if !time then Some (fun (s : string) -> Console.eprint caps s) else None) Tui_turbo.program; Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
