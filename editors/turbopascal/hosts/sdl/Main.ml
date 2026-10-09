(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-turbopascal in a window on Linux: see Window.mli *)

let usage = "usage: mini-turbopascal [-scale n] [-rows n] [-cols n]   (-h: how)"

let help = {|usage: mini-turbopascal [-scale n] [-rows n] [-cols n]
Turbo Pascal's IDE in a window, its text Plan 9's font: F9 compiles, Control-F9
runs, F10 or Alt and a letter the menus, F1 the keys, Alt-X ends it. The window
made larger has more rows and columns, not larger letters. Without F keys:
Escape then a digit (0 for F10), Control and a digit for Control and the F key.
-scale: a pixel of the font is n by n of the screen's (2). -rows, -cols: the
window at first (24, 80).|}

let main (caps : < Cap.stdout; Cap.stderr; .. >) (argv : string array) : Exit.t =
  let scale = ref 2 and rows = ref 24 and cols = ref 80 in
  let options = [
    "-scale", Arg.Set_int scale, " n: a pixel of the font is n by n of the screen's";
    "-rows", Arg.Set_int rows, " n: the window's rows at first";
    "-cols", Arg.Set_int cols, " n: its columns";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> raise (Arg.Bad (a ^ ": no argument is expected\n"))) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> Window_sdl.run "mini-turbopascal" ~mouse:false (max 1 !scale) !rows !cols Tui_turbo.program; Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
