(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-turbopascal in a window of mini-rio's, under mini-9pi: see Window.mli *)

let usage = "usage: turbopascal   (-h: how)"

let help = {|usage: turbopascal
Turbo Pascal's IDE in this window (or on all the screen, with no window system),
its text Plan 9's font: F9 compiles, Control-F9 runs, F10 the menus, F1 the
keys; File's Exit ends it. The window made larger has more rows and columns,
not larger letters. Without F keys: Escape then a digit (0 for F10). Alt is
Plan 9's compose key: not used here.|}

let main (caps : < Window.caps; Cap.stdout; Cap.stderr; .. >) (argv : string array) : Exit.t =
  let options = [ "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how" ] in
  match Arg.parse_argv argv options (fun (a : string) -> raise (Arg.Bad (a ^ ": no argument is expected\n"))) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> Window.run caps Tui_turbo.program; Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
