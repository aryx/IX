(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-emacs in a window of mini-rio's, under mini-9pi: Top_window's
 * program run by lib_terminal/hosts/draw's Window_draw. *)

let usage = "usage: emacs [-q] [-time] [file]   (-h: how)"

let help = {|usage: emacs [-q] [-time] [file]
An Emacs in this window (or on all the screen, with no window system), on the
file or the directory, its text Plan 9's font. Its keys are Emacs's: C-f C-b
C-n C-p and the arrows, C-v M-v, C-s, C-x C-f a file, C-x b a buffer, C-x 2 and
C-x o the windows, M-x a command by its name, C-x C-s saves, C-x C-c ends it.
Meta is Escape, then the key (Alt is Plan 9's compose key). A click puts the
point. -q: without the author's configuration (his colors, his keys).
-time: each time the screen is painted, the milliseconds of it, on the console
(run it with >file in a window).|}

let main (caps : < Window_draw.caps ; Cap.stdout ; Cap.stderr ; Cap.open_in ; Cap.open_out ; Cap.readdir ; .. >) (argv : string array) : Exit.t =
  let time = ref false and pad = ref true and file : string option ref = ref None in
  let options = [
    "-q", Arg.Clear pad, " without the author's configuration (Config_pad)";
    "-time", Arg.Set time, " the milliseconds of each painting, on the console";
    "-nocache", Arg.Clear Frame.cache, " a frame's rows made at each key (Frame)";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> file := Some a) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () ->
      Window_draw.run caps ~mouse:true (if !time then Some (fun (s : string) -> Console.eprint caps s) else None)
        (Start.editor (caps :> Efuns.caps) ~pad:!pad !file);
      Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
