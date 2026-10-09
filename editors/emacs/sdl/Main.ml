(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-emacs in a window on Linux: Top_window's program run by
 * lib_terminal/hosts/sdl's Window_sdl, a cell a character of Plan 9's
 * font, the mouse a key. *)

let usage = "usage: mini-emacs [-q] [-scale n] [-rows n] [-cols n] [file]   (-h: how)"

let help = {|usage: mini-emacs [-q] [-scale n] [-rows n] [-cols n] [file]
An Emacs in a window, on the file or the directory, its text Plan 9's font
(Latin's letters: another character is not drawn). Its keys are Emacs's
(mini-emacs-tty -h lists them); a click puts the point, the wheel scrolls. The
window made larger has more rows and columns, not larger letters.
-q: without the author's configuration (his colors, his keys).
-scale: a pixel of the font is n by n of the screen's (2). -rows, -cols: the
window at first (40, 100).|}

let main (caps : < Cap.stdout ; Cap.stderr ; Cap.open_in ; Cap.open_out ; Cap.readdir ; .. >) (argv : string array) : Exit.t =
  let scale = ref 2 and rows = ref 40 and cols = ref 100 and pad = ref true and file : string option ref = ref None in
  let options = [
    "-q", Arg.Clear pad, " without the author's configuration (Config_pad)";
    "-scale", Arg.Set_int scale, " n: a pixel of the font is n by n of the screen's";
    "-rows", Arg.Set_int rows, " n: the window's rows at first";
    "-cols", Arg.Set_int cols, " n: its columns";
    "-nocache", Arg.Clear Frame.cache, " a frame's rows made at each key (Frame)";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> file := Some a) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () ->
      Window_sdl.run "mini-emacs" ~mouse:true (max 1 !scale) !rows !cols (Start.editor (caps :> Efuns.caps) ~pad:!pad !file);
      Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
