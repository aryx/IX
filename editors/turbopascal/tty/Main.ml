(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-turbopascal in the terminal one types this in (the author's
 * playground's apps/devtools/tty/TinyTurboPascal.ml): Tui_turbo's
 * program run by Tty_unix. The terminal's own colours stand for the
 * PC's, and its font must have the box characters. Its files are its
 * own disk's, in memory. *)

let usage = "usage: mini-turbopascal-tty [-keys script [-frame file.ppm]]   (-h: how)"

let help = {|usage: mini-turbopascal-tty [-keys script [-frame file.ppm]]
Turbo Pascal's IDE in this terminal, 80 by 24 at least: F9 compiles, Control-F9
runs, F10 the menus, F1 the keys; Control-C ends it. Without F keys: Escape
then a digit (0 for F10), Control and a digit for Control and the F key.
-keys: no terminal; the script's keys given (F9 C-F9 A-c Enter ArrowDown
=text; 16x60: the screen made 16 rows of 60 columns), and the screen they
leave printed as text; with -frame, written as the picture a window shows
(Plan 9's font, a cell 9 by 15 pixels: a PPM).|}

(* the screen as the windows paint it (hosts/Cells), in a file *)
let frame (caps : < Cap.open_out; .. >) (screen : Curses.t) (file : string) : unit =
  let font = Picture.font () in
  let w, h = Picture.cell font in
  let picture = Picture.create (Curses.cols screen * w) (Curses.rows screen * h) in
  Cells.show (Picture.surface picture font) None screen;
  FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc (Picture.ppm picture)) (Fpath.v file)

let main (caps : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.open_out; .. >) (argv : string array) : Exit.t =
  let script : string option ref = ref None and file : string option ref = ref None and views = ref false in
  let options = [
    "-keys", Arg.String (fun (s : string) -> script := Some s), " script: no terminal, the screen its keys leave";
    "-views", Arg.Set views, " with -keys: the screen made and compared after each key, as a window does (to time it)";
    "-nocache", Arg.Clear Turbo_view.cache, " a view keeps nothing of the one before";
    "-frame", Arg.String (fun (s : string) -> file := Some s), " file.ppm: with -keys, the screen as a picture";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> raise (Arg.Bad (a ^ ": no argument is expected\n"))) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> (
      match !script with
      | None -> Tty_unix.run caps Tui_turbo.program; Exit.OK
      | Some s -> (
          (* -views: after each key the screen is made and compared with
           * the one before, a window's work but the painting *)
          let shown : Curses.t option ref = ref None in
          let each (m : Tui_turbo.model) : unit =
            if !views then begin
              let next = Tui_turbo.program.view m in
              ignore (Cells.runs !shown next);
              shown := Some next
            end in
          match Keys.run_each each s, !file with
          | Ok screen, Some f -> frame caps screen f; Exit.OK
          | Ok screen, None -> List.iter (fun (r : string) -> Console.print caps (r ^ "\n")) (Curses.text screen); Exit.OK
          | Error w, _ -> Console.eprint caps (w ^ ": no key of that name\n"); Exit.Code 1))

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
